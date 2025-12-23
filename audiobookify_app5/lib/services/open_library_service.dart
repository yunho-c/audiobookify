import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/open_library_work.dart';
import '../models/public_book.dart';

class OpenLibraryException implements Exception {
  final String message;

  const OpenLibraryException(this.message);

  @override
  String toString() => 'OpenLibraryException: $message';
}

class OpenLibraryService {
  static const String _baseUrl = 'https://openlibrary.org/search.json';
  static const String _defaultUserAgent =
      'Audiobookify/1.0 (contact@audiobookify.app)';
  static const Duration _requestTimeout = Duration(seconds: 12);
  static const Duration _networkCheckTimeout = Duration(seconds: 3);
  static const int _cacheMaxEntries = 50;
  static const Duration _diskCacheTtl = Duration(hours: 24);
  static const String _diskCacheKey = 'open_library_cache_v1';

  OpenLibraryService({
    http.Client? client,
    String? userAgent,
    SharedPreferences? preferences,
    Future<bool> Function()? networkChecker,
  })  : _client = client ?? http.Client(),
        _headers = {
          'User-Agent': userAgent ?? _defaultUserAgent,
        },
        _preferences = preferences,
        _networkChecker = networkChecker ?? _defaultNetworkChecker {
    _loadDiskCache();
  }

  final http.Client _client;
  final Map<String, String> _headers;
  final LinkedHashMap<String, List<PublicBook>> _cache = LinkedHashMap();
  final LinkedHashMap<String, _CachedSearch> _diskCache = LinkedHashMap();
  final SharedPreferences? _preferences;
  final Future<bool> Function() _networkChecker;

  Future<List<PublicBook>> searchPublicDomain({
    required String query,
    int page = 1,
    int limit = 20,
    String? language,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];

    final cacheKey = _cacheKey(normalizedQuery, page, limit, language);
    final cached = _cache.remove(cacheKey);
    if (cached != null) {
      _cache[cacheKey] = cached;
      return cached;
    }

    final diskCached = _diskCache.remove(cacheKey);
    if (diskCached != null) {
      _diskCache[cacheKey] = diskCached;
      if (!diskCached.isExpired) {
        _cache[cacheKey] = diskCached.results;
        return diskCached.results;
      }
    }

    final hasNetwork = await _networkChecker();
    if (!hasNetwork) {
      if (diskCached != null) {
        _cache[cacheKey] = diskCached.results;
        return diskCached.results;
      }
      throw const OpenLibraryException(
        'No internet connection. Please try again when you are online.',
      );
    }

    final params = <String, String>{
      'q': normalizedQuery,
      'has_fulltext': 'true',
      'fields':
          'key,title,author_name,cover_i,ia,ebook_access,first_publish_year,language',
      'limit': '$limit',
      'page': '$page',
      'mode': 'everything',
    };

    if (language != null && language.trim().isNotEmpty) {
      params['lang'] = language.trim();
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    http.Response response;
    try {
      response = await _getWithRetry(uri);
    } on OpenLibraryException {
      if (diskCached != null) {
        _cache[cacheKey] = diskCached.results;
        return diskCached.results;
      }
      rethrow;
    }

    if (response.statusCode != 200) {
      throw OpenLibraryException(
        'Search failed. Please try again shortly.',
      );
    }

    final dynamic body;
    try {
      body = json.decode(response.body);
    } catch (_) {
      throw const OpenLibraryException(
        'Open Library returned unexpected data. Please try again.',
      );
    }
    final results = _parseResults(body);
    _cache[cacheKey] = results;
    while (_cache.length > _cacheMaxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _writeDiskCache(cacheKey, results);
    return results;
  }

  Future<OpenLibraryWork?> fetchWorkDetails(String key) async {
    final normalized = key.trim();
    if (normalized.isEmpty) return null;
    final path = normalized.startsWith('/') ? normalized : '/$normalized';
    final uri = Uri.parse('https://openlibrary.org$path.json');

    http.Response response;
    try {
      response = await _getWithRetry(uri);
    } on OpenLibraryException {
      return null;
    }
    if (response.statusCode != 200) {
      return null;
    }

    try {
      final body = json.decode(response.body);
      if (body is! Map<String, dynamic>) return null;
      return OpenLibraryWork.fromMap(body);
    } catch (_) {
      return null;
    }
  }

  void clearCache() {
    _cache.clear();
    _diskCache.clear();
    _persistDiskCache();
  }

  void dispose() => _client.close();

  String _cacheKey(String query, int page, int limit, String? language) {
    final languageKey = language?.trim().toLowerCase() ?? '';
    return '${query.toLowerCase()}::$page::$limit::$languageKey';
  }

  static Future<bool> _defaultNetworkChecker() async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one')
          .timeout(_networkCheckTimeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    const maxAttempts = 3;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await _client
            .get(uri, headers: _headers)
            .timeout(_requestTimeout);
        return response;
      } on TimeoutException {
        if (attempt == maxAttempts - 1) {
          throw const OpenLibraryException(
            'Open Library is taking too long to respond. Please try again.',
          );
        }
      } on SocketException {
        if (attempt == maxAttempts - 1) {
          throw const OpenLibraryException(
            'Network error. Please check your connection and retry.',
          );
        }
      }
      final backoffMs = 300 * (attempt + 1);
      await Future<void>.delayed(Duration(milliseconds: backoffMs));
    }
    throw const OpenLibraryException('Search failed. Please try again.');
  }

  List<PublicBook> _parseResults(dynamic body) {
    if (body is! Map<String, dynamic>) return const [];
    final docs = body['docs'];
    if (docs is! List) return const [];

    final results = <PublicBook>[];
    for (final entry in docs) {
      if (entry is! Map) continue;
      if (entry['ebook_access'] != 'public') continue;

      final iaId = _extractIaId(entry['ia']);
      if (iaId == null) continue;

      final title = (entry['title'] as String?)?.trim();
      final authors = _extractAuthors(entry['author_name']);
      final year = _extractYear(entry['first_publish_year']);
      final coverUrl = _buildCoverUrl(entry['cover_i']);
      final key = entry['key']?.toString() ?? '';
      final epubUrl = 'https://archive.org/download/$iaId/$iaId.epub';

      results.add(
        PublicBook(
          title: title?.isNotEmpty == true ? title! : 'Unknown Title',
          authors: authors.isNotEmpty ? authors : const ['Unknown Author'],
          firstPublishYear: year,
          coverUrl: coverUrl,
          epubUrl: epubUrl,
          key: key,
          iaId: iaId,
        ),
      );
    }

    return results;
  }

  String? _extractIaId(dynamic ia) {
    if (ia is List) {
      for (final item in ia) {
        if (item is String && item.trim().isNotEmpty) {
          return item.trim();
        }
      }
      return null;
    }
    if (ia is String && ia.trim().isNotEmpty) {
      return ia.trim();
    }
    return null;
  }

  List<String> _extractAuthors(dynamic authors) {
    if (authors is List) {
      return authors
          .whereType<String>()
          .map((author) => author.trim())
          .where((author) => author.isNotEmpty)
          .toList(growable: false);
    }
    if (authors is String && authors.trim().isNotEmpty) {
      return [authors.trim()];
    }
    return const [];
  }

  int? _extractYear(dynamic year) {
    if (year is int) return year;
    if (year is String) return int.tryParse(year.trim());
    return null;
  }

  String? _buildCoverUrl(dynamic coverId) {
    if (coverId is int) {
      return 'https://covers.openlibrary.org/b/id/$coverId-M.jpg';
    }
    if (coverId is String) {
      final parsed = int.tryParse(coverId);
      if (parsed != null) {
        return 'https://covers.openlibrary.org/b/id/$parsed-M.jpg';
      }
    }
    return null;
  }

  void _loadDiskCache() {
    final prefs = _preferences;
    if (prefs == null) return;
    final raw = prefs.getString(_diskCacheKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return;
      for (final entry in decoded.entries) {
        final cached = _cachedSearchFromJson(entry.value);
        if (cached == null) continue;
        _diskCache[entry.key] = cached;
      }
    } catch (_) {
      _diskCache.clear();
    }
  }

  void _writeDiskCache(String cacheKey, List<PublicBook> results) {
    _diskCache[cacheKey] = _CachedSearch(
      storedAt: DateTime.now(),
      results: results,
    );
    while (_diskCache.length > _cacheMaxEntries) {
      _diskCache.remove(_diskCache.keys.first);
    }
    _persistDiskCache();
  }

  void _persistDiskCache() {
    final prefs = _preferences;
    if (prefs == null) return;
    final payload = <String, dynamic>{};
    for (final entry in _diskCache.entries) {
      payload[entry.key] = _cachedSearchToJson(entry.value);
    }
    unawaited(prefs.setString(_diskCacheKey, json.encode(payload)));
  }

  static Map<String, dynamic> _cachedSearchToJson(_CachedSearch cached) {
    return {
      'storedAt': cached.storedAt.millisecondsSinceEpoch,
      'results': cached.results.map(_publicBookToJson).toList(),
    };
  }

  static _CachedSearch? _cachedSearchFromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final storedAtRaw = value['storedAt'];
    final resultsRaw = value['results'];
    if (storedAtRaw is! int || resultsRaw is! List) return null;
    final results = <PublicBook>[];
    for (final entry in resultsRaw) {
      final book = _publicBookFromJson(entry);
      if (book != null) {
        results.add(book);
      }
    }
    return _CachedSearch(
      storedAt: DateTime.fromMillisecondsSinceEpoch(storedAtRaw),
      results: results,
    );
  }

  static Map<String, dynamic> _publicBookToJson(PublicBook book) {
    return {
      'title': book.title,
      'authors': book.authors,
      'firstPublishYear': book.firstPublishYear,
      'coverUrl': book.coverUrl,
      'epubUrl': book.epubUrl,
      'key': book.key,
      'iaId': book.iaId,
    };
  }

  static PublicBook? _publicBookFromJson(Object? value) {
    if (value is! Map) return null;
    final title = value['title']?.toString();
    final authorsRaw = value['authors'];
    final authors = authorsRaw is List
        ? authorsRaw.map((author) => author.toString()).toList()
        : <String>[];
    final epubUrl = value['epubUrl']?.toString();
    final key = value['key']?.toString();
    final iaId = value['iaId']?.toString();
    if (title == null || epubUrl == null || key == null || iaId == null) {
      return null;
    }
    return PublicBook(
      title: title,
      authors: authors,
      firstPublishYear: value['firstPublishYear'] is int
          ? value['firstPublishYear'] as int
          : int.tryParse(value['firstPublishYear']?.toString() ?? ''),
      coverUrl: value['coverUrl']?.toString(),
      epubUrl: epubUrl,
      key: key,
      iaId: iaId,
    );
  }
}

class _CachedSearch {
  final DateTime storedAt;
  final List<PublicBook> results;

  const _CachedSearch({
    required this.storedAt,
    required this.results,
  });

  bool get isExpired =>
      DateTime.now().difference(storedAt) > OpenLibraryService._diskCacheTtl;
}

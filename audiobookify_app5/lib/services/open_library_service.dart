import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
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

  OpenLibraryService({http.Client? client, String? userAgent})
      : _client = client ?? http.Client(),
        _headers = {
          'User-Agent': userAgent ?? _defaultUserAgent,
        };

  final http.Client _client;
  final Map<String, String> _headers;
  final Map<String, List<PublicBook>> _cache = {};

  Future<List<PublicBook>> searchPublicDomain({
    required String query,
    int page = 1,
    int limit = 20,
    String? language,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];

    final cacheKey = _cacheKey(normalizedQuery, page, limit, language);
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

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
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw OpenLibraryException(
        'Search failed (${response.statusCode}): ${response.reasonPhrase}',
      );
    }

    final body = json.decode(response.body);
    final results = _parseResults(body);
    _cache[cacheKey] = results;
    return results;
  }

  Future<OpenLibraryWork?> fetchWorkDetails(String key) async {
    final normalized = key.trim();
    if (normalized.isEmpty) return null;
    final path = normalized.startsWith('/') ? normalized : '/$normalized';
    final uri = Uri.parse('https://openlibrary.org$path.json');

    final response = await _client
        .get(uri, headers: _headers)
        .timeout(_requestTimeout);
    if (response.statusCode != 200) {
      return null;
    }

    final body = json.decode(response.body);
    if (body is! Map<String, dynamic>) return null;
    return OpenLibraryWork.fromMap(body);
  }

  void clearCache() => _cache.clear();

  void dispose() => _client.close();

  String _cacheKey(String query, int page, int limit, String? language) {
    final languageKey = language?.trim().toLowerCase() ?? '';
    return '${query.toLowerCase()}::$page::$limit::$languageKey';
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
}

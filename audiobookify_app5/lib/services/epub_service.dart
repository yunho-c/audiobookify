import '../src/rust/api/epub.dart' as rust_epub;

typedef OpenEpubLoader =
    Future<rust_epub.ParsedEpubBook> Function(String path);

class EpubService {
  EpubService({OpenEpubLoader? loader}) : _loader = loader ?? _defaultLoader;

  final OpenEpubLoader _loader;
  final Map<String, rust_epub.ParsedEpubBook> _cache = {};
  final Map<String, Future<rust_epub.ParsedEpubBook>> _inflight = {};

  Future<rust_epub.ParsedEpubBook> openEpub(String path) {
    final cached = _cache[path];
    if (cached != null) {
      return Future.value(cached);
    }

    final inflight = _inflight[path];
    if (inflight != null) {
      return inflight;
    }

    final future = _loadAndCache(path);
    _inflight[path] = future;
    return future;
  }

  void evict(String path) {
    _cache.remove(path);
    _inflight.remove(path);
  }

  void clearCache() {
    _cache.clear();
    _inflight.clear();
  }

  Future<rust_epub.ParsedEpubBook> _loadAndCache(String path) async {
    try {
      final book = await _loader(path);
      _cache[path] = book;
      return book;
    } finally {
      _inflight.remove(path);
    }
  }

  static Future<rust_epub.ParsedEpubBook> _defaultLoader(String path) {
    return rust_epub.openEpub(path: path);
  }
}

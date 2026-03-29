import 'dart:collection';
import 'dart:typed_data';

import '../src/rust/api/epub.dart';
import 'reader_ir.dart';

class EpubResourceResolver {
  final String epubPath;
  final int cacheSize;
  final Future<Uint8List?> Function(String href)? loader;

  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();

  EpubResourceResolver({
    required this.epubPath,
    this.cacheSize = 32,
    this.loader,
  });

  static EpubResourceResolver fromMemory(
    Map<String, Uint8List> assets, {
    int cacheSize = 32,
  }) {
    return EpubResourceResolver(
      epubPath: '',
      cacheSize: cacheSize,
      loader: (href) async => assets[href],
    );
  }

  Future<Uint8List?> loadImage(String href) async {
    return loadHref(href);
  }

  Future<Uint8List?> loadResource(ReaderResourceRef resource) async {
    final normalized = _normalizeHref(resource.href);
    if (normalized.isEmpty) return null;

    final cached = _cache.remove(normalized);
    if (cached != null) {
      _cache[normalized] = cached;
      return cached;
    }

    final bytes =
        loader != null
            ? await loader!(normalized)
            : await readBookResourceBytes(
                path: epubPath,
                resource: ResourceRef(
                  href: normalized,
                  mediaType: resource.mediaType,
                  kind: _resourceKind(resource.kind),
                ),
              );
    if (bytes == null) return null;

    _cache[normalized] = bytes;
    while (_cache.length > cacheSize) {
      _cache.remove(_cache.keys.first);
    }
    return bytes;
  }

  Future<Uint8List?> loadHref(String href) async {
    final normalized = _normalizeHref(href);
    if (normalized.isEmpty) return null;

    final cached = _cache.remove(normalized);
    if (cached != null) {
      _cache[normalized] = cached;
      return cached;
    }

    final bytes =
        loader != null
            ? await loader!(normalized)
            : await readBookResourceBytes(
                path: epubPath,
                resource: ResourceRef(
                  href: normalized,
                  mediaType: null,
                  kind: ResourceKind.image,
                ),
              );
    if (bytes == null) return null;

    _cache[normalized] = bytes;
    while (_cache.length > cacheSize) {
      _cache.remove(_cache.keys.first);
    }
    return bytes;
  }

  String _normalizeHref(String href) {
    final trimmed = href.trim();
    if (trimmed.isEmpty) return '';
    final withoutFragment = trimmed.split('#').first;
    if (withoutFragment.isEmpty) return '';
    final decoded = Uri.decodeComponent(withoutFragment);
    if (decoded.startsWith('/')) {
      return decoded.substring(1);
    }
    return decoded;
  }

  ResourceKind _resourceKind(ReaderResourceKind kind) {
    switch (kind) {
      case ReaderResourceKind.image:
        return ResourceKind.image;
      case ReaderResourceKind.stylesheet:
        return ResourceKind.stylesheet;
      case ReaderResourceKind.cover:
        return ResourceKind.cover;
      case ReaderResourceKind.other:
        return ResourceKind.other;
    }
  }
}

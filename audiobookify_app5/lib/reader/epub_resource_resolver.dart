import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../src/rust/api/epub.dart';
import 'reader_debug_logging.dart';
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
    final normalizedCandidates = _normalizedHrefCandidates(resource.href);
    if (normalizedCandidates.isEmpty) {
      _logImageDebug(
        'resolver resource skipped empty href raw="${resource.href}"',
      );
      return null;
    }

    for (final candidate in normalizedCandidates) {
      final cached = _cache.remove(candidate);
      if (cached != null) {
        _cache[candidate] = cached;
        _logImageDebug(
          'resolver resource cache-hit href="$candidate" bytes=${cached.length} media="${resource.mediaType ?? 'N/A'}"',
        );
        return cached;
      }
    }

    for (final candidate in normalizedCandidates) {
      _logImageDebug(
        'resolver resource load-start raw="${resource.href}" normalized="$candidate" media="${resource.mediaType ?? 'N/A'}" kind=${resource.kind.name}',
      );

      final Uint8List? bytes;
      try {
        bytes =
            loader != null
                ? await loader!(candidate)
                : await readBookResourceBytes(
                    path: epubPath,
                    resource: ResourceRef(
                      href: candidate,
                      mediaType: resource.mediaType,
                      kind: _resourceKind(resource.kind),
                    ),
                  );
      } catch (error, stackTrace) {
        _logImageDebug(
          'resolver resource load-error href="$candidate" error=$error\n$stackTrace',
        );
        rethrow;
      }

      _logImageDebug(
        'resolver resource load-done href="$candidate" bytes=${bytes?.length ?? 0}',
      );
      if (bytes == null) continue;

      _cache[candidate] = bytes;
      while (_cache.length > cacheSize) {
        _cache.remove(_cache.keys.first);
      }
      return bytes;
    }

    return null;
  }

  Future<Uint8List?> loadHref(String href) async {
    final normalizedCandidates = _normalizedHrefCandidates(href);
    if (normalizedCandidates.isEmpty) {
      _logImageDebug('resolver href skipped empty raw="$href"');
      return null;
    }

    for (final candidate in normalizedCandidates) {
      final cached = _cache.remove(candidate);
      if (cached != null) {
        _cache[candidate] = cached;
        _logImageDebug(
          'resolver href cache-hit href="$candidate" bytes=${cached.length}',
        );
        return cached;
      }
    }

    for (final candidate in normalizedCandidates) {
      _logImageDebug('resolver href load-start raw="$href" normalized="$candidate"');

      final Uint8List? bytes;
      try {
        bytes =
            loader != null
                ? await loader!(candidate)
                : await readBookResourceBytes(
                    path: epubPath,
                    resource: ResourceRef(
                      href: candidate,
                      mediaType: null,
                      kind: ResourceKind.image,
                    ),
                  );
      } catch (error, stackTrace) {
        _logImageDebug(
          'resolver href load-error href="$candidate" error=$error\n$stackTrace',
        );
        rethrow;
      }

      _logImageDebug(
        'resolver href load-done href="$candidate" bytes=${bytes?.length ?? 0}',
      );
      if (bytes == null) continue;

      _cache[candidate] = bytes;
      while (_cache.length > cacheSize) {
        _cache.remove(_cache.keys.first);
      }
      return bytes;
    }

    return null;
  }

  List<String> _normalizedHrefCandidates(String href) {
    final trimmed = href.trim();
    if (trimmed.isEmpty) return const [];
    final withoutFragment = trimmed.split('#').first;
    if (withoutFragment.isEmpty) return const [];
    final decoded = Uri.decodeComponent(withoutFragment);
    final candidates = <String>[];
    void addCandidate(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty || candidates.contains(normalized)) return;
      candidates.add(normalized);
    }
    addCandidate(decoded);
    if (decoded.startsWith('/')) {
      addCandidate(decoded.substring(1));
    } else {
      addCandidate('/$decoded');
    }
    return candidates;
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

void _logImageDebug(String message) {
  if (!kDebugMode || !ReaderDebugLogging.imageLogsEnabled) return;
  debugPrint('[image-debug] $message');
}

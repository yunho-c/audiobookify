import 'dart:convert';
import 'package:flutter/foundation.dart';

enum BackdropSourceType { builtIn, unsplash, url, upload }

@immutable
class BackdropImage {
  final String id;
  final BackdropSourceType sourceType;
  final String uri;
  final String? metadata;

  const BackdropImage({
    required this.id,
    required this.sourceType,
    required this.uri,
    this.metadata,
  });

  BackdropImage copyWith({
    String? id,
    BackdropSourceType? sourceType,
    String? uri,
    String? metadata,
  }) {
    return BackdropImage(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      uri: uri ?? this.uri,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceType': sourceType.name,
      'uri': uri,
      'metadata': metadata,
    };
  }

  factory BackdropImage.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final uri = (json['uri'] as String?)?.trim() ?? '';
    if (id.isEmpty || uri.isEmpty) {
      throw const FormatException('Invalid BackdropImage payload.');
    }
    final metadataValue = json['metadata'];
    final metadata = metadataValue is String && metadataValue.trim().isNotEmpty
        ? metadataValue.trim()
        : null;
    return BackdropImage(
      id: id,
      sourceType: _parseSourceType(json['sourceType'] as String?),
      uri: uri,
      metadata: metadata,
    );
  }

  static BackdropSourceType _parseSourceType(String? value) {
    for (final entry in BackdropSourceType.values) {
      if (entry.name == value) {
        return entry;
      }
    }
    return BackdropSourceType.url;
  }

  static String? encodeMetadata({
    String? title,
    String? author,
    String? attributionUrl,
  }) {
    final cleanTitle = title?.trim();
    final cleanAuthor = author?.trim();
    final cleanUrl = attributionUrl?.trim();
    final payload = <String, String>{};
    if (cleanTitle != null && cleanTitle.isNotEmpty) {
      payload['title'] = cleanTitle;
    }
    if (cleanAuthor != null && cleanAuthor.isNotEmpty) {
      payload['author'] = cleanAuthor;
    }
    if (cleanUrl != null && cleanUrl.isNotEmpty) {
      payload['attributionUrl'] = cleanUrl;
    }
    if (payload.isEmpty) return null;
    return jsonEncode(payload);
  }

  static Map<String, String> decodeMetadata(String? metadata) {
    if (metadata == null || metadata.trim().isEmpty) {
      return const {};
    }
    try {
      final decoded = jsonDecode(metadata);
      if (decoded is Map) {
        final result = <String, String>{};
        decoded.forEach((key, value) {
          if (key == null || value == null) return;
          result[key.toString()] = value.toString();
        });
        return result;
      }
    } catch (_) {
      // Ignore malformed metadata.
    }
    return const {};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackdropImage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sourceType == other.sourceType &&
          uri == other.uri &&
          metadata == other.metadata;

  @override
  int get hashCode => Object.hash(id, sourceType, uri, metadata);
}

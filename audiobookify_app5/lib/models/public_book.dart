import 'package:flutter/material.dart';

@immutable
class PublicBook {
  final String title;
  final List<String> authors;
  final int? firstPublishYear;
  final String? coverUrl;
  final String epubUrl;
  final String key;
  final String iaId;

  const PublicBook({
    required this.title,
    required this.authors,
    required this.firstPublishYear,
    required this.coverUrl,
    required this.epubUrl,
    required this.key,
    required this.iaId,
  });

  String get primaryAuthor =>
      authors.isEmpty ? 'Unknown Author' : authors.first;

  String get yearLabel => firstPublishYear?.toString() ?? 'N/A';
}

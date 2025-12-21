import 'package:flutter/material.dart';

@immutable
class OpenLibraryWork {
  final String? title;
  final String? description;
  final List<String> subjects;
  final String? firstPublishDate;

  const OpenLibraryWork({
    required this.title,
    required this.description,
    required this.subjects,
    required this.firstPublishDate,
  });

  factory OpenLibraryWork.fromMap(Map<String, dynamic> map) {
    final rawDescription = map['description'];
    String? description;
    if (rawDescription is String) {
      description = rawDescription.trim();
    } else if (rawDescription is Map) {
      final value = rawDescription['value'];
      if (value is String) {
        description = value.trim();
      }
    }

    final rawSubjects = map['subjects'];
    final subjects = <String>[];
    if (rawSubjects is List) {
      for (final entry in rawSubjects) {
        if (entry is String && entry.trim().isNotEmpty) {
          subjects.add(entry.trim());
        }
      }
    }

    final rawDate = map['first_publish_date'];
    String? firstPublishDate;
    if (rawDate is String && rawDate.trim().isNotEmpty) {
      firstPublishDate = rawDate.trim();
    }

    final rawTitle = map['title'];
    String? title;
    if (rawTitle is String && rawTitle.trim().isNotEmpty) {
      title = rawTitle.trim();
    }

    return OpenLibraryWork(
      title: title,
      description: description,
      subjects: subjects,
      firstPublishDate: firstPublishDate,
    );
  }
}

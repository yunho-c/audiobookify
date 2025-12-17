import 'package:flutter/material.dart';

/// Represents a chapter in an audiobook
class Chapter {
  final int id;
  final String title;
  final String duration;

  const Chapter({
    required this.id,
    required this.title,
    required this.duration,
  });
}

/// Represents an audiobook with metadata and chapters
class Book {
  final int id;
  final String title;
  final String author;
  final String duration;
  final List<Color> gradientColors;
  final Color accentColor;
  final String description;
  final List<Chapter> chapters;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.gradientColors,
    required this.accentColor,
    required this.description,
    required this.chapters,
  });
}

/// Mock data matching the React reference
final List<Book> mockBooks = [
  Book(
    id: 1,
    title: "The Quantum Paradox",
    author: "Sarah J. Vance",
    duration: "8h 12m",
    gradientColors: [Colors.purple.shade500, Colors.indigo.shade600],
    accentColor: Colors.purple.shade500,
    description:
        "A journey through time and space where reality bends at the will of a single observer.",
    chapters: const [
      Chapter(id: 1, title: "Chapter 1: The Incident", duration: "15:20"),
      Chapter(id: 2, title: "Chapter 2: Event Horizon", duration: "22:15"),
      Chapter(id: 3, title: "Chapter 3: Schrödinger's Cat", duration: "18:45"),
      Chapter(id: 4, title: "Chapter 4: The Void", duration: "25:10"),
    ],
  ),
  Book(
    id: 2,
    title: "Midnight in Kyoto",
    author: "Hiroshi Tanaka",
    duration: "6h 45m",
    gradientColors: [Colors.red.shade500, Colors.orange.shade600],
    accentColor: Colors.red.shade500,
    description:
        "A neon-noir mystery set in the winding streets of futuristic Kyoto.",
    chapters: const [
      Chapter(id: 1, title: "Chapter 1: Red Lanterns", duration: "12:30"),
      Chapter(id: 2, title: "Chapter 2: The Tea House", duration: "19:20"),
      Chapter(id: 3, title: "Chapter 3: Silent Blade", duration: "21:05"),
    ],
  ),
  Book(
    id: 3,
    title: "Echoes of the Deep",
    author: "Marina Waters",
    duration: "10h 05m",
    gradientColors: [Colors.cyan.shade500, Colors.blue.shade700],
    accentColor: Colors.cyan.shade500,
    description:
        "Submarine warfare meets cosmic horror in this gripping thriller.",
    chapters: const [
      Chapter(id: 1, title: "Chapter 1: Dive", duration: "30:00"),
      Chapter(id: 2, title: "Chapter 2: Pressure", duration: "28:15"),
      Chapter(id: 3, title: "Chapter 3: The Signal", duration: "32:40"),
    ],
  ),
  Book(
    id: 4,
    title: "Silicon Dreams",
    author: "Alex Chen",
    duration: "9h 20m",
    gradientColors: [Colors.teal.shade400, Colors.teal.shade600],
    accentColor: Colors.teal.shade500,
    description: "The rise and fall of a tech empire built on a lie.",
    chapters: const [
      Chapter(id: 1, title: "Chapter 1: IPO", duration: "14:10"),
      Chapter(id: 2, title: "Chapter 2: The Bug", duration: "16:55"),
    ],
  ),
];

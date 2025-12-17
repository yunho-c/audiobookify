import 'package:flutter/material.dart';

class Book {
  final int id;
  final String title;
  final String author;
  final String cover;
  final int progress;
  final String duration;
  final String timeLeft;
  final String description;
  final Color gradientStart;
  final Color gradientEnd;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.cover,
    required this.progress,
    required this.duration,
    required this.timeLeft,
    required this.description,
    required this.gradientStart,
    required this.gradientEnd,
  });

  static const List<Book> mockBooks = [
    Book(
      id: 1,
      title: "The Silent Stars",
      author: "Elena Fisher",
      cover:
          "https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=600&auto=format&fit=crop",
      progress: 45,
      duration: "12h 30m",
      timeLeft: "6h 15m",
      description:
          "A journey through the cosmos seeking silence in a noisy universe.",
      gradientStart: Color(0xFF1E3A5F), // blue-900
      gradientEnd: Color(0xFF0F172A), // slate-900
    ),
    Book(
      id: 2,
      title: "Echoes of Old",
      author: "Marcus Thorne",
      cover:
          "https://images.unsplash.com/photo-1461360370896-922624d12aa1?q=80&w=600&auto=format&fit=crop",
      progress: 12,
      duration: "8h 45m",
      timeLeft: "7h 30m",
      description: "History refuses to stay buried in this gripping mystery.",
      gradientStart: Color(0xFF78350F), // amber-900
      gradientEnd: Color(0xFF1C1917), // stone-900
    ),
    Book(
      id: 3,
      title: "Neon Dreams",
      author: "Sarah J. Watts",
      cover:
          "https://images.unsplash.com/photo-1555680202-c86f0e12f086?q=80&w=600&auto=format&fit=crop",
      progress: 0,
      duration: "10h 15m",
      timeLeft: "10h 15m",
      description: "Cyberpunk noir thriller set in the year 2089.",
      gradientStart: Color(0xFF581C87), // purple-900
      gradientEnd: Color(0xFF312E81), // indigo-900
    ),
    Book(
      id: 4,
      title: "Mountain Path",
      author: "David Chen",
      cover:
          "https://images.unsplash.com/photo-1519681393784-d120267933ba?q=80&w=600&auto=format&fit=crop",
      progress: 88,
      duration: "6h 20m",
      timeLeft: "45m",
      description: "Finding peace one step at a time in the Himalayas.",
      gradientStart: Color(0xFF064E3B), // emerald-900
      gradientEnd: Color(0xFF134E4A), // teal-900
    ),
    Book(
      id: 5,
      title: "Abstract Minds",
      author: "Dr. Emily Ray",
      cover:
          "https://images.unsplash.com/photo-1541963463532-d68292c34b19?q=80&w=600&auto=format&fit=crop",
      progress: 0,
      duration: "14h 00m",
      timeLeft: "14h 00m",
      description: "Understanding the psychology of creativity.",
      gradientStart: Color(0xFF831843), // pink-900
      gradientEnd: Color(0xFF881337), // rose-900
    ),
  ];
}

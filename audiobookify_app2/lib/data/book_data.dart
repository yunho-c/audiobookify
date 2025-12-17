import 'package:flutter/material.dart';

/// Book binding style affects spine decoration
enum BookStyle { classic, leather, cloth, modern }

/// A chapter within a book
class Chapter {
  final int id;
  final String title;
  final String text;

  const Chapter({
    required this.id,
    required this.title,
    required this.text,
  });
}

/// Book model with all styling and content information
class Book {
  final int id;
  final String title;
  final String author;
  final Color color;
  final Color spineColor;
  final List<Color> coverGradient;
  final Color textColor;
  final int pages;
  final String duration;
  final BookStyle style;
  final double heightVar;
  final List<Chapter> chapters;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.color,
    required this.spineColor,
    required this.coverGradient,
    required this.textColor,
    required this.pages,
    required this.duration,
    required this.style,
    required this.heightVar,
    required this.chapters,
  });

  /// Whether to use gold or silver text stamp
  bool get useSilverStamp => textColor == const Color(0xFFDBEAFE);
}

/// Base book templates
const _baseBooks = [
  (
    title: "Robinson Crusoe",
    author: "Daniel Defoe",
    color: Color(0xFF052e16),
    spineColor: Color(0xFF14532d),
    coverGradient: [Color(0xFF14532d), Color(0xFF166534)],
    textColor: Color(0xFFDCFCE7),
    pages: 296,
    duration: "6h 12m",
    style: BookStyle.classic,
  ),
  (
    title: "Moby Dick",
    author: "Herman Melville",
    color: Color(0xFF0f172a),
    spineColor: Color(0xFF1e3a8a),
    coverGradient: [Color(0xFF0f172a), Color(0xFF1e293b)],
    textColor: Color(0xFFDBEAFE),
    pages: 600,
    duration: "13h 20m",
    style: BookStyle.leather,
  ),
  (
    title: "Emma",
    author: "Jane Austen",
    color: Color(0xFF4a044e),
    spineColor: Color(0xFF831843),
    coverGradient: [Color(0xFF701a75), Color(0xFF881337)],
    textColor: Color(0xFFFFE4E6),
    pages: 400,
    duration: "8h 20m",
    style: BookStyle.cloth,
  ),
  (
    title: "Dune",
    author: "Frank Herbert",
    color: Color(0xFF451a03),
    spineColor: Color(0xFF7c2d12),
    coverGradient: [Color(0xFF7c2d12), Color(0xFF78350f)],
    textColor: Color(0xFFFEF3C7),
    pages: 800,
    duration: "20h 00m",
    style: BookStyle.leather,
  ),
  (
    title: "1984",
    author: "George Orwell",
    color: Color(0xFF18181b),
    spineColor: Color(0xFF27272a),
    coverGradient: [Color(0xFF09090b), Color(0xFF27272a)],
    textColor: Color(0xFFF4F4F5),
    pages: 328,
    duration: "6h 40m",
    style: BookStyle.classic,
  ),
];

/// Sample chapters for each book
const _sampleChapters = [
  Chapter(
    id: 1,
    title: "Chapter One",
    text:
        "It was a bright cold day in April, and the clocks were striking thirteen. Winston Smith, his chin nuzzled into his breast in an effort to escape the vile wind, slipped quickly through the glass doors of Victory Mansions, though not quickly enough to prevent a swirl of gritty dust from entering along with him.",
  ),
  Chapter(
    id: 2,
    title: "Chapter Two",
    text:
        "The hallway smelt of boiled cabbage and old rag mats. At one end of it a coloured poster, too large for indoor display, had been tacked to the wall. It depicted simply an enormous face, more than a metre wide: the face of a man of about forty-five, with a heavy black moustache and ruggedly handsome features.",
  ),
  Chapter(
    id: 3,
    title: "Chapter Three",
    text:
        "Winston Smith, his chin nuzzled into his breast in an effort to escape the vile wind, slipped quickly through the glass doors of Victory Mansions, though not quickly enough to prevent a swirl of gritty dust from entering along with him. The hallway smelt of boiled cabbage and old rag mats.",
  ),
];

/// Generate 28 books from the 5 templates
List<Book> generateBooks() {
  final books = <Book>[];
  for (int i = 0; i < 28; i++) {
    final template = _baseBooks[i % _baseBooks.length];
    books.add(Book(
      id: i + 1,
      title: template.title,
      author: template.author,
      color: template.color,
      spineColor: template.spineColor,
      coverGradient: template.coverGradient,
      textColor: template.textColor,
      pages: template.pages,
      duration: template.duration,
      style: template.style,
      heightVar: (i * 17 % 40).toDouble(), // Pseudo-random height variation
      chapters: _sampleChapters,
    ));
  }
  return books;
}

/// Organize books into shelves
List<List<Book>> organizeBooksIntoShelves(List<Book> books,
    {int shelfCapacity = 14}) {
  final shelves = <List<Book>>[];
  for (int i = 0; i < books.length; i += shelfCapacity) {
    shelves.add(books.sublist(
      i,
      (i + shelfCapacity > books.length) ? books.length : i + shelfCapacity,
    ));
  }
  return shelves;
}

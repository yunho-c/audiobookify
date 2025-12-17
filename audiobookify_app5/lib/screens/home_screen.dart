import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../widgets/book_card.dart';

/// Home screen with book grid and "Continue listening" header
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final books = [
      BookData(
        id: '1',
        title: 'Adventures of Robinson Crusoe',
        author: 'Daniel Defoe',
        color: AppColors.emerald700,
        progress: 45,
      ),
      BookData(
        id: '2',
        title: 'The Great Gatsby',
        author: 'F. Scott Fitzgerald',
        color: AppColors.indigo700,
        progress: 0,
      ),
      BookData(
        id: '3',
        title: 'Moby Dick',
        author: 'Herman Melville',
        color: AppColors.slate700,
        progress: 12,
      ),
      BookData(
        id: '4',
        title: 'Pride and Prejudice',
        author: 'Jane Austen',
        color: AppColors.rose700,
        progress: 0,
      ),
      BookData(
        id: '5',
        title: '1984',
        author: 'George Orwell',
        color: AppColors.amber800,
        progress: 88,
      ),
      BookData(
        id: '6',
        title: 'To Kill a Mockingbird',
        author: 'Harper Lee',
        color: AppColors.sky700,
        progress: 0,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.stone50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Header
              Text(
                'Audiobookify',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.stone800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Continue listening',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.stone500,
                ),
              ),
              const SizedBox(height: 32),
              // Book grid
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = _getCrossAxisCount(
                      constraints.maxWidth,
                    );
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 2 / 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: books.length + 1, // +1 for add button
                      itemBuilder: (context, index) {
                        if (index < books.length) {
                          final book = books[index];
                          return BookCard(
                            id: book.id,
                            title: book.title,
                            author: book.author,
                            color: book.color,
                            progress: book.progress,
                          );
                        } else {
                          return const AddBookCard();
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getCrossAxisCount(double width) {
    if (width >= 1000) return 5;
    if (width >= 800) return 4;
    if (width >= 600) return 3;
    return 2;
  }
}

class BookData {
  final String id;
  final String title;
  final String author;
  final Color color;
  final int progress;

  const BookData({
    required this.id,
    required this.title,
    required this.author,
    required this.color,
    this.progress = 0,
  });
}

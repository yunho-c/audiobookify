import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';
import '../core/providers.dart';
import '../widgets/book_card.dart';
import '../models/book.dart';

/// Home screen with book grid from ObjectBox database
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);

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
              booksAsync.when(
                data: (books) => Text(
                  books.isEmpty ? 'Your library is empty' : 'Your library',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.stone500,
                  ),
                ),
                loading: () => Text(
                  'Loading...',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.stone500,
                  ),
                ),
                error: (_, __) => Text(
                  'Error loading library',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.stone500,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Book grid
              Expanded(
                child: booksAsync.when(
                  data: (books) => books.isEmpty
                      ? _buildEmptyState(context)
                      : _buildBookGrid(context, books),
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.orange600,
                    ),
                  ),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.stone100,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              LucideIcons.bookOpen,
              size: 48,
              color: AppColors.stone300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No books yet',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.stone700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Import an EPUB to get started',
            style: GoogleFonts.inter(fontSize: 16, color: AppColors.stone500),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go('/create'),
            icon: const Icon(LucideIcons.upload, size: 20),
            label: Text(
              'Import EPUB',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookGrid(BuildContext context, List<Book> books) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
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
              return BookCard.fromBook(book);
            } else {
              return const AddBookCard();
            }
          },
        );
      },
    );
  }

  int _getCrossAxisCount(double width) {
    if (width >= 1000) return 5;
    if (width >= 800) return 4;
    if (width >= 600) return 3;
    return 2;
  }
}

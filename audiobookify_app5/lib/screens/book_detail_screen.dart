import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';

/// Book detail screen with 3D cover, stats, and chapter list
class BookDetailScreen extends StatelessWidget {
  final String bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    // Mock book data
    final book = BookDetail(
      id: bookId,
      title: 'Adventures of Robinson Crusoe',
      author: 'Daniel Defoe',
      color: AppColors.emerald700,
      pages: 296,
      minutes: 372,
      chapters: [
        Chapter(id: 1, title: 'Fisherman', completed: true),
        Chapter(id: 2, title: 'Fireman', completed: true),
        Chapter(id: 3, title: 'Chef', completed: false),
        Chapter(id: 4, title: 'Alice', completed: false),
        Chapter(id: 5, title: 'Sendless', completed: false),
        Chapter(id: 6, title: 'Walrusay', completed: false),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.stone100,
      body: Stack(
        children: [
          // Scrollable content
          CustomScrollView(
            slivers: [
              // Colored header with gradient
              SliverToBoxAdapter(
                child: Container(
                  height: 256,
                  color: book.color,
                  child: Stack(
                    children: [
                      // Gradient overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withAlpha(75),
                                AppColors.stone100,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Back button
                      Positioned(
                        top: 48,
                        left: 24,
                        child: GestureDetector(
                          onTap: () => context.go('/'),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(50),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              LucideIcons.arrowLeft,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Content
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -128),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // 3D Book cover
                        _BookCover3D(book: book),
                        const SizedBox(height: 24),
                        // Stats
                        _StatsRow(book: book),
                        const SizedBox(height: 24),
                        // Chapter list
                        _ChapterList(book: book),
                        const SizedBox(height: 100), // Space for FAB
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Floating resume button
          Positioned(
            bottom: 24,
            right: 24,
            child: GestureDetector(
              onTap: () => context.push('/player/${book.id}'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.stone800,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.playCircle,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Resume',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCover3D extends StatelessWidget {
  final BookDetail book;

  const _BookCover3D({required this.book});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 192,
        height: 288,
        decoration: BoxDecoration(
          color: book.color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(75),
              blurRadius: 30,
              offset: const Offset(10, 20),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withAlpha(50),
                      Colors.black.withAlpha(25),
                    ],
                  ),
                ),
              ),
            ),
            // Spine effect
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(50),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              width: 1,
              child: Container(color: Colors.white.withAlpha(75)),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text(
                        book.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        book.author,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${book.id} // ${book.pages}pgs',
                    style: GoogleFonts.robotoMono(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: Colors.white.withAlpha(150),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final BookDetail book;

  const _StatsRow({required this.book});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatItem(
          icon: LucideIcons.bookOpen,
          value: '${book.pages}',
          label: 'Pages',
        ),
        Container(
          width: 1,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 32),
          color: AppColors.stone300,
        ),
        _StatItem(
          icon: LucideIcons.clock,
          value: '${book.minutes}',
          label: 'Est. Mins',
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.stone400),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.stone600,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w500,
            color: AppColors.stone400,
          ),
        ),
      ],
    );
  }
}

class _ChapterList extends StatelessWidget {
  final BookDetail book;

  const _ChapterList({required this.book});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chapters',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.stone800,
            ),
          ),
          const SizedBox(height: 16),
          ...book.chapters.map(
            (chapter) => _ChapterItem(chapter: chapter, bookId: book.id),
          ),
        ],
      ),
    );
  }
}

class _ChapterItem extends StatelessWidget {
  final Chapter chapter;
  final String bookId;

  const _ChapterItem({required this.chapter, required this.bookId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/player/$bookId?chapter=${chapter.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '${chapter.id}.',
                style: GoogleFonts.robotoMono(
                  fontSize: 14,
                  color: AppColors.stone300,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                chapter.title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.stone700,
                ),
              ),
            ),
            Icon(
              chapter.completed ? LucideIcons.checkCircle2 : LucideIcons.circle,
              size: 20,
              color: chapter.completed
                  ? AppColors.emerald600
                  : AppColors.stone300,
            ),
          ],
        ),
      ),
    );
  }
}

class BookDetail {
  final String id;
  final String title;
  final String author;
  final Color color;
  final int pages;
  final int minutes;
  final List<Chapter> chapters;

  const BookDetail({
    required this.id,
    required this.title,
    required this.author,
    required this.color,
    required this.pages,
    required this.minutes,
    required this.chapters,
  });
}

class Chapter {
  final int id;
  final String title;
  final bool completed;

  const Chapter({
    required this.id,
    required this.title,
    required this.completed,
  });
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../models/book.dart';

/// Book card widget with 2:3 aspect ratio, gradient overlay, and spine effect
class BookCard extends StatelessWidget {
  final int id;
  final String title;
  final String author;
  final Color? color;
  final Uint8List? coverImage;
  final int progress;

  const BookCard({
    super.key,
    required this.id,
    required this.title,
    required this.author,
    this.color,
    this.coverImage,
    this.progress = 0,
  });

  /// Factory to create BookCard from a Book model
  factory BookCard.fromBook(Book book) {
    return BookCard(
      id: book.id,
      title: book.title ?? 'Unknown',
      author: book.author ?? 'Unknown Author',
      coverImage: book.coverImage,
      progress: book.progress,
    );
  }

  @override
  Widget build(BuildContext context) {
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final fallbackPalette = const <Color>[
      AppColors.emerald700,
      AppColors.indigo700,
      AppColors.slate700,
      AppColors.rose700,
      AppColors.amber800,
      AppColors.sky700,
    ];
    final palette = extras?.bookCoverPalette ?? fallbackPalette;
    final bgColor = color ?? palette[id % palette.length];

    return GestureDetector(
      onTap: () => context.push('/book/$id'),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Cover image (if available)
              if (coverImage != null)
                Positioned.fill(
                  child: Image.memory(coverImage!, fit: BoxFit.cover),
                ),
              // Gradient overlay for text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: coverImage != null
                          ? [Colors.transparent, Colors.black.withAlpha(180)]
                          : [
                              Colors.white.withAlpha(50),
                              Colors.black.withAlpha(25),
                            ],
                    ),
                  ),
                ),
              ),
              // Spine effect - dark edge
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 6,
                child: Container(color: Colors.black.withAlpha(50)),
              ),
              // Spine effect - highlight
              Positioned(
                left: 6,
                top: 0,
                bottom: 0,
                width: 1,
                child: Container(color: Colors.white.withAlpha(75)),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and author
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: coverImage != null
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            author,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withAlpha(200),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Progress indicator or book icon
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(50),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: progress > 0
                              ? Text(
                                  '$progress%',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.book_outlined,
                                  size: 14,
                                  color: Colors.white.withAlpha(200),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Progress bar at bottom
              if (progress > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 4,
                  child: Stack(
                    children: [
                      Container(color: Colors.black.withAlpha(75)),
                      FractionallySizedBox(
                        widthFactor: progress / 100,
                        child: Container(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add book placeholder card with dashed border
class AddBookCard extends StatelessWidget {
  const AddBookCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/create'),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: CustomPaint(
            painter: DashedBorderPainter(
              color: Theme.of(context).colorScheme.outline,
              strokeWidth: 2,
              dashWidth: 8,
              dashSpace: 4,
              borderRadius: 12,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      '+',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add Book',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for dashed border effect
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // We use the container's border instead, this is optional decoration
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

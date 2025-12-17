import 'package:flutter/material.dart';
import '../models/book.dart';
import '../theme.dart';
import '../widgets/book_cover_3d.dart';

/// Library grid screen showing all books
class LibraryScreen extends StatelessWidget {
  final Function(Book) onBookSelect;

  const LibraryScreen({super.key, required this.onBookSelect});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive columns: 4 for desktop, 3 for tablet, 2 for mobile
    int crossAxisCount;
    if (screenWidth >= 1200) {
      crossAxisCount = 4;
    } else if (screenWidth >= 800) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 2;
    }

    return Stack(
      children: [
        // Ambient gradient blobs
        Positioned(
          top: -100,
          left: -50,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppColors.indigo.withOpacity(0.2), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          right: -50,
          child: Container(
            width: 350,
            height: 450,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.blue.shade900.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Main content
        SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth >= 768 ? 48 : 24,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'My Library',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Continue where you left off',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 48),

              // Book grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.55,
                  crossAxisSpacing: screenWidth >= 768 ? 48 : 32,
                  mainAxisSpacing: screenWidth >= 768 ? 48 : 32,
                ),
                itemCount: mockBooks.length,
                itemBuilder: (context, index) {
                  final book = mockBooks[index];
                  return _BookGridItem(
                    book: book,
                    onTap: () => onBookSelect(book),
                  );
                },
              ),

              const SizedBox(height: 100), // Bottom padding for mobile nav
            ],
          ),
        ),
      ],
    );
  }
}

/// Individual book item in the grid
class _BookGridItem extends StatefulWidget {
  final Book book;
  final VoidCallback onTap;

  const _BookGridItem({required this.book, required this.onTap});

  @override
  State<_BookGridItem> createState() => _BookGridItemState();
}

class _BookGridItemState extends State<_BookGridItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 3D Book cover with lift effect
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..translate(0.0, _isHovered ? -16.0 : 0.0),
            child: BookCover3D(
              gradientColors: widget.book.gradientColors,
              title: widget.book.title,
              author: widget.book.author,
              onTap: widget.onTap,
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            widget.book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          // Author
          Text(
            widget.book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

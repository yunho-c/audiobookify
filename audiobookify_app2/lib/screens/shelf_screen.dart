import 'package:flutter/material.dart';
import '../data/book_data.dart';
import '../theme/app_theme.dart';
import '../widgets/book_spine.dart';

/// Main bookshelf view with scrollable shelves
class ShelfScreen extends StatelessWidget {
  final List<List<Book>> shelves;
  final void Function(Book book, Rect rect) onBookTap;
  final bool isBlurred;

  const ShelfScreen({
    super.key,
    required this.shelves,
    required this.onBookTap,
    this.isBlurred = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: isBlurred ? 0.3 : 1.0,
      child: IgnorePointer(
        ignoring: isBlurred,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 48, bottom: 128),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1024),
              child: Column(
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.only(bottom: 64),
                    child: Text(
                      'Audiobookify',
                      style: AppTextStyles.title(context),
                    ),
                  ),

                  // Shelves
                  ...shelves.map((shelfBooks) => _Shelf(
                        books: shelfBooks,
                        onBookTap: onBookTap,
                      )),

                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single wooden shelf with books
class _Shelf extends StatelessWidget {
  final List<Book> books;
  final void Function(Book book, Rect rect) onBookTap;

  const _Shelf({
    required this.books,
    required this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Wooden shelf plank
          Positioned(
            left: -16,
            right: -16,
            bottom: -16,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.shelfWood,
                borderRadius: BorderRadius.circular(2),
                border: const Border(
                  top: BorderSide(color: AppColors.shelfBorder, width: 1),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x80000000),
                    offset: Offset(0, 10),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0x80000000),
                      Colors.transparent,
                      Color(0x80000000),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Books row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: books.map((book) {
                return _HoverableBookSpine(
                  book: book,
                  onTap: onBookTap,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Book spine with hover lift effect
class _HoverableBookSpine extends StatefulWidget {
  final Book book;
  final void Function(Book book, Rect rect) onTap;

  const _HoverableBookSpine({
    required this.book,
    required this.onTap,
  });

  @override
  State<_HoverableBookSpine> createState() => _HoverableBookSpineState();
}

class _HoverableBookSpineState extends State<_HoverableBookSpine> {
  bool _isHovered = false;
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        key: _key,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -16 : 0, 0),
        child: BookSpine(
          book: widget.book,
          onTap: () {
            final renderBox =
                _key.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final position = renderBox.localToGlobal(Offset.zero);
              final size = renderBox.size;
              final rect = Rect.fromLTWH(
                position.dx,
                position.dy,
                size.width,
                size.height,
              );
              widget.onTap(widget.book, rect);
            }
          },
        ),
      ),
    );
  }
}

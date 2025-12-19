import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';
import '../widgets/book_card.dart';
import '../main.dart'; // For bookService
import '../models/book.dart';

/// Home screen with book grid from ObjectBox database
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Book> _books = [];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  void _loadBooks() {
    setState(() {
      _books = bookService.getAllBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                _books.isEmpty ? 'Your library is empty' : 'Your library',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.stone500,
                ),
              ),
              const SizedBox(height: 32),
              // Book grid
              Expanded(
                child: _books.isEmpty
                    ? _buildEmptyState(context)
                    : _buildBookGrid(context),
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

  Widget _buildBookGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
        return RefreshIndicator(
          onRefresh: () async => _loadBooks(),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 2 / 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _books.length + 1, // +1 for add button
            itemBuilder: (context, index) {
              if (index < _books.length) {
                final book = _books[index];
                return _BookCardFromDb(book: book);
              } else {
                return const AddBookCard();
              }
            },
          ),
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

/// Book card that displays data from ObjectBox - matches original BookCard aesthetics
class _BookCardFromDb extends StatelessWidget {
  final Book book;

  const _BookCardFromDb({required this.book});

  @override
  Widget build(BuildContext context) {
    final color = _getColorForBook(book.id);

    return GestureDetector(
      onTap: () => context.push('/book/${book.id}'),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          decoration: BoxDecoration(
            color: color,
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
              // Cover image (if available) - fills the entire card
              if (book.coverImage != null)
                Positioned.fill(
                  child: Image.memory(book.coverImage!, fit: BoxFit.cover),
                ),
              // Gradient overlay for text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: book.coverImage != null
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
                        mainAxisAlignment: book.coverImage != null
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Text(
                            book.title ?? 'Unknown',
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
                            book.author ?? 'Unknown Author',
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
                          child: book.progress > 0
                              ? Text(
                                  '${book.progress}%',
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
              if (book.progress > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 4,
                  child: Stack(
                    children: [
                      Container(color: Colors.black.withAlpha(75)),
                      FractionallySizedBox(
                        widthFactor: book.progress / 100,
                        child: Container(color: AppColors.orange400),
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

  Color _getColorForBook(int id) {
    final colors = [
      AppColors.emerald700,
      AppColors.indigo700,
      AppColors.slate700,
      AppColors.rose700,
      AppColors.amber800,
      AppColors.sky700,
    ];
    return colors[id % colors.length];
  }
}

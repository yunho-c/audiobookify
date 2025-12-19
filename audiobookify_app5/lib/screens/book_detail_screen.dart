import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';
import '../core/providers.dart';
import '../models/book.dart';
import '../src/rust/api/epub.dart';

/// Book detail screen with cover, stats, and chapter list
class BookDetailScreen extends ConsumerStatefulWidget {
  final String bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  Book? _book;
  EpubBook? _epubBook;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Future<void> _loadBook() async {
    try {
      final bookId = int.tryParse(widget.bookId);
      if (bookId == null) {
        setState(() {
          _error = 'Invalid book ID';
          _isLoading = false;
        });
        return;
      }

      // Load book from ObjectBox
      final book = ref.read(bookServiceProvider).getBook(bookId);
      if (book == null) {
        setState(() {
          _error = 'Book not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _book = book;
      });

      // Load EPUB to get TOC and chapters
      try {
        final epub = await openEpub(path: book.filePath);
        setState(() {
          _epubBook = epub;
          _isLoading = false;
        });
      } catch (e) {
        // EPUB file might be gone, but we still have metadata
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getColor() {
    if (_book == null) return AppColors.emerald700;
    final colors = [
      AppColors.emerald700,
      AppColors.indigo700,
      AppColors.slate700,
      AppColors.rose700,
      AppColors.amber800,
      AppColors.sky700,
    ];
    return colors[_book!.id % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.stone100,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.orange600),
        ),
      );
    }

    if (_error != null || _book == null) {
      return Scaffold(
        backgroundColor: AppColors.stone100,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: AppColors.stone800),
            onPressed: () => context.go('/'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.alertCircle,
                size: 48,
                color: AppColors.stone400,
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Book not found',
                style: GoogleFonts.inter(color: AppColors.stone600),
              ),
            ],
          ),
        ),
      );
    }

    final book = _book!;
    final color = _getColor();

    return Scaffold(
      backgroundColor: AppColors.stone100,
      body: Stack(
        children: [
          // All content in one scroll view - header is part of scroll, painted FIRST
          SingleChildScrollView(
            child: Column(
              children: [
                // Header background (scrolls with content)
                Container(
                  height: 256,
                  color: color,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Cover image as background (translucent)
                      if (book.coverImage != null)
                        Opacity(
                          opacity: 0.3,
                          child: Image.memory(
                            book.coverImage!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      // Gradient overlay
                      DecoratedBox(
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
                    ],
                  ),
                ),
                // Book cover - overlaps into header (painted AFTER header, so on top)
                Transform.translate(
                  offset: const Offset(0, -144),
                  child: Center(
                    child: _BookCover3D(book: book, color: color),
                  ),
                ),
                // Content (with negative margin to account for overlap)
                Transform.translate(
                  offset: const Offset(0, -120),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _StatsRow(book: book),
                        const SizedBox(height: 24),
                        _ChapterList(
                          bookId: book.id,
                          toc: _epubBook?.toc ?? [],
                          chapters: _epubBook?.chapters ?? [],
                        ),
                        const SizedBox(height: 100), // Space for FAB
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Back button - on top of scroll
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
          // Floating play button
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
                      book.progress > 0 ? 'Resume' : 'Start',
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
  final Book book;
  final Color color;

  const _BookCover3D({required this.book, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 192,
        height: 288,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(75),
              blurRadius: 30,
              offset: const Offset(10, 20),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Cover image if available
            if (book.coverImage != null)
              Positioned.fill(
                child: Image.memory(book.coverImage!, fit: BoxFit.cover),
              ),
            // Gradient overlay for text readability
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: book.coverImage != null
                        ? const [0.0, 0.4, 1.0]
                        : null,
                    colors: book.coverImage != null
                        ? [
                            Colors.black.withAlpha(50),
                            Colors.transparent,
                            Colors.black.withAlpha(220),
                          ]
                        : [
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
            // Content - show at bottom when cover image exists
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title ?? 'Unknown',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
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
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(200),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Book book;

  const _StatsRow({required this.book});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatItem(
          icon: LucideIcons.bookOpen,
          value: '${book.chapterCount}',
          label: 'Chapters',
        ),
        Container(
          width: 1,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 32),
          color: AppColors.stone300,
        ),
        _StatItem(
          icon: LucideIcons.percent,
          value: '${book.progress}',
          label: 'Progress',
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
  final int bookId;
  final List<TocEntry> toc;
  final List<ChapterInfo> chapters;

  const _ChapterList({
    required this.bookId,
    required this.toc,
    required this.chapters,
  });

  @override
  Widget build(BuildContext context) {
    // Use TOC if available, otherwise fall back to chapters
    final items = toc.isNotEmpty
        ? toc
        : chapters
              .map(
                (c) => _ChapterItem(
                  id: c.index.toInt(),
                  title: c.id ?? 'Chapter ${c.index}',
                ),
              )
              .toList();

    if (items.isEmpty) {
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
          children: [
            const Icon(
              LucideIcons.fileText,
              size: 32,
              color: AppColors.stone300,
            ),
            const SizedBox(height: 12),
            Text(
              'No chapters available',
              style: GoogleFonts.inter(color: AppColors.stone500),
            ),
          ],
        ),
      );
    }

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
          if (toc.isNotEmpty)
            ...toc
                .where((t) => t.title.trim().isNotEmpty) // Filter empty titles
                .toList()
                .asMap()
                .entries
                .map(
                  (entry) => _TocItem(
                    index: entry.key + 1,
                    title: entry.value.title,
                    bookId: bookId,
                  ),
                )
          else
            ...chapters.asMap().entries.map(
              (entry) => _TocItem(
                index: entry.key + 1,
                title: entry.value.id ?? 'Chapter ${entry.key + 1}',
                bookId: bookId,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChapterItem {
  final int id;
  final String title;
  _ChapterItem({required this.id, required this.title});
}

class _TocItem extends StatelessWidget {
  final int index;
  final String title;
  final int bookId;

  const _TocItem({
    required this.index,
    required this.title,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/player/$bookId?chapter=$index'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$index.',
                style: GoogleFonts.robotoMono(
                  fontSize: 14,
                  color: AppColors.stone300,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.stone700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(LucideIcons.play, size: 16, color: AppColors.stone300),
          ],
        ),
      ),
    );
  }
}

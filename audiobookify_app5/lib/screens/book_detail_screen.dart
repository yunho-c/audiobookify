import 'dart:typed_data';
import 'dart:ui';
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

  Color _getColor(BuildContext context) {
    if (_book == null) return AppColors.emerald700;
    final palette =
        Theme.of(context).extension<AppThemeExtras>()?.bookCoverPalette ??
            const [
              AppColors.emerald700,
              AppColors.indigo700,
              AppColors.slate700,
              AppColors.rose700,
              AppColors.amber800,
              AppColors.sky700,
            ];
    return palette[_book!.id % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    if (_error != null || _book == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: colorScheme.onSurface),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.alertCircle,
                size: 48,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Book not found',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final book = _book!;
    final color = _getColor(context);
    final bookTitle = (book.title?.trim().isNotEmpty ?? false)
        ? book.title!.trim()
        : 'Untitled';
    final bookAuthor = (book.author?.trim().isNotEmpty ?? false)
        ? book.author!.trim()
        : 'Unknown author';
    final bookDescription = (book.description?.trim().isNotEmpty ?? false)
        ? book.description!.trim()
        : null;
    final metadata = <String>[
      if (book.language?.trim().isNotEmpty ?? false)
        book.language!.trim().toUpperCase(),
      if (book.publisher?.trim().isNotEmpty ?? false)
        book.publisher!.trim(),
      'Added ${book.addedAt.year}',
    ];
    final progress = (book.progress.clamp(0, 100)) / 100;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          _DetailBackdrop(
            coverImage: book.coverImage,
            fallbackColor: colorScheme.background,
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        _GlassIconButton(
                          icon: LucideIcons.arrowLeft,
                          onTap: () => context.pop(),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: _BookCover3D(book: book, color: color)),
                      const SizedBox(height: 20),
                      _StatsRow(book: book),
                      const SizedBox(height: 24),
                      Text(
                        bookTitle,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bookAuthor,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: metadata
                              .map((item) => _MetaChip(label: item))
                              .toList(),
                        ),
                      ],
                      if (bookDescription != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          bookDescription,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: colorScheme.surfaceVariant,
                          valueColor:
                              AlwaysStoppedAnimation(colorScheme.primary),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${book.progress}% listened',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FadeTap(
                        onTap: () => context.push('/player/${book.id}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .shadowColor
                                    .withAlpha(50),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.playCircle,
                                color: colorScheme.onPrimary,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                book.progress > 0 ? 'Resume' : 'Start',
                                style: textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ChapterList(
                        bookId: book.id,
                        toc: _epubBook?.toc ?? [],
                        chapters: _epubBook?.chapters ?? [],
                        progress: book.progress,
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
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
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Container(
        width: 200,
        height: 300,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withAlpha(60),
              blurRadius: 30,
              offset: const Offset(0, 18),
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
                  borderRadius: BorderRadius.circular(16),
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
                    left: Radius.circular(16),
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
                      style: textTheme.titleMedium?.copyWith(
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
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
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
    final colorScheme = Theme.of(context).colorScheme;
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
          color: colorScheme.outlineVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
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
  final int progress;

  const _ChapterList({
    required this.bookId,
    required this.toc,
    required this.chapters,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final filteredToc =
        toc.where((t) => t.title.trim().isNotEmpty).toList();
    final hasChapters = filteredToc.isNotEmpty || chapters.isNotEmpty;

    if (!hasChapters) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              LucideIcons.fileText,
              size: 32,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No chapters available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(15),
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          if (filteredToc.isNotEmpty)
            ...filteredToc.asMap().entries.map(
                  (entry) => _TocItem(
                    index: entry.key + 1,
                    title: entry.value.title,
                    bookId: bookId,
                    status: _chapterStatus(
                      entry.key + 1,
                      filteredToc.length,
                      progress,
                    ),
                  ),
                )
          else
            ...chapters.asMap().entries.map(
              (entry) => _TocItem(
                index: entry.key + 1,
                title: entry.value.id ?? 'Chapter ${entry.key + 1}',
                bookId: bookId,
                status: _chapterStatus(
                  entry.key + 1,
                  chapters.length,
                  progress,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _ChapterStatus { newChapter, inProgress, completed }

_ChapterStatus _chapterStatus(int index, int total, int progress) {
  if (total <= 0) return _ChapterStatus.newChapter;
  final normalized = (progress.clamp(0, 100)) / 100;
  if (normalized >= 1) return _ChapterStatus.completed;
  final exactProgress = normalized * total;
  final completedCount = exactProgress.floor();
  final hasPartial = exactProgress - completedCount > 0.001;

  if (index <= completedCount) {
    return _ChapterStatus.completed;
  }
  if (hasPartial && index == completedCount + 1) {
    return _ChapterStatus.inProgress;
  }
  return _ChapterStatus.newChapter;
}

class _TocItem extends StatelessWidget {
  final int index;
  final String title;
  final int bookId;
  final _ChapterStatus status;

  const _TocItem({
    required this.index,
    required this.title,
    required this.bookId,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return _FadeTap(
      onTap: () => context.push('/player/$bookId?chapter=$index'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$index.',
                style: GoogleFonts.robotoMono(
                  fontSize: 14,
                  color: colorScheme.outline,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _ChapterStatusPill(status: status),
          ],
        ),
      ),
    );
  }
}

class _ChapterStatusPill extends StatelessWidget {
  final _ChapterStatus status;

  const _ChapterStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String label;
    Color fg;
    Color bg;

    switch (status) {
      case _ChapterStatus.completed:
        label = 'Done';
        fg = colorScheme.primary;
        bg = colorScheme.primary.withAlpha(24);
        break;
      case _ChapterStatus.inProgress:
        label = 'Listening';
        fg = colorScheme.secondary;
        bg = colorScheme.secondary.withAlpha(24);
        break;
      case _ChapterStatus.newChapter:
        label = 'New';
        fg = colorScheme.onSurfaceVariant;
        bg = colorScheme.surfaceVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _DetailBackdrop extends StatelessWidget {
  final Uint8List? coverImage;
  final Color fallbackColor;

  const _DetailBackdrop({
    required this.coverImage,
    required this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(color: fallbackColor)),
        if (coverImage != null)
          Opacity(
            opacity: 0.45,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Image.memory(
                coverImage!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: fallbackColor.withAlpha(170),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface.withAlpha(70),
                fallbackColor.withAlpha(235),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final glassBackground =
        extras?.glassBackground ?? colorScheme.surface.withAlpha(200);
    final glassBorder =
        extras?.glassBorder ?? colorScheme.onSurface.withAlpha(40);
    final glassShadow =
        extras?.glassShadow ?? Theme.of(context).shadowColor.withAlpha(30);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: glassShadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: _FadeTap(
            onTap: onTap,
            pressedOpacity: 0.7,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: glassBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: glassBorder, width: 1),
              ),
              child: Icon(
                icon,
                color: colorScheme.onSurface,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FadeTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedOpacity;
  final Duration duration;

  const _FadeTap({
    required this.child,
    this.onTap,
    this.pressedOpacity = 0.75,
    this.duration = const Duration(milliseconds: 140),
  });

  @override
  State<_FadeTap> createState() => _FadeTapState();
}

class _FadeTapState extends State<_FadeTap> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        duration: widget.duration,
        opacity: _isPressed ? widget.pressedOpacity : 1,
        child: widget.child,
      ),
    );
  }
}

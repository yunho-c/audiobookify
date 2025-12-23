import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';
import '../core/error_reporter.dart';
import '../core/providers.dart';
import '../models/book.dart';
import '../src/rust/api/epub.dart';
import '../widgets/book_actions_sheet.dart';
import '../widgets/shared/glass_icon_button.dart';
import '../widgets/shared/pressable.dart';
import '../widgets/shared/state_scaffolds.dart';

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
  String? _epubLoadError;

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
        _epubLoadError = null;
      });

      // Load EPUB to get TOC and chapters
      try {
        final epub =
            await ref.read(epubServiceProvider).openEpub(book.filePath);
        if (!mounted) return;
        setState(() {
          _epubBook = epub;
          _isLoading = false;
        });
      } catch (e, stackTrace) {
        reportError(e, stackTrace, context: 'book_detail.loadEpub');
        // EPUB file might be gone, but we still have metadata
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _epubLoadError = e.toString();
        });
      }
    } catch (e) {
      if (!mounted) return;
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

  void _showBookActions(BuildContext context) {
    final book = _book;
    if (book == null) return;
    final title = (book.title?.trim().isNotEmpty ?? false)
        ? book.title!.trim()
        : 'Untitled';
    final author = (book.author?.trim().isNotEmpty ?? false)
        ? book.author!.trim()
        : 'Unknown author';
    showBookActionsSheet(
      context: context,
      title: title,
      author: author,
      coverImage: book.coverImage,
      onDelete: () async {
        final messenger = ScaffoldMessenger.of(context);
        final removed = await ref
            .read(bookServiceProvider)
            .deleteBookAndAssets(book.id);
        if (!mounted) return;
        if (removed) {
          ref.read(bookResumeProvider.notifier).clearPosition(book.id);
          messenger.showSnackBar(
            SnackBar(content: Text('Removed "$title" from library')),
          );
          context.pop();
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('Could not delete book')),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final debugEnabled = ref.watch(debugModeProvider);
    final resumePositions = ref.watch(bookResumeProvider);
    final resumePosition =
        _book == null ? null : resumePositions[_book!.id];
    if (_isLoading) {
      return const LoadingScaffold();
    }

    if (_error != null || _book == null) {
      return ErrorScaffold(
        message: _error ?? 'Book not found',
        onBack: () => context.pop(),
        messageAlign: TextAlign.center,
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
    final resumePath = resumePosition == null
        ? '/player/${book.id}'
        : '/player/${book.id}?chapter=${resumePosition.chapterIndex + 1}'
            '&paragraph=${resumePosition.paragraphIndex + 1}'
            '&sentence=${resumePosition.sentenceIndex + 1}';
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
                        GlassIconButton(
                          icon: LucideIcons.arrowLeft,
                          onTap: () => context.pop(),
                        ),
                        const Spacer(),
                        GlassIconButton(
                          icon: LucideIcons.moreVertical,
                          onTap: () => _showBookActions(context),
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
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.96, end: 1),
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Transform.scale(scale: value, child: child);
                        },
                        child: _BookCover3D(book: book, color: color),
                      ),
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
                      if (debugEnabled && _epubLoadError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.error.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                LucideIcons.alertTriangle,
                                size: 18,
                                color: colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'EPUB load failed: $_epubLoadError',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Pressable(
                        onTap: () => context.push(resumePath),
                        pressedScale: 1,
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
                                (resumePosition != null || book.progress > 0)
                                    ? 'Resume'
                                    : 'Start',
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

class _ChapterList extends ConsumerWidget {
  final int bookId;
  final List<TocEntry> toc;
  final List<ChapterInfo> chapters;
  final int progress;

  static const bool kPreferTocTitles = true;

  const _ChapterList({
    required this.bookId,
    required this.toc,
    required this.chapters,
    required this.progress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const bucketCount = 64;
    final filteredToc = toc
        .where(
          (entry) =>
              entry.title.trim().isNotEmpty && entry.href.trim().isNotEmpty,
        )
        .toList();
    final tocTitleByHref = <String, String>{};
    if (kPreferTocTitles) {
      for (final entry in filteredToc) {
        final key = _normalizeHref(entry.href);
        if (key.isNotEmpty) {
          tocTitleByHref[key] = entry.title.trim();
        }
      }
    }
    final hasChapters = chapters.isNotEmpty;

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
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 16),
          ...chapters.asMap().entries.map(
            (entry) {
              final index = entry.key + 1;
              return _TocItem(
                index: index,
                title: _chapterTitleFor(
                  entry.value,
                  index,
                  tocTitleByHref,
                ),
                bookId: bookId,
                status: _chapterStatus(
                  index,
                  chapters.length,
                  progress,
                ),
                bucketCount: bucketCount,
              );
            },
          ),
        ],
      ),
    );
  }
}

enum _ChapterStatus { newChapter, inProgress, completed }

String _chapterTitleFor(
  ChapterInfo chapter,
  int index,
  Map<String, String> tocTitleByHref,
) {
  if (_ChapterList.kPreferTocTitles) {
    final tocTitle = tocTitleByHref[_normalizeHref(chapter.href)];
    if (tocTitle != null && tocTitle.trim().isNotEmpty) {
      return tocTitle.trim();
    }
  }
  final fallback = chapter.id.trim();
  if (fallback.isNotEmpty) return fallback;
  return 'Chapter $index';
}

String _normalizeHref(String href) {
  final trimmed = href.trim();
  if (trimmed.isEmpty) return '';
  final withoutFragment = trimmed.split('#').first;
  if (withoutFragment.startsWith('./')) {
    return withoutFragment.substring(2);
  }
  return withoutFragment;
}

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

class _TocItem extends ConsumerWidget {
  final int index;
  final String title;
  final int bookId;
  final _ChapterStatus status;
  final int bucketCount;

  const _TocItem({
    required this.index,
    required this.title,
    required this.bookId,
    required this.status,
    required this.bucketCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final debugEnabled = ref.watch(debugModeProvider);
    final bucketState = ref.watch(
      bucketProgressProvider(
        BucketProgressArgs(
          bookId: bookId,
          chapterIndex: index,
          bucketCount: bucketCount,
        ),
      ),
    );
    final buckets = bucketState.value ?? Uint8List(bucketCount);
    final listenedCount = buckets.where((b) => b == 1).length;
    final percent = buckets.isEmpty
        ? 0
        : ((listenedCount / buckets.length) * 100).round();
    return Pressable(
      onTap: () => context.push('/player/$bookId?chapter=$index'),
      pressedScale: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Row(
                children: [
                  Expanded(
                    child: _BucketProgressBar(
                      buckets: buckets,
                      activeColor: colorScheme.primary,
                      inactiveColor: colorScheme.surfaceVariant,
                    ),
                  ),
                  if (debugEnabled) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$percent%',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
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

class _BucketProgressBar extends StatelessWidget {
  final Uint8List buckets;
  final Color activeColor;
  final Color inactiveColor;
  final double height;
  final double gap;
  final double activeOverlap;

  const _BucketProgressBar({
    required this.buckets,
    required this.activeColor,
    required this.inactiveColor,
    this.height = 1,
    this.gap = -2,
    this.activeOverlap = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: inactiveColor,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _BucketProgressPainter(
          buckets: buckets,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          gap: gap,
          activeOverlap: activeOverlap,
        ),
      ),
    );
  }
}

class _BucketProgressPainter extends CustomPainter {
  final Uint8List buckets;
  final Color activeColor;
  final Color inactiveColor;
  final double gap;
  final double activeOverlap;

  _BucketProgressPainter({
    required this.buckets,
    required this.activeColor,
    required this.inactiveColor,
    required this.gap,
    required this.activeOverlap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = buckets.length;
    if (count <= 0) return;
    final totalGap = gap * (count - 1);
    final segmentWidth = (size.width - totalGap) / count;
    if (segmentWidth <= 0) return;

    final activePaint = Paint()..color = activeColor;
    final inactivePaint = Paint()..color = inactiveColor;
    final radius = Radius.circular(size.height / 2);

    // Draw inactive baseline without overlap.
    var x = 0.0;
    for (var i = 0; i < count; i++) {
      final rect = Rect.fromLTWH(x, 0, segmentWidth, size.height);
      final rrect = RRect.fromRectAndRadius(rect, radius);
      canvas.drawRRect(rrect, inactivePaint);
      x += segmentWidth + gap;
    }

    if (activeOverlap <= 0) return;

    // Draw active buckets with overlap and rounding on top.
    x = 0.0;
    for (var i = 0; i < count; i++) {
      if (buckets[i] != 1) {
        x += segmentWidth + gap;
        continue;
      }
      final overlapRect = Rect.fromLTWH(
        x - (activeOverlap / 2),
        0,
        segmentWidth + activeOverlap,
        size.height,
      );
      final rrect = RRect.fromRectAndRadius(overlapRect, radius);
      canvas.drawRRect(rrect, activePaint);
      x += segmentWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _BucketProgressPainter oldDelegate) {
    return !listEquals(oldDelegate.buckets, buckets) ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.gap != gap ||
        oldDelegate.activeOverlap != activeOverlap;
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

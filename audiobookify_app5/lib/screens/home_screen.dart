import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';
import '../core/providers.dart';
import '../widgets/book_card.dart';
import '../widgets/book_actions_sheet.dart';
import '../widgets/shared/pressable.dart';
import '../widgets/shared/state_scaffolds.dart';
import '../models/book.dart';

/// Home screen with book grid from ObjectBox database
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _didPromptCrashReporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptCrashReporting();
    });
  }

  Future<void> _maybePromptCrashReporting() async {
    if (_didPromptCrashReporting || !mounted) return;
    const dsn = String.fromEnvironment('SENTRY_DSN');
    if (dsn.isEmpty) return;

    final prefs = ref.read(sharedPreferencesProvider);
    final hasPrompted = prefs.getBool(crashReportingPromptedKey) ?? false;
    if (hasPrompted) return;

    _didPromptCrashReporting = true;

    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Help improve Audiobookify'),
          content: const Text(
            'Share anonymous crash reports to help us fix issues faster. '
            'You can change this anytime in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Share Reports'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    await prefs.setBool(crashReportingPromptedKey, true);
    await ref
        .read(crashReportingProvider.notifier)
        .setEnabled(enable ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);
    return booksAsync.when(
      loading: () => const LoadingScaffold(),
      error: (e, _) => ErrorScaffold(message: 'Error: $e'),
      data: (books) {
        final subtitle =
            books.isEmpty ? 'Your library is empty' : 'Your library';
        final continueBook = _selectContinueBook(books);
        final continueChapter = continueBook != null
            ? _estimatedResumeChapter(continueBook)
            : null;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              const _HomeBackdrop(),
              SafeArea(
                child: books.isEmpty
                    ? CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                            sliver: SliverToBoxAdapter(
                              child: _Header(
                                subtitle: subtitle,
                              ),
                            ),
                          ),
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyState(context),
                          ),
                        ],
                      )
                    : CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                            sliver: SliverToBoxAdapter(
                              child: _Header(subtitle: subtitle),
                            ),
                          ),
                          if (continueBook != null)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                              sliver: SliverToBoxAdapter(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionHeader(
                                      title: 'Continue Listening',
                                    ),
                                    const SizedBox(height: 12),
                                    _ContinueListeningCard(
                                      book: continueBook,
                                      resumeChapter: continueChapter ?? 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                            sliver: SliverToBoxAdapter(
                              child: _SectionHeader(
                                title: 'Library',
                                subtitle: '${books.length} titles',
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                            sliver: _buildBookGrid(context, books),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              LucideIcons.bookOpen,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No books yet',
            style: textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Import an EPUB to get started',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go('/create'),
            icon: const Icon(LucideIcons.upload, size: 20),
            label: Text(
              'Import EPUB',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
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
    final width = MediaQuery.sizeOf(context).width - 48;
    final crossAxisCount = _getCrossAxisCount(width);
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index < books.length) {
            final book = books[index];
            return BookCard.fromBook(
              book,
              onLongPress: () => _showBookActions(context, book),
              longPressHaptic: PressableHaptic.medium,
            );
          }
          return const AddBookCard();
        },
        childCount: books.length + 1,
      ),
    );
  }

  int _getCrossAxisCount(double width) {
    if (width >= 1000) return 5;
    if (width >= 800) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  Book? _selectContinueBook(List<Book> books) {
    final inProgress = books
        .where((book) => book.progress > 0 && book.progress < 100)
        .toList();
    if (inProgress.isEmpty) return null;
    inProgress.sort((a, b) {
      final progressCompare = b.progress.compareTo(a.progress);
      if (progressCompare != 0) return progressCompare;
      return b.addedAt.compareTo(a.addedAt);
    });
    return inProgress.first;
  }

  int _estimatedResumeChapter(Book book) {
    if (book.chapterCount <= 0) return 1;
    final estimated = (book.progress / 100) * book.chapterCount;
    return estimated.clamp(1, book.chapterCount).ceil();
  }

  void _showBookActions(BuildContext context, Book book) {
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
        if (!context.mounted) return;
        if (removed) {
          messenger.showSnackBar(
            SnackBar(content: Text('Removed "$title" from library')),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('Could not delete book')),
          );
        }
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String subtitle;

  const _Header({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Audiobookify',
          style: textTheme.displayLarge?.copyWith(letterSpacing: -0.5),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _ContinueListeningCard extends StatelessWidget {
  final Book book;
  final int resumeChapter;

  const _ContinueListeningCard({
    required this.book,
    required this.resumeChapter,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = (book.progress.clamp(0, 100)) / 100;
    final chapterLabel = book.chapterCount > 0
        ? 'Chapter $resumeChapter of ${book.chapterCount}'
        : 'Resume listening';

    return Pressable(
      onTap: () =>
          context.push('/player/${book.id}?chapter=$resumeChapter'),
      haptic: PressableHaptic.selection,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withAlpha(20),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _CoverThumb(coverImage: book.coverImage),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title ?? 'Untitled',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.author ?? 'Unknown author',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chapterLabel,
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Resume',
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  final Uint8List? coverImage;

  const _CoverThumb({required this.coverImage});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      height: 72,
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: coverImage == null
          ? Icon(
              LucideIcons.bookOpen,
              color: colorScheme.onSurfaceVariant,
              size: 24,
            )
          : Image.memory(
              coverImage!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
    );
  }
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final palette = extras?.accentPalette ??
        const [
          AppColors.rose600,
          AppColors.amber600,
          AppColors.blue600,
          AppColors.emerald600,
        ];

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: colorScheme.background),
        ),
        Positioned(
          top: -120,
          left: -80,
          child: _GlowOrb(
            size: 260,
            color: palette[0].withAlpha(50),
          ),
        ),
        Positioned(
          bottom: -160,
          right: -80,
          child: _GlowOrb(
            size: 280,
            color: palette[2].withAlpha(40),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface.withAlpha(40),
                colorScheme.background.withAlpha(240),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

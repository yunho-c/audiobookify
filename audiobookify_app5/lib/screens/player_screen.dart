import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:html/parser.dart' as html_parser;
import '../core/app_theme.dart';
import '../core/providers.dart';
import '../core/route_observer.dart';
import '../services/book_service.dart';
import '../services/tts_service.dart';
import '../models/book.dart';
import '../models/player_theme_settings.dart';
import '../src/rust/api/epub.dart';
import '../widgets/settings_wheel.dart';

/// Player screen with text reader, TTS audio controls, and settings
class PlayerScreen extends ConsumerStatefulWidget {
  final String bookId;

  const PlayerScreen({super.key, required this.bookId});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> with RouteAware {
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _paragraphKeys = [];

  // Data
  Book? _book;
  EpubBook? _epubBook;
  List<String> _paragraphs = [];
  late final BookService _bookService;
  late final TtsService _ttsService;

  // UI-specific state (TTS state comes from provider)
  bool _isLoading = true;
  String? _error;
  bool _showSettings = false;
  int _currentChapterIndex = 0;
  int _lastScrolledToParagraph = -1;
  int _lastBucketParagraph = -1;

  @override
  void initState() {
    super.initState();
    _bookService = ref.read(bookServiceProvider);
    _ttsService = ref.read(ttsProvider.notifier);
    _initTts();
    _loadContent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPop() {
    if (mounted) {
      _ttsService.stop();
    }
    super.didPop();
  }

  @override
  void didPushNext() {
    if (mounted) {
      _ttsService.stop();
    }
    super.didPushNext();
  }

  Future<void> _initTts() async {
    // Set completion callback
    _ttsService.onComplete = () {
      if (!mounted) return;
      // Try to advance to next chapter
      if (_currentChapterIndex < (_epubBook?.chapters.length ?? 1) - 1) {
        _loadChapter(_currentChapterIndex + 1);
      } else {
        _saveProgress();
      }
    };
  }

  Future<void> _loadContent() async {
    try {
      final bookId = int.tryParse(widget.bookId);
      if (bookId == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Invalid book ID';
          _isLoading = false;
        });
        return;
      }

      // Load book from ObjectBox
      final book = _bookService.getBook(bookId);
      if (book == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Book not found';
          _isLoading = false;
        });
        return;
      }

      // Load EPUB
      final epub = await openEpub(path: book.filePath);

      if (!mounted) return;
      setState(() {
        _book = book;
        _epubBook = epub;
      });

      // Get chapter from query params
      final uri = GoRouterState.of(context).uri;
      final chapterParam = uri.queryParameters['chapter'];
      final chapterIndex = chapterParam != null
          ? (int.tryParse(chapterParam) ?? 1) - 1
          : 0;

      await _loadChapter(chapterIndex);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChapter(int index) async {
    if (_epubBook == null || !mounted) return;

    final chapters = _epubBook!.chapters;
    if (index < 0 || index >= chapters.length) return;

    final chapterContent = _epubBook!.chapterContents[index];
    final paragraphs = _extractParagraphs(chapterContent);

    if (!mounted) return;

    // Update local UI state
    setState(() {
      _currentChapterIndex = index;
      _paragraphs = paragraphs;
      _paragraphKeys =
          List.generate(paragraphs.length, (_) => GlobalKey());
      _lastScrolledToParagraph = -1;
      _lastBucketParagraph = -1;
      _isLoading = false;
    });

    // Load content into TTS provider
    final wasPlaying = _ttsService.state.status == TtsStatus.playing;
    _ttsService.loadContent(paragraphs);

    // Resume playback if we were playing
    if (wasPlaying) {
      await _ttsService.play();
    }
  }

  List<String> _extractParagraphs(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final body = document.body;
    if (body == null) return [];

    final paragraphs = <String>[];
    final textNodes = body.querySelectorAll('p, h1, h2, h3, h4, h5, h6');

    for (final node in textNodes) {
      final text = node.text.trim();
      if (text.isNotEmpty) {
        paragraphs.add(text);
      }
    }

    // If no paragraph tags, split by double newlines
    if (paragraphs.isEmpty) {
      final text = body.text.trim();
      paragraphs.addAll(
        text.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty),
      );
    }

    return paragraphs;
  }

  void _openSettings() {
    HapticFeedback.selectionClick();
    setState(() => _showSettings = true);
  }

  void _scrollToParagraph(int index) {
    if (index < 0 || index >= _paragraphKeys.length) return;
    final targetContext = _paragraphKeys[index].currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
      return;
    }

    final scrollPosition = index * 120.0;
    _scrollController.animateTo(
      scrollPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _updateBucketProgress(int paragraphIndex, int totalParagraphs) {
    if (_book == null) return;
    _bookService.markBucketProgress(
      bookId: _book!.id,
      chapterIndex: _currentChapterIndex + 1,
      paragraphIndex: paragraphIndex,
      totalParagraphs: totalParagraphs,
    );
  }

  void _togglePlayPause() async {
    HapticFeedback.lightImpact();
    final ttsState = _ttsService.state;

    if (ttsState.status == TtsStatus.playing) {
      await _ttsService.pause();
    } else {
      await _ttsService.play();
    }
  }

  void _previousChapter() {
    HapticFeedback.selectionClick();
    if (_currentChapterIndex > 0) {
      _loadChapter(_currentChapterIndex - 1);
    }
  }

  void _nextChapter() {
    HapticFeedback.selectionClick();
    if (_epubBook != null &&
        _currentChapterIndex < _epubBook!.chapters.length - 1) {
      _loadChapter(_currentChapterIndex + 1);
    }
  }

  void _saveProgress() {
    if (_book == null || _epubBook == null) return;

    final totalChapters = _epubBook!.chapters.length;
    final progress = (((_currentChapterIndex + 1) / totalChapters) * 100)
        .round();

    _bookService.updateProgress(_book!.id, progress);
  }

  @override
  void dispose() {
    _saveProgress();
    routeObserver.unsubscribe(this);
    _ttsService.onComplete = null;
    Future.microtask(_ttsService.stop);
    _scrollController.dispose();
    super.dispose();
  }

  String get _currentChapterTitle {
    if (_epubBook == null || _epubBook!.toc.isEmpty) {
      return 'Chapter ${_currentChapterIndex + 1}';
    }
    if (_currentChapterIndex < _epubBook!.toc.length) {
      return _epubBook!.toc[_currentChapterIndex].title;
    }
    return 'Chapter ${_currentChapterIndex + 1}';
  }

  TextStyle _buildReaderTextStyle({
    required TextStyle? baseStyle,
    required PlayerThemeSettings theme,
    required Color color,
  }) {
    final style = (baseStyle ?? const TextStyle()).copyWith(
      fontSize: theme.fontSize,
      fontWeight: _resolveFontWeight(theme.fontWeight),
      height: theme.lineHeight,
      color: color,
    );
    final fontFamily = theme.fontFamily;
    if (fontFamily == null || fontFamily.trim().isEmpty) {
      return style;
    }
    try {
      return GoogleFonts.getFont(fontFamily, textStyle: style);
    } catch (_) {
      return style.copyWith(fontFamily: fontFamily);
    }
  }

  FontWeight _resolveFontWeight(int weight) {
    final normalized = ((weight / 100).round() * 100).clamp(100, 900);
    switch (normalized) {
      case 100:
        return FontWeight.w100;
      case 200:
        return FontWeight.w200;
      case 300:
        return FontWeight.w300;
      case 400:
        return FontWeight.w400;
      case 500:
        return FontWeight.w500;
      case 600:
        return FontWeight.w600;
      case 700:
        return FontWeight.w700;
      case 800:
        return FontWeight.w800;
      case 900:
        return FontWeight.w900;
    }
    return FontWeight.w400;
  }

  Color _resolveReaderTextColor(
    PlayerThemeSettings theme,
    ColorScheme colorScheme, {
    required bool isActive,
  }) {
    if (theme.textColorMode == PlayerThemeTextColorMode.fixed &&
        theme.textColor != null) {
      final base = theme.textColor!;
      return isActive ? base : base.withOpacity(0.78);
    }
    return isActive ? colorScheme.onSurface : colorScheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    // Watch TTS state for reactive updates
    final ttsState = ref.watch(ttsProvider);
    final readerTheme = ref.watch(playerThemeProvider);
    final isPlaying = ttsState.status == TtsStatus.playing;
    final currentParagraphIndex = ttsState.paragraphIndex;
    final currentSentenceIndex = ttsState.sentenceIndex;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final glassBackground =
        extras?.glassBackground ?? colorScheme.surface.withAlpha(200);
    final glassBorder =
        extras?.glassBorder ?? colorScheme.onSurface.withAlpha(40);
    final glassShadow =
        extras?.glassShadow ?? Theme.of(context).shadowColor.withAlpha(30);
    final bookTitle = (_book?.title?.trim().isNotEmpty ?? false)
        ? _book!.title!.trim()
        : 'Untitled';
    final bookAuthor = (_book?.author?.trim().isNotEmpty ?? false)
        ? _book!.author!.trim()
        : 'Unknown author';
    final coverImage = _book?.coverImage;
    final safeParagraphSpacing =
        readerTheme.paragraphSpacing < 0 ? 0.0 : readerTheme.paragraphSpacing;
    final safeParagraphIndent =
        readerTheme.paragraphIndent < 0 ? 0.0 : readerTheme.paragraphIndent;
    final safePagePaddingHorizontal = readerTheme.pagePaddingHorizontal < 0
        ? 0.0
        : readerTheme.pagePaddingHorizontal;
    final safePagePaddingVertical = readerTheme.pagePaddingVertical < 0
        ? 0.0
        : readerTheme.pagePaddingVertical;
    final activeParagraphOpacity =
        readerTheme.activeParagraphOpacity.clamp(0.0, 1.0);
    final sentenceHighlightOpacity =
        (activeParagraphOpacity + 0.12).clamp(0.0, 0.6);

    // Auto-scroll when paragraph changes
    if (currentParagraphIndex != _lastScrolledToParagraph && isPlaying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToParagraph(currentParagraphIndex);
        _lastScrolledToParagraph = currentParagraphIndex;
      });
    }

    if (_book != null &&
        _paragraphs.isNotEmpty &&
        currentParagraphIndex != _lastBucketParagraph) {
      _updateBucketProgress(currentParagraphIndex, _paragraphs.length);
      _lastBucketParagraph = currentParagraphIndex;
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    if (_error != null) {
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
                'Error loading book',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final progress = _paragraphs.isEmpty
        ? 0.0
        : (currentParagraphIndex + 1) / _paragraphs.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _AmbientBackground(
            coverImage: coverImage,
            fallbackColor: Theme.of(context).scaffoldBackgroundColor,
            backgroundMode: readerTheme.backgroundMode,
            backgroundImagePath: readerTheme.backgroundImagePath,
            backgroundBlur: readerTheme.backgroundBlur,
            backgroundOpacity: readerTheme.backgroundOpacity,
          ),
          // Main content
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      _GlassIconButton(
                        icon: LucideIcons.arrowLeft,
                        onTap: () {
                          _saveProgress();
                          context.pop();
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bookTitle,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$bookAuthor \u2022 $_currentChapterTitle',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _GlassIconButton(
                        icon: LucideIcons.settings2,
                        onTap: _openSettings,
                      ),
                    ],
                  ),
                ),
              ),
              // Text content
              Expanded(
                child: _paragraphs.isEmpty
                    ? Center(
                        child: Text(
                          'No content available',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          safePagePaddingHorizontal,
                          safePagePaddingVertical,
                          safePagePaddingHorizontal,
                          safePagePaddingVertical + 260,
                        ),
                        itemCount: _paragraphs.length,
                        itemBuilder: (context, index) {
                          final paragraphKey = index < _paragraphKeys.length
                              ? _paragraphKeys[index]
                              : GlobalKey();
                          final isActiveParagraph =
                              index == currentParagraphIndex;
                          final sentences =
                              ttsState.sentencesPerParagraph.length > index
                              ? ttsState.sentencesPerParagraph[index]
                              : <String>[];
                          final showHighlight = isActiveParagraph &&
                              readerTheme.activeParagraphStyle ==
                                  PlayerThemeActiveParagraphStyle.highlight;
                          final showLeftBar = isActiveParagraph &&
                              readerTheme.activeParagraphStyle ==
                                  PlayerThemeActiveParagraphStyle.leftBar;
                          final showUnderline = isActiveParagraph &&
                              readerTheme.activeParagraphStyle ==
                                  PlayerThemeActiveParagraphStyle.underline;
                          final underlineOpacity =
                              activeParagraphOpacity < 0.2
                                  ? 0.2
                                  : activeParagraphOpacity;

                          return _FadeTap(
                            pressedOpacity: 0.78,
                            onTap: () {
                              ref
                                  .read(ttsProvider.notifier)
                                  .jumpToParagraph(index);
                            },
                            child: AnimatedContainer(
                              key: paragraphKey,
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.symmetric(
                                vertical: safeParagraphSpacing,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: showHighlight
                                    ? colorScheme.primary
                                        .withOpacity(activeParagraphOpacity)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                                border: showUnderline
                                    ? Border(
                                        bottom: BorderSide(
                                          color: colorScheme.primary
                                              .withOpacity(underlineOpacity),
                                          width: 2,
                                        ),
                                      )
                                    : null,
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Vertical line indicator
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: showLeftBar ? 3 : 0,
                                      margin: EdgeInsets.only(
                                        right: showLeftBar ? 12 : 0,
                                        top: 6,
                                        bottom: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: showLeftBar
                                            ? colorScheme.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    // Text content
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          left: safeParagraphIndent,
                                        ),
                                        child: sentences.isEmpty
                                            ? Text(
                                                _paragraphs[index],
                                                style: _buildReaderTextStyle(
                                                  baseStyle:
                                                      textTheme.bodyLarge,
                                                  theme: readerTheme,
                                                  color: _resolveReaderTextColor(
                                                    readerTheme,
                                                    colorScheme,
                                                    isActive:
                                                        isActiveParagraph,
                                                  ),
                                                ),
                                              )
                                            : RichText(
                                                text: TextSpan(
                                                  children: sentences
                                                      .asMap()
                                                      .entries
                                                      .map((entry) {
                                                    final sentenceIdx =
                                                        entry.key;
                                                    final sentence =
                                                        entry.value;
                                                    final isCurrentSentence =
                                                        isActiveParagraph &&
                                                        sentenceIdx ==
                                                            currentSentenceIndex;
                                                    final sentenceColor =
                                                        _resolveReaderTextColor(
                                                      readerTheme,
                                                      colorScheme,
                                                      isActive:
                                                          isCurrentSentence,
                                                    );

                                                    return TextSpan(
                                                      text:
                                                          sentence +
                                                          (sentenceIdx <
                                                                  sentences
                                                                          .length -
                                                                      1
                                                              ? ' '
                                                              : ''),
                                                      style:
                                                          _buildReaderTextStyle(
                                                        baseStyle:
                                                            textTheme.bodyLarge,
                                                        theme: readerTheme,
                                                        color: sentenceColor,
                                                      ).copyWith(
                                                        backgroundColor:
                                                            isCurrentSentence
                                                                ? colorScheme
                                                                    .primary
                                                                    .withOpacity(
                                                                  sentenceHighlightOpacity,
                                                                )
                                                                : Colors
                                                                    .transparent,
                                                      ),
                                                      recognizer:
                                                          TapGestureRecognizer()
                                                            ..onTap = () {
                                                              ref
                                                                  .read(
                                                                    ttsProvider
                                                                        .notifier,
                                                                  )
                                                                  .jumpToSentence(
                                                                    index,
                                                                    sentenceIdx,
                                                                  );
                                                            },
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          // Player controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _PlayerControlsEnhanced(
              isPlaying: isPlaying,
              progress: progress,
              currentParagraph: currentParagraphIndex + 1,
              totalParagraphs: _paragraphs.length,
              glassBackground: glassBackground,
              glassBorder: glassBorder,
              glassShadow: glassShadow,
              onPlayPause: _togglePlayPause,
              onPrevious: _previousChapter,
              onNext: _nextChapter,
              canGoPrevious: _currentChapterIndex > 0,
              canGoNext:
                  _epubBook != null &&
                  _currentChapterIndex < _epubBook!.chapters.length - 1,
            ),
          ),
          // Settings modal
          if (_showSettings)
            Positioned.fill(
              child: SettingsWheel(
                onClose: () => setState(() => _showSettings = false),
              ),
            ),
        ],
      ),
    );
  }
}

/// Enhanced player controls with chapter navigation
class _PlayerControlsEnhanced extends StatelessWidget {
  final bool isPlaying;
  final double progress;
  final int currentParagraph;
  final int totalParagraphs;
  final Color glassBackground;
  final Color glassBorder;
  final Color glassShadow;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canGoPrevious;
  final bool canGoNext;

  const _PlayerControlsEnhanced({
    required this.isPlaying,
    required this.progress,
    required this.currentParagraph,
    required this.totalParagraphs,
    required this.glassBackground,
    required this.glassBorder,
    required this.glassShadow,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomPadding),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: BoxDecoration(
              color: glassBackground,
              border: Border.all(color: glassBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: glassShadow,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: colorScheme.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$currentParagraph / $totalParagraphs',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundedControlButton(
                      icon: LucideIcons.skipBack,
                      onTap: canGoPrevious ? onPrevious : null,
                      backgroundColor: colorScheme.surface,
                      borderColor: colorScheme.outlineVariant,
                      iconColor: colorScheme.onSurface,
                      size: 48,
                      radius: 16,
                    ),
                    const SizedBox(width: 24),
                    AnimatedScale(
                      duration: const Duration(milliseconds: 150),
                      scale: isPlaying ? 0.96 : 1,
                      child: _RoundedControlButton(
                        icon: isPlaying ? LucideIcons.pause : LucideIcons.play,
                        onTap: onPlayPause,
                        backgroundColor: colorScheme.primary,
                        iconColor: colorScheme.onPrimary,
                        size: 56,
                        radius: 18,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .shadowColor
                                .withAlpha(50),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: child,
                            );
                          },
                          child: Icon(
                            isPlaying ? LucideIcons.pause : LucideIcons.play,
                            key: ValueKey(isPlaying),
                            color: colorScheme.onPrimary,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    _RoundedControlButton(
                      icon: LucideIcons.skipForward,
                      onTap: canGoNext ? onNext : null,
                      backgroundColor: colorScheme.surface,
                      borderColor: colorScheme.outlineVariant,
                      iconColor: colorScheme.onSurface,
                      size: 48,
                      radius: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  final Uint8List? coverImage;
  final Color fallbackColor;
  final PlayerThemeBackgroundMode backgroundMode;
  final String? backgroundImagePath;
  final double backgroundBlur;
  final double backgroundOpacity;

  const _AmbientBackground({
    required this.coverImage,
    required this.fallbackColor,
    required this.backgroundMode,
    required this.backgroundImagePath,
    required this.backgroundBlur,
    required this.backgroundOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final safeBlur = backgroundBlur < 0 ? 0.0 : backgroundBlur;
    final safeOpacity = backgroundOpacity.clamp(0.0, 1.0);
    final imageLayer = _buildImageLayer();
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(color: fallbackColor)),
        if (imageLayer != null)
          Opacity(
            opacity: safeOpacity,
            child: ImageFiltered(
              imageFilter:
                  ImageFilter.blur(sigmaX: safeBlur, sigmaY: safeBlur),
              child: imageLayer,
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: fallbackColor.withAlpha(110),
          ),
        ),
        if (backgroundMode != PlayerThemeBackgroundMode.solid)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surface.withAlpha(60),
                  fallbackColor.withAlpha(122),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget? _buildImageLayer() {
    switch (backgroundMode) {
      case PlayerThemeBackgroundMode.coverAmbient:
        if (coverImage == null) return null;
        return Image.memory(
          coverImage!,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        );
      case PlayerThemeBackgroundMode.customImage:
        if (backgroundImagePath == null ||
            backgroundImagePath!.trim().isEmpty) {
          return null;
        }
        return Image.asset(
          backgroundImagePath!,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        );
      case PlayerThemeBackgroundMode.solid:
      case PlayerThemeBackgroundMode.gradient:
        return null;
    }
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

class _RoundedControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color iconColor;
  final Color? borderColor;
  final double size;
  final double radius;
  final List<BoxShadow>? boxShadow;
  final Widget? child;

  const _RoundedControlButton({
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.iconColor,
    required this.size,
    required this.radius,
    this.borderColor,
    this.boxShadow,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final content = child ??
        Icon(
          icon,
          color: iconColor,
          size: 24,
        );

    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: _FadeTap(
        onTap: onTap,
        pressedOpacity: 0.7,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(radius),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1)
                : null,
            boxShadow: boxShadow,
          ),
          child: Center(child: content),
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

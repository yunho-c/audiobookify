import 'dart:io';
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
import '../services/tts_audio_handler.dart';
import '../services/tts_service.dart';
import '../models/book.dart';
import '../models/backdrop_image.dart';
import '../models/player_theme_settings.dart';
import '../src/rust/api/epub.dart';
import '../widgets/settings_wheel.dart';
import '../widgets/shared/glass_icon_button.dart';
import '../widgets/shared/pressable.dart';
import '../widgets/shared/state_scaffolds.dart';

/// Player screen with text reader, TTS audio controls, and settings
class PlayerScreen extends ConsumerStatefulWidget {
  final String bookId;

  const PlayerScreen({super.key, required this.bookId});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with RouteAware, SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _paragraphKeys = [];
  final List<List<TapGestureRecognizer>> _sentenceRecognizers = [];
  late final AnimationController _sentenceHighlightController;
  late final Animation<double> _sentenceHighlightCurve;

  // Data
  Book? _book;
  EpubBook? _epubBook;
  List<String> _paragraphs = [];
  late final BookService _bookService;
  late final TtsService _ttsService;
  late final TtsAudioHandler _audioHandler;

  // UI-specific state (TTS state comes from provider)
  bool _isLoading = true;
  String? _error;
  bool _showSettings = false;
  int _currentChapterIndex = 0;
  int _lastScrolledToParagraph = -1;
  int _lastBucketParagraph = -1;
  int _activeSentenceIndex = -1;
  int _activeSentenceParagraphIndex = -1;
  int _previousSentenceIndex = -1;
  int _previousSentenceParagraphIndex = -1;

  @override
  void initState() {
    super.initState();
    _bookService = ref.read(bookServiceProvider);
    _ttsService = ref.read(ttsProvider.notifier);
    _audioHandler = ref.read(audioHandlerProvider);
    _audioHandler.onSkipNext = () => _nextChapter(haptic: false);
    _audioHandler.onSkipPrevious = () => _previousChapter(haptic: false);
    _sentenceHighlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _sentenceHighlightCurve = CurvedAnimation(
      parent: _sentenceHighlightController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _sentenceHighlightController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _sentenceHighlightController.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.completed) {
        setState(() {
          _previousSentenceIndex = -1;
          _previousSentenceParagraphIndex = -1;
        });
      }
    });
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
      _audioHandler.stop();
    }
    super.didPop();
  }

  @override
  void didPushNext() {
    if (mounted) {
      _audioHandler.stop();
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
    _clearSentenceRecognizers();
    setState(() {
      _currentChapterIndex = index;
      _paragraphs = paragraphs;
      _paragraphKeys =
          List.generate(paragraphs.length, (_) => GlobalKey());
      _lastScrolledToParagraph = -1;
      _lastBucketParagraph = -1;
      _isLoading = false;
    });

    _updateNowPlaying();

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
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  void _previousChapter({bool haptic = true}) {
    if (haptic) {
      HapticFeedback.selectionClick();
    }
    if (_currentChapterIndex > 0) {
      _loadChapter(_currentChapterIndex - 1);
    }
  }

  void _nextChapter({bool haptic = true}) {
    if (haptic) {
      HapticFeedback.selectionClick();
    }
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
    _audioHandler.onSkipNext = null;
    _audioHandler.onSkipPrevious = null;
    Future.microtask(_audioHandler.stop);
    _clearSentenceRecognizers();
    _scrollController.dispose();
    _sentenceHighlightController.dispose();
    super.dispose();
  }

  String get _currentChapterTitle {
    return _chapterTitleFor(_currentChapterIndex);
  }

  String _chapterTitleFor(int index) {
    if (_epubBook == null || _epubBook!.toc.isEmpty) {
      return 'Chapter ${index + 1}';
    }
    if (index < _epubBook!.toc.length) {
      return _epubBook!.toc[index].title;
    }
    return 'Chapter ${index + 1}';
  }

  void _updateNowPlaying() {
    final book = _book;
    if (book == null) return;
    final title = (book.title?.trim().isNotEmpty ?? false)
        ? book.title!.trim()
        : 'Untitled';
    final author = (book.author?.trim().isNotEmpty ?? false)
        ? book.author!.trim()
        : 'Unknown author';
    _audioHandler.updateNowPlaying(
      id: book.id.toString(),
      title: title,
      artist: author,
      album: _chapterTitleFor(_currentChapterIndex),
    );
  }

  void _startSentenceHighlightTransition(
    int paragraphIndex,
    int sentenceIndex,
  ) {
    if (!mounted) return;
    if (sentenceIndex < 0) {
      setState(() {
        _activeSentenceIndex = -1;
        _activeSentenceParagraphIndex = -1;
        _previousSentenceIndex = -1;
        _previousSentenceParagraphIndex = -1;
      });
      _sentenceHighlightController.value = 1;
      return;
    }
    if (paragraphIndex == _activeSentenceParagraphIndex &&
        sentenceIndex == _activeSentenceIndex) {
      return;
    }

    setState(() {
      _previousSentenceIndex = _activeSentenceIndex;
      _previousSentenceParagraphIndex = _activeSentenceParagraphIndex;
      _activeSentenceIndex = sentenceIndex;
      _activeSentenceParagraphIndex = paragraphIndex;
    });

    _sentenceHighlightController.stop();
    _sentenceHighlightController.value = 0;
    _sentenceHighlightController.forward();
  }

  List<TextSpan> _buildSentenceSpans({
    required List<String> sentences,
    required int paragraphIndex,
    required bool isActiveParagraph,
    required int currentSentenceIndex,
    required int previousSentenceIndex,
    required int previousParagraphIndex,
    required double transitionValue,
    required PlayerThemeSettings readerTheme,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required PlayerThemeSentenceHighlightStyle highlightStyle,
    required double highlightOpacity,
  }) {
    final spans = <TextSpan>[];

    for (var sentenceIdx = 0;
        sentenceIdx < sentences.length;
        sentenceIdx++) {
      final sentence = sentences[sentenceIdx];
      final isCurrentSentence =
          isActiveParagraph && sentenceIdx == currentSentenceIndex;
      final isPreviousSentence =
          paragraphIndex == previousParagraphIndex &&
              sentenceIdx == previousSentenceIndex;
      final highlightIntensity = isCurrentSentence
          ? transitionValue
          : isPreviousSentence
          ? 1 - transitionValue
          : 0.0;
      final sentenceColor = _resolveReaderTextColor(
        readerTheme,
        colorScheme,
        isActive: isCurrentSentence || isPreviousSentence,
      );
      final sentenceStyle = _buildReaderTextStyle(
        baseStyle: textTheme.bodyLarge,
        theme: readerTheme,
        color: sentenceColor,
      );

      spans.add(
        TextSpan(
          text: sentence,
          style: _applySentenceHighlight(
            base: sentenceStyle,
            isCurrent: highlightIntensity > 0,
            highlightStyle: highlightStyle,
            highlightColor: colorScheme.primary.withOpacity(highlightOpacity),
            intensity: highlightIntensity,
          ),
          recognizer: _sentenceRecognizerFor(paragraphIndex, sentenceIdx),
        ),
      );

      if (sentenceIdx < sentences.length - 1) {
        spans.add(TextSpan(text: ' ', style: sentenceStyle));
      }
    }

    return spans;
  }

  TapGestureRecognizer _sentenceRecognizerFor(
    int paragraphIndex,
    int sentenceIndex,
  ) {
    while (_sentenceRecognizers.length <= paragraphIndex) {
      _sentenceRecognizers.add(<TapGestureRecognizer>[]);
    }
    final paragraphRecognizers = _sentenceRecognizers[paragraphIndex];
    while (paragraphRecognizers.length <= sentenceIndex) {
      paragraphRecognizers.add(TapGestureRecognizer());
    }
    final recognizer = paragraphRecognizers[sentenceIndex];
    recognizer.onTap = () {
      ref
          .read(ttsProvider.notifier)
          .jumpToSentence(paragraphIndex, sentenceIndex);
    };
    return recognizer;
  }

  void _clearSentenceRecognizers() {
    for (final paragraph in _sentenceRecognizers) {
      for (final recognizer in paragraph) {
        recognizer.dispose();
      }
    }
    _sentenceRecognizers.clear();
  }

  Widget _wrapShadow({
    required bool showShadow,
    required Color shadowColor,
    required Widget child,
  }) {
    if (!showShadow) return child;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 6),
            blurStyle: BlurStyle.outer,
          ),
        ],
      ),
      child: child,
    );
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

  TextStyle _applySentenceHighlight({
    required TextStyle base,
    required bool isCurrent,
    required PlayerThemeSentenceHighlightStyle highlightStyle,
    required Color highlightColor,
    required double intensity,
  }) {
    if (!isCurrent || intensity <= 0) {
      return base;
    }
    final resolvedColor =
        highlightColor.withOpacity(highlightColor.opacity * intensity);
    switch (highlightStyle) {
      case PlayerThemeSentenceHighlightStyle.background:
        return base.copyWith(backgroundColor: resolvedColor);
      case PlayerThemeSentenceHighlightStyle.underline:
        return base.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: resolvedColor,
          decorationThickness: 1.6,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch TTS state for reactive updates
    final ttsState = ref.watch(ttsProvider);
    ref.listen<TtsPlaybackState>(ttsProvider, (previous, next) {
      if (!mounted || _paragraphs.isEmpty) return;
      final prevParagraph = previous?.paragraphIndex;
      final prevSentence = previous?.sentenceIndex;
      if (prevParagraph == next.paragraphIndex &&
          prevSentence == next.sentenceIndex) {
        return;
      }
      _startSentenceHighlightTransition(
        next.paragraphIndex,
        next.sentenceIndex,
      );
    });
    final readerTheme = ref.watch(playerThemeProvider);
    final backdropSettings = ref.watch(backdropSettingsProvider);
    final backdrops = ref.watch(backdropLibraryProvider);
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
    BackdropImage? selectedBackdrop;
    if (readerTheme.backgroundMode ==
        PlayerThemeBackgroundMode.customImage) {
      for (final image in backdrops) {
        if (image.id == backdropSettings.id) {
          selectedBackdrop = image;
          break;
        }
      }
    }
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
                          final sentenceHighlightStyle =
                              readerTheme.sentenceHighlightStyle;

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
      final targetParagraph = currentParagraphIndex;
      final targetChapter = _currentChapterIndex;
      _lastBucketParagraph = targetParagraph;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_book == null || _paragraphs.isEmpty) return;
        if (_currentChapterIndex != targetChapter) return;
        _updateBucketProgress(targetParagraph, _paragraphs.length);
      });
    }

    if (_isLoading) {
      return const LoadingScaffold();
    }

    if (_error != null) {
      return ErrorScaffold(
        title: 'Error loading book',
        message: _error!,
        onBack: () => context.pop(),
        messagePadding: const EdgeInsets.symmetric(horizontal: 32),
        messageAlign: TextAlign.center,
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
            backdropImage: selectedBackdrop,
            backdropBrightness: backdropSettings.brightness,
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
                      GlassIconButton(
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
                      GlassIconButton(
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
                          final style = readerTheme.activeParagraphStyle;
                          final showHighlight = isActiveParagraph &&
                              (style ==
                                      PlayerThemeActiveParagraphStyle
                                          .highlight ||
                                  style ==
                                      PlayerThemeActiveParagraphStyle
                                          .highlightBar);
                          final showLeftBar = isActiveParagraph &&
                              (style ==
                                      PlayerThemeActiveParagraphStyle.leftBar ||
                                  style ==
                                      PlayerThemeActiveParagraphStyle
                                          .highlightBar);
                          final showShadow = isActiveParagraph &&
                              style ==
                                  PlayerThemeActiveParagraphStyle.underline;
                          final shadowOpacity =
                              (activeParagraphOpacity * 0.9).clamp(0.08, 0.3);

                          return Pressable(
                            pressedOpacity: 0.78,
                            pressedScale: 1,
                            onTap: () {
                              ref
                                  .read(ttsProvider.notifier)
                                  .jumpToParagraph(index);
                            },
                            child: _wrapShadow(
                              showShadow: showShadow,
                              shadowColor:
                                  glassShadow.withOpacity(shadowOpacity),
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
                                                    color:
                                                        _resolveReaderTextColor(
                                                      readerTheme,
                                                      colorScheme,
                                                      isActive:
                                                          isActiveParagraph,
                                                    ),
                                                  ),
                                                )
                                              : RichText(
                                                  text: TextSpan(
                                                    children:
                                                        _buildSentenceSpans(
                                                      sentences: sentences,
                                                      paragraphIndex: index,
                                                      isActiveParagraph:
                                                          isActiveParagraph,
                                                      currentSentenceIndex:
                                                          currentSentenceIndex,
                                                      previousSentenceIndex:
                                                          _previousSentenceIndex,
                                                      previousParagraphIndex:
                                                          _previousSentenceParagraphIndex,
                                                      transitionValue:
                                                          _sentenceHighlightCurve
                                                              .value,
                                                      readerTheme: readerTheme,
                                                      colorScheme: colorScheme,
                                                      textTheme: textTheme,
                                                      highlightStyle:
                                                          sentenceHighlightStyle,
                                                      highlightOpacity:
                                                          sentenceHighlightOpacity,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
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
  final BackdropImage? backdropImage;
  final double backdropBrightness;
  final String? backgroundImagePath;
  final double backgroundBlur;
  final double backgroundOpacity;

  const _AmbientBackground({
    required this.coverImage,
    required this.fallbackColor,
    required this.backgroundMode,
    required this.backdropImage,
    required this.backdropBrightness,
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
    final brightness = backdropBrightness.clamp(-1.0, 1.0);
    final brightnessOverlay = backgroundMode ==
                PlayerThemeBackgroundMode.customImage &&
            brightness.abs() > 0.01
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: brightness > 0
                  ? Colors.white.withAlpha((brightness * 76).round())
                  : Colors.black.withAlpha((-brightness * 76).round()),
            ),
          )
        : null;
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
        if (brightnessOverlay != null) brightnessOverlay,
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
        final backdrop = backdropImage;
        if (backdrop != null) {
          final uri = backdrop.uri.trim();
          if (uri.startsWith('http://') || uri.startsWith('https://')) {
            return Image.network(
              uri,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            );
          }
          if (uri.startsWith('assets/') || uri.startsWith('packages/')) {
            return Image.asset(
              uri,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            );
          }
          if (backdrop.sourceType == BackdropSourceType.upload) {
            return Image.file(
              File(uri),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            );
          }
        }
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
      child: Pressable(
        onTap: onTap,
        pressedOpacity: 0.7,
        pressedScale: 1,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:html/parser.dart' as html_parser;
import '../core/app_theme.dart';
import '../core/providers.dart';
import '../models/book.dart';
import '../src/rust/api/epub.dart';
import '../services/tts_service.dart';
import '../widgets/settings_wheel.dart';

/// Player screen with text reader, TTS audio controls, and settings
class PlayerScreen extends ConsumerStatefulWidget {
  final String bookId;

  const PlayerScreen({super.key, required this.bookId});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final TtsService _tts = TtsService();
  final ScrollController _scrollController = ScrollController();

  // Data
  Book? _book;
  EpubBook? _epubBook;
  List<String> _paragraphs = [];

  // State
  bool _isLoading = true;
  String? _error;
  bool _showSettings = false;
  int _currentChapterIndex = 0;
  int _currentParagraphIndex = 0;
  int _currentSentenceIndex = 0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadContent();
  }

  Future<void> _initTts() async {
    await _tts.init();

    // Apply initial settings
    final settings = ref.read(playerSettingsProvider);
    await _tts.applySettings(
      speed: settings.speed,
      pitch: settings.pitch,
      voiceName: settings.voiceName,
      voiceLocale: settings.voiceLocale,
    );

    _tts.onParagraphChange = (index) {
      if (!mounted) return;
      setState(() {
        _currentParagraphIndex = index;
        _currentSentenceIndex = 0;
      });
      _scrollToParagraph(index);
    };

    _tts.onSentenceChange = (index) {
      if (!mounted) return;
      setState(() => _currentSentenceIndex = index);
    };

    _tts.onComplete = () {
      if (!mounted) return;
      // Try to advance to next chapter
      if (_currentChapterIndex < (_epubBook?.chapters.length ?? 1) - 1) {
        _loadChapter(_currentChapterIndex + 1);
      } else {
        setState(() => _isPlaying = false);
        _saveProgress();
      }
    };
  }

  Future<void> _loadContent() async {
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

      // Load EPUB
      final epub = await openEpub(path: book.filePath);

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
    setState(() {
      _currentChapterIndex = index;
      _paragraphs = paragraphs;
      _currentParagraphIndex = 0;
      _isLoading = false;
    });

    _tts.setParagraphs(paragraphs);

    // Auto-play when loading a chapter (if already playing)
    if (_isPlaying) {
      await _tts.play();
    }
  }

  List<String> _extractParagraphs(String htmlContent) {
    // Parse HTML and extract text
    final document = html_parser.parse(htmlContent);
    final body = document.body;
    if (body == null) return [];

    // Get text content and split into paragraphs
    final text = body.text ?? '';

    // Split by double newlines or paragraph markers
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && p.length > 10)
        .toList();

    if (paragraphs.isEmpty) {
      // Fallback: split by sentences if no paragraphs
      return text
          .split(RegExp(r'(?<=[.!?])\s+'))
          .where((s) => s.trim().isNotEmpty)
          .take(20)
          .toList();
    }

    return paragraphs;
  }

  void _scrollToParagraph(int index) {
    // Approximate scroll position based on paragraph index
    final scrollPosition = index * 120.0;
    _scrollController.animateTo(
      scrollPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _tts.pause();
    } else {
      if (_tts.state == TtsState.paused) {
        await _tts.resume();
      } else {
        await _tts.play();
      }
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _previousChapter() {
    if (_currentChapterIndex > 0) {
      _loadChapter(_currentChapterIndex - 1);
    }
  }

  void _nextChapter() {
    if (_epubBook != null &&
        _currentChapterIndex < _epubBook!.chapters.length - 1) {
      _loadChapter(_currentChapterIndex + 1);
    }
  }

  void _saveProgress() {
    if (_book == null || _epubBook == null) return;

    // Calculate progress as percentage
    final totalChapters = _epubBook!.chapters.length;
    final progress = (((_currentChapterIndex + 1) / totalChapters) * 100)
        .round();

    ref.read(bookServiceProvider).updateProgress(_book!.id, progress);
  }

  @override
  void dispose() {
    _saveProgress();
    _tts.dispose();
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

  @override
  Widget build(BuildContext context) {
    // Listen for settings changes and apply to TTS
    ref.listen(playerSettingsProvider, (previous, next) {
      _tts.applySettings(
        speed: next.speed,
        pitch: next.pitch,
        voiceName: next.voiceName,
        voiceLocale: next.voiceLocale,
      );
    });

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.orange50,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.orange600),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.orange50,
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
                _error!,
                style: GoogleFonts.inter(color: AppColors.stone600),
              ),
            ],
          ),
        ),
      );
    }

    final progress = _paragraphs.isNotEmpty
        ? (_currentParagraphIndex + 1) / _paragraphs.length
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.orange50,
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Header
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          _saveProgress();
                          context.go('/book/${widget.bookId}');
                        },
                        child: const Icon(
                          LucideIcons.arrowLeft,
                          color: AppColors.stone600,
                          size: 24,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _currentChapterTitle,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.stone800,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'CHAPTER ${_currentChapterIndex + 1} OF ${_epubBook?.chapters.length ?? 0}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w500,
                                color: AppColors.stone500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showSettings = true),
                        child: const Icon(
                          LucideIcons.settings2,
                          color: AppColors.stone600,
                          size: 24,
                        ),
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
                          style: GoogleFonts.inter(color: AppColors.stone500),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(32, 16, 32, 200),
                        itemCount: _paragraphs.length,
                        itemBuilder: (context, index) {
                          final isActiveParagraph =
                              index == _currentParagraphIndex;
                          final sentences = _tts.getSentencesForParagraph(
                            index,
                          );

                          return GestureDetector(
                            onTap: () async {
                              await _tts.jumpToParagraph(index);
                              setState(() {
                                _currentParagraphIndex = index;
                                _currentSentenceIndex = 0;
                              });
                            },
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Vertical line indicator for active paragraph
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: isActiveParagraph ? 3 : 0,
                                    margin: EdgeInsets.only(
                                      right: isActiveParagraph ? 12 : 0,
                                      bottom: 20,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isActiveParagraph
                                          ? AppColors.orange600
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  // Text content with sentence highlighting
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 20,
                                      ),
                                      child: sentences.isEmpty
                                          ? Text(
                                              _paragraphs[index],
                                              style: GoogleFonts.lora(
                                                fontSize: 18,
                                                height: 1.8,
                                                color: isActiveParagraph
                                                    ? AppColors.stone700
                                                    : AppColors.stone500,
                                              ),
                                            )
                                          : RichText(
                                              text: TextSpan(
                                                children: sentences.asMap().entries.map((
                                                  entry,
                                                ) {
                                                  final sentenceIndex =
                                                      entry.key;
                                                  final sentence = entry.value;
                                                  final isCurrentSentence =
                                                      isActiveParagraph &&
                                                      sentenceIndex ==
                                                          _currentSentenceIndex;

                                                  return TextSpan(
                                                    text:
                                                        sentence +
                                                        (sentenceIndex <
                                                                sentences
                                                                        .length -
                                                                    1
                                                            ? ' '
                                                            : ''),
                                                    style: GoogleFonts.lora(
                                                      fontSize: 18,
                                                      height: 1.8,
                                                      color: isCurrentSentence
                                                          ? AppColors.stone800
                                                          : isActiveParagraph
                                                          ? AppColors.stone600
                                                          : AppColors.stone500,
                                                      backgroundColor:
                                                          isCurrentSentence
                                                          ? AppColors.orange200
                                                                .withAlpha(150)
                                                          : Colors.transparent,
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          // Player controls at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _PlayerControlsEnhanced(
              isPlaying: _isPlaying,
              progress: progress,
              currentParagraph: _currentParagraphIndex + 1,
              totalParagraphs: _paragraphs.length,
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
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.stone100,
              valueColor: const AlwaysStoppedAnimation(AppColors.orange600),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          // Progress text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$currentParagraph / $totalParagraphs',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.stone500,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.stone500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous chapter
              IconButton(
                onPressed: canGoPrevious ? onPrevious : null,
                icon: Icon(
                  LucideIcons.skipBack,
                  color: canGoPrevious
                      ? AppColors.stone700
                      : AppColors.stone300,
                  size: 28,
                ),
              ),
              const SizedBox(width: 24),
              // Play/Pause
              GestureDetector(
                onTap: onPlayPause,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.stone800,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(50),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isPlaying ? LucideIcons.pause : LucideIcons.play,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Next chapter
              IconButton(
                onPressed: canGoNext ? onNext : null,
                icon: Icon(
                  LucideIcons.skipForward,
                  color: canGoNext ? AppColors.stone700 : AppColors.stone300,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

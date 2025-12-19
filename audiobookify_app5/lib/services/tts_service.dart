import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/player_settings.dart';

/// TTS playback status
enum TtsStatus { stopped, playing, paused }

/// Immutable state for TTS playback
class TtsPlaybackState {
  final TtsStatus status;
  final int paragraphIndex;
  final int sentenceIndex;
  final List<String> paragraphs;
  final List<List<String>> sentencesPerParagraph;

  const TtsPlaybackState({
    this.status = TtsStatus.stopped,
    this.paragraphIndex = 0,
    this.sentenceIndex = 0,
    this.paragraphs = const [],
    this.sentencesPerParagraph = const [],
  });

  TtsPlaybackState copyWith({
    TtsStatus? status,
    int? paragraphIndex,
    int? sentenceIndex,
    List<String>? paragraphs,
    List<List<String>>? sentencesPerParagraph,
  }) {
    return TtsPlaybackState(
      status: status ?? this.status,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      sentenceIndex: sentenceIndex ?? this.sentenceIndex,
      paragraphs: paragraphs ?? this.paragraphs,
      sentencesPerParagraph:
          sentencesPerParagraph ?? this.sentencesPerParagraph,
    );
  }

  List<String> get currentSentences {
    if (paragraphIndex >= 0 && paragraphIndex < sentencesPerParagraph.length) {
      return sentencesPerParagraph[paragraphIndex];
    }
    return [];
  }
}

/// Service wrapper for FlutterTts with sentence-level tracking
class TtsService extends StateNotifier<TtsPlaybackState> {
  TtsService() : super(const TtsPlaybackState()) {
    _flutterTts = FlutterTts();
    _initTts();
  }

  late final FlutterTts _flutterTts;
  Function()? onComplete;
  bool _isJumping = false; // Suppress completion callbacks during jumps

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      if (_isJumping) {
        _isJumping = false;
      }
    });

    _flutterTts.setCompletionHandler(() {
      _onSentenceComplete();
    });

    _flutterTts.setErrorHandler((message) {
      _isJumping = false;
      state = state.copyWith(status: TtsStatus.stopped);
    });
  }

  /// Load content for playback
  void loadContent(List<String> paragraphs) {
    final sentencesPerParagraph = paragraphs
        .map((p) => _splitIntoSentences(p))
        .toList();

    state = TtsPlaybackState(
      paragraphs: paragraphs,
      sentencesPerParagraph: sentencesPerParagraph,
      paragraphIndex: 0,
      sentenceIndex: 0,
      status: TtsStatus.stopped,
    );
  }

  /// Start or resume playback
  Future<void> play() async {
    if (state.paragraphs.isEmpty) return;
    state = state.copyWith(status: TtsStatus.playing);
    await _speakCurrentSentence();
  }

  /// Pause playback
  Future<void> pause() async {
    await _flutterTts.stop();
    state = state.copyWith(status: TtsStatus.paused);
  }

  /// Stop playback
  Future<void> stop() async {
    await _flutterTts.stop();
    state = state.copyWith(status: TtsStatus.stopped);
  }

  /// Jump to specific paragraph (resets to first sentence)
  Future<void> jumpToParagraph(int index) async {
    if (index < 0 || index >= state.paragraphs.length) return;

    final wasPlaying = state.status == TtsStatus.playing;
    _isJumping = true;
    await _flutterTts.stop();

    state = state.copyWith(
      paragraphIndex: index,
      sentenceIndex: 0,
      status: wasPlaying ? TtsStatus.playing : state.status,
    );

    if (wasPlaying) {
      await _speakCurrentSentence();
    } else {
      _isJumping = false;
    }
  }

  /// Jump to specific sentence within a paragraph
  Future<void> jumpToSentence(int paragraphIndex, int sentenceIndex) async {
    if (paragraphIndex < 0 || paragraphIndex >= state.paragraphs.length) return;

    final wasPlaying = state.status == TtsStatus.playing;
    _isJumping = true;

    // Stop immediately and update state atomically
    await _flutterTts.stop();

    final sentences = state.sentencesPerParagraph[paragraphIndex];
    final validSentenceIndex = sentenceIndex.clamp(0, sentences.length - 1);

    state = state.copyWith(
      paragraphIndex: paragraphIndex,
      sentenceIndex: validSentenceIndex,
      status: wasPlaying ? TtsStatus.playing : state.status,
    );

    if (wasPlaying) {
      await _speakCurrentSentence();
    } else {
      _isJumping = false;
    }
  }

  /// Apply settings from PlayerSettings
  Future<void> applySettings(PlayerSettings settings) async {
    final ttsRate = (settings.speed * 0.5).clamp(0.1, 1.0);
    await _flutterTts.setSpeechRate(ttsRate);
    await _flutterTts.setPitch(settings.pitch);
    if (settings.voiceName != null && settings.voiceLocale != null) {
      await _flutterTts.setVoice({
        'name': settings.voiceName!,
        'locale': settings.voiceLocale!,
      });
    }
  }

  Future<void> _speakCurrentSentence() async {
    if (state.paragraphIndex >= state.paragraphs.length) {
      state = state.copyWith(status: TtsStatus.stopped);
      onComplete?.call();
      return;
    }

    final sentences = state.sentencesPerParagraph[state.paragraphIndex];
    if (state.sentenceIndex >= sentences.length) {
      // Move to next paragraph
      final nextParagraph = state.paragraphIndex + 1;
      if (nextParagraph >= state.paragraphs.length) {
        state = state.copyWith(status: TtsStatus.stopped);
        onComplete?.call();
        return;
      }
      state = state.copyWith(paragraphIndex: nextParagraph, sentenceIndex: 0);
    }

    final text =
        state.sentencesPerParagraph[state.paragraphIndex][state.sentenceIndex];
    await _flutterTts.speak(text);
  }

  void _onSentenceComplete() {
    if (_isJumping) return;
    if (state.status != TtsStatus.playing) return;

    final sentences = state.sentencesPerParagraph[state.paragraphIndex];
    final nextSentence = state.sentenceIndex + 1;

    if (nextSentence >= sentences.length) {
      // Move to next paragraph
      final nextParagraph = state.paragraphIndex + 1;
      if (nextParagraph >= state.paragraphs.length) {
        state = state.copyWith(status: TtsStatus.stopped);
        onComplete?.call();
        return;
      }
      state = state.copyWith(paragraphIndex: nextParagraph, sentenceIndex: 0);
    } else {
      state = state.copyWith(sentenceIndex: nextSentence);
    }

    _speakCurrentSentence();
  }

  List<String> _splitIntoSentences(String text) {
    final sentencePattern = RegExp(
      r'(?<!\b(?:Mr|Mrs|Ms|Dr|Prof|Sr|Jr|vs|etc|e\.g|i\.e))\s*[.!?]+\s+',
      caseSensitive: false,
    );

    final sentences = <String>[];
    var remaining = text.trim();

    while (remaining.isNotEmpty) {
      final match = sentencePattern.firstMatch(remaining);
      if (match != null) {
        final sentence = remaining.substring(0, match.end).trim();
        if (sentence.isNotEmpty) {
          sentences.add(sentence);
        }
        remaining = remaining.substring(match.end).trim();
      } else {
        if (remaining.isNotEmpty) {
          sentences.add(remaining);
        }
        break;
      }
    }

    if (sentences.isEmpty && text.trim().isNotEmpty) {
      sentences.add(text.trim());
    }

    return sentences;
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}

import 'package:flutter_tts/flutter_tts.dart';

/// TTS playback state
enum TtsState { playing, stopped, paused }

/// Service wrapper for FlutterTts with sentence-level tracking
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  TtsState _state = TtsState.stopped;

  // Callbacks
  Function(int)? onParagraphChange;
  Function(int)? onSentenceChange;
  Function()? onComplete;
  Function(String)? onError;

  // Current playback state
  List<String> _paragraphs = [];
  List<List<String>> _sentencesPerParagraph = [];
  int _currentParagraphIndex = 0;
  int _currentSentenceIndex = 0;

  TtsState get state => _state;
  int get currentParagraphIndex => _currentParagraphIndex;
  int get currentSentenceIndex => _currentSentenceIndex;

  /// Get sentences for a specific paragraph
  List<String> getSentencesForParagraph(int paragraphIndex) {
    if (paragraphIndex >= 0 && paragraphIndex < _sentencesPerParagraph.length) {
      return _sentencesPerParagraph[paragraphIndex];
    }
    return [];
  }

  Future<void> init() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Set up completion handler
    _flutterTts.setCompletionHandler(() {
      _onSentenceComplete();
    });

    _flutterTts.setErrorHandler((message) {
      _state = TtsState.stopped;
      onError?.call(message.toString());
    });
  }

  /// Split text into sentences, handling common abbreviations
  List<String> _splitIntoSentences(String text) {
    // Regex to split on sentence endings, but not on common abbreviations
    // Handles: Mr., Mrs., Ms., Dr., Prof., Sr., Jr., etc.
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
        // No more matches, add remaining text as last sentence
        if (remaining.isNotEmpty) {
          sentences.add(remaining);
        }
        break;
      }
    }

    // If no sentences found, return the entire text as one sentence
    if (sentences.isEmpty && text.trim().isNotEmpty) {
      sentences.add(text.trim());
    }

    return sentences;
  }

  /// Set the paragraphs to read
  void setParagraphs(List<String> paragraphs) {
    _paragraphs = paragraphs;
    _sentencesPerParagraph = paragraphs.map(_splitIntoSentences).toList();
    _currentParagraphIndex = 0;
    _currentSentenceIndex = 0;
  }

  /// Start reading from current paragraph/sentence
  Future<void> play() async {
    if (_paragraphs.isEmpty) return;

    _state = TtsState.playing;
    await _speakCurrentSentence();
  }

  /// Pause speech
  Future<void> pause() async {
    _state = TtsState.paused;
    await _flutterTts.stop();
  }

  /// Stop and reset
  Future<void> stop() async {
    _state = TtsState.stopped;
    _currentParagraphIndex = 0;
    _currentSentenceIndex = 0;
    await _flutterTts.stop();
  }

  /// Resume from paused state
  Future<void> resume() async {
    if (_state == TtsState.paused) {
      _state = TtsState.playing;
      await _speakCurrentSentence();
    }
  }

  /// Jump to specific paragraph (resets to first sentence)
  Future<void> jumpToParagraph(int index) async {
    if (index >= 0 && index < _paragraphs.length) {
      await _flutterTts.stop();
      _currentParagraphIndex = index;
      _currentSentenceIndex = 0;
      onParagraphChange?.call(_currentParagraphIndex);
      onSentenceChange?.call(_currentSentenceIndex);

      if (_state == TtsState.playing) {
        await _speakCurrentSentence();
      }
    }
  }

  /// Set speech rate
  /// User speed: 0.5 (half) to 2.0 (double)
  /// TTS engine rate: 0.25 to 0.75 where 0.5 is normal on macOS
  Future<void> setRate(double userSpeed) async {
    // Normalize: 1.0x user speed = 0.5 TTS rate (normal)
    // 0.5x user speed = 0.25 TTS rate (slow)
    // 2.0x user speed = 0.75 TTS rate (fast)
    final ttsRate = (userSpeed * 0.5).clamp(0.1, 1.0);
    await _flutterTts.setSpeechRate(ttsRate);
  }

  /// Get available voices
  Future<List<Map<String, String>>> getVoices() async {
    final voices = await _flutterTts.getVoices;
    return (voices as List).map((v) => Map<String, String>.from(v)).toList();
  }

  /// Set voice
  Future<void> setVoice(String name, String locale) async {
    await _flutterTts.setVoice({'name': name, 'locale': locale});
  }

  /// Apply full settings object
  Future<void> applySettings({
    required double speed,
    required double pitch,
    String? voiceName,
    String? voiceLocale,
  }) async {
    await setRate(speed);
    await _flutterTts.setPitch(pitch);
    if (voiceName != null && voiceLocale != null) {
      await setVoice(voiceName, voiceLocale);
    }
  }

  Future<void> _speakCurrentSentence() async {
    if (_currentParagraphIndex >= _paragraphs.length) {
      _state = TtsState.stopped;
      onComplete?.call();
      return;
    }

    final sentences = _sentencesPerParagraph[_currentParagraphIndex];
    if (_currentSentenceIndex >= sentences.length) {
      // Move to next paragraph
      _currentParagraphIndex++;
      _currentSentenceIndex = 0;
      if (_currentParagraphIndex >= _paragraphs.length) {
        _state = TtsState.stopped;
        onComplete?.call();
        return;
      }
      onParagraphChange?.call(_currentParagraphIndex);
    }

    final text =
        _sentencesPerParagraph[_currentParagraphIndex][_currentSentenceIndex];
    onSentenceChange?.call(_currentSentenceIndex);
    await _flutterTts.speak(text);
  }

  void _onSentenceComplete() {
    if (_state != TtsState.playing) return;

    final sentences = _sentencesPerParagraph[_currentParagraphIndex];
    _currentSentenceIndex++;

    if (_currentSentenceIndex >= sentences.length) {
      // Move to next paragraph
      _currentParagraphIndex++;
      _currentSentenceIndex = 0;

      if (_currentParagraphIndex >= _paragraphs.length) {
        _state = TtsState.stopped;
        onComplete?.call();
        return;
      }

      onParagraphChange?.call(_currentParagraphIndex);
    }

    _speakCurrentSentence();
  }

  Future<void> dispose() async {
    await _flutterTts.stop();
  }
}

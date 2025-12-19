import 'package:flutter_tts/flutter_tts.dart';

/// TTS playback state
enum TtsState { playing, stopped, paused }

/// Service wrapper for FlutterTts
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  TtsState _state = TtsState.stopped;

  // Callbacks
  Function(int)? onParagraphChange;
  Function()? onComplete;
  Function(String)? onError;

  // Current playback state
  List<String> _paragraphs = [];
  int _currentParagraphIndex = 0;

  TtsState get state => _state;
  int get currentParagraphIndex => _currentParagraphIndex;

  Future<void> init() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Set up completion handler
    _flutterTts.setCompletionHandler(() {
      _onParagraphComplete();
    });

    _flutterTts.setErrorHandler((message) {
      _state = TtsState.stopped;
      onError?.call(message.toString());
    });
  }

  /// Set the paragraphs to read
  void setParagraphs(List<String> paragraphs) {
    _paragraphs = paragraphs;
    _currentParagraphIndex = 0;
  }

  /// Start reading from current paragraph
  Future<void> play() async {
    if (_paragraphs.isEmpty) return;

    _state = TtsState.playing;
    await _speakCurrentParagraph();
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
    await _flutterTts.stop();
  }

  /// Resume from paused state
  Future<void> resume() async {
    if (_state == TtsState.paused) {
      _state = TtsState.playing;
      await _speakCurrentParagraph();
    }
  }

  /// Jump to specific paragraph
  Future<void> jumpToParagraph(int index) async {
    if (index >= 0 && index < _paragraphs.length) {
      await _flutterTts.stop();
      _currentParagraphIndex = index;
      onParagraphChange?.call(_currentParagraphIndex);

      if (_state == TtsState.playing) {
        await _speakCurrentParagraph();
      }
    }
  }

  /// Set speech rate (0.0 - 1.0)
  Future<void> setRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
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

  Future<void> _speakCurrentParagraph() async {
    if (_currentParagraphIndex >= _paragraphs.length) {
      _state = TtsState.stopped;
      onComplete?.call();
      return;
    }

    final text = _paragraphs[_currentParagraphIndex];
    onParagraphChange?.call(_currentParagraphIndex);
    await _flutterTts.speak(text);
  }

  void _onParagraphComplete() {
    if (_state != TtsState.playing) return;

    _currentParagraphIndex++;
    if (_currentParagraphIndex >= _paragraphs.length) {
      _state = TtsState.stopped;
      onComplete?.call();
    } else {
      _speakCurrentParagraph();
    }
  }

  Future<void> dispose() async {
    await _flutterTts.stop();
  }
}

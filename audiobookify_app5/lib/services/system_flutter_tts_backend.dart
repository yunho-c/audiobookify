import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../models/player_settings.dart';
import 'speech_backend.dart';
import 'tts_debug_logging.dart';

class SystemFlutterTtsBackend implements SpeechBackend {
  SystemFlutterTtsBackend({FlutterTts? flutterTts})
    : _flutterTts = flutterTts ?? FlutterTts();

  static const defaultLocale = 'en-US';

  final FlutterTts _flutterTts;
  final StreamController<SpeechBackendEvent> _events =
      StreamController<SpeechBackendEvent>.broadcast();

  Completer<void>? _speakCompleter;
  bool _initialized = false;
  Future<void>? _initializing;
  bool _disposed = false;
  int _generation = 0;

  @override
  SpeechBackendKind get backendId => SpeechBackendKind.system;

  @override
  String get displayName => 'System';

  @override
  SpeechBackendCapabilities get capabilities => const SpeechBackendCapabilities(
    supportsPitch: true,
    supportsVoiceSelection: true,
    supportsPause: true,
  );

  @override
  Stream<SpeechBackendEvent> get events => _events.stream;

  @override
  Future<void> initialize() {
    if (_disposed) return Future.error(StateError('System speech is closed'));
    if (_initialized) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    logTtsDebug('Initializing system TTS backend', category: 'tts.system');

    await _flutterTts.setLanguage(defaultLocale);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      if (_disposed || _speakCompleter == null) return;
      _events.add(const SpeechBackendEvent(type: SpeechBackendEventType.start));
    });
    _flutterTts.setCompletionHandler(() {
      if (_disposed || _speakCompleter == null) return;
      _completeSpeak();
      _events.add(
        const SpeechBackendEvent(type: SpeechBackendEventType.complete),
      );
    });
    _flutterTts.setErrorHandler((message) {
      if (_disposed || _speakCompleter == null) return;
      final error = StateError(message);
      _completeSpeak(error: error, stackTrace: StackTrace.current);
      _events.add(
        SpeechBackendEvent(
          type: SpeechBackendEventType.error,
          message: message,
        ),
      );
    });

    _initialized = true;
    logTtsDebug('System TTS backend initialized', category: 'tts.system');
  }

  @override
  Future<List<SpeechVoiceOption>> listVoices() async {
    await initialize();
    final rawVoices = await _flutterTts.getVoices;
    if (rawVoices is! List) {
      return const [];
    }

    final voices = <SpeechVoiceOption>[];
    for (final entry in rawVoices) {
      if (entry is! Map) continue;
      final voice = Map<String, dynamic>.from(entry);
      final name = voice['name']?.toString();
      final locale = voice['locale']?.toString();
      if (name == null || locale == null) continue;
      voices.add(
        SpeechVoiceOption(
          backend: backendId,
          id: voiceIdFor(locale: locale, name: name),
          label: name,
          languageCode: _languageCodeFromLocale(locale),
          localeLabel: locale,
          gender: voice['gender']?.toString(),
        ),
      );
    }

    voices.sort((a, b) => a.label.compareTo(b.label));
    logTtsDebug(
      'System TTS listed ${voices.length} voices',
      category: 'tts.system',
    );
    return voices;
  }

  @override
  Future<void> applySettings(PlayerSettings settings) async {
    await initialize();
    logTtsDebug(
      'System TTS applySettings voiceId=${settings.voiceId ?? "default"} speed=${settings.speed} pitch=${settings.pitch}',
      category: 'tts.system',
    );
    final ttsRate = (settings.speed * 0.5).clamp(0.1, 1.0);
    await _flutterTts.setSpeechRate(ttsRate);
    await _flutterTts.setPitch(settings.pitch);
    await _flutterTts.setVolume(1.0);

    final voiceId = settings.voiceId;
    if (voiceId != null) {
      final voice = parseVoiceId(voiceId);
      if (voice != null) {
        await _flutterTts.setLanguage(voice.locale);
        await _flutterTts.setVoice({
          'name': voice.name,
          'locale': voice.locale,
        });
        return;
      }
    }

    await _flutterTts.setLanguage(defaultLocale);
  }

  @override
  Future<void> speak(String text, {String? languageCode}) async {
    final generation = ++_generation;
    await initialize();
    if (_disposed || generation != _generation) return;
    logTtsDebug('System TTS speak "$text"', category: 'tts.system');
    _completeSpeak();
    await _flutterTts.stop();
    if (_disposed || generation != _generation) return;
    final completer = Completer<void>();
    _speakCompleter = completer;
    await _flutterTts.speak(text);
    await completer.future;
  }

  @override
  Future<void> pause() async {
    await stop();
  }

  @override
  Future<void> stop() async {
    ++_generation;
    logTtsDebug('System TTS stop', category: 'tts.system');
    _completeSpeak();
    if (_initialized) await _flutterTts.stop();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final initializing = _initializing;
    if (initializing != null) {
      try {
        await initializing;
      } catch (_) {}
    }
    await stop();
    await _events.close();
  }

  void _completeSpeak({Object? error, StackTrace? stackTrace}) {
    final completer = _speakCompleter;
    _speakCompleter = null;
    if (completer == null || completer.isCompleted) {
      return;
    }
    if (error != null) {
      completer.completeError(error, stackTrace);
    } else {
      completer.complete();
    }
  }

  static String voiceIdFor({required String locale, required String name}) =>
      '$locale::$name';

  static SystemVoiceId? parseVoiceId(String voiceId) {
    final separator = voiceId.indexOf('::');
    if (separator <= 0 || separator >= voiceId.length - 2) {
      return null;
    }
    return SystemVoiceId(
      locale: voiceId.substring(0, separator),
      name: voiceId.substring(separator + 2),
    );
  }

  static String? _languageCodeFromLocale(String locale) {
    final separator = locale.indexOf('-');
    if (separator <= 0) return locale;
    return locale.substring(0, separator);
  }
}

class SystemVoiceId {
  final String locale;
  final String name;

  const SystemVoiceId({required this.locale, required this.name});
}

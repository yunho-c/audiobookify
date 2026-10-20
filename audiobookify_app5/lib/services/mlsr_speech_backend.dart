import 'dart:async';

import 'package:mlsr_app_models/app_models.dart';
import 'package:mlsr_flutter/mlsr_flutter.dart';

import '../models/player_settings.dart';
import 'speech_backend.dart';
import 'tts_debug_logging.dart';

typedef MlsrSessionFactory = Future<MlsrSession> Function();

/// Small boundary for testing app lifecycle races without loading a model.
abstract interface class MlsrSession {
  Future<List<SpeechVoiceOption>> listVoices();
  MlsrPlayback speak(
    String text, {
    required RequestOptions request,
    required SpeechOptions options,
  });
  Future<void> dispose();
}

abstract interface class MlsrPlayback {
  Stream<void> get starts;

  /// True only after the native output has drained; false for cancellation.
  Future<bool> get done;
  void cancel();
  Future<void> dispose();
}

/// MLSR owns inference, PCM buffering, native output, and completion.
class MlsrSdkSession implements MlsrSession {
  MlsrSdkSession(this.tts);

  final Tts tts;

  static Future<MlsrSession> openBundled() async => MlsrSdkSession(
    await FlutterMlsr.openTts(
      model: AppModels.supertonic3,
      options: const TtsOptions(output: OutputMode.hostManaged),
      onProgress: (progress) => logTtsDebug(
        'Model ${progress.stage.name} ${progress.copiedBytes}/${progress.totalBytes}',
        category: 'tts.mlsr',
      ),
    ),
  );

  @override
  Future<List<SpeechVoiceOption>> listVoices() async => [
    for (final voice in await tts.getVoices())
      SpeechVoiceOption(
        backend: SpeechBackendKind.mlsr,
        id: voice.id,
        label: voice.displayName,
        localeLabel: 'Multilingual',
      ),
  ];

  @override
  MlsrPlayback speak(
    String text, {
    required RequestOptions request,
    required SpeechOptions options,
  }) => _SdkPlayback(tts.speak(text, request: request, options: options));

  @override
  Future<void> dispose() => tts.dispose();
}

class _SdkPlayback implements MlsrPlayback {
  _SdkPlayback(this.speech);
  final Speech speech;

  @override
  Stream<void> get starts => speech.states
      .where((state) => state.playback == PlaybackPhase.playing)
      .take(1)
      .map((_) {});

  @override
  Future<bool> get done async =>
      (await speech.done).kind == OutcomeKind.completed;

  @override
  void cancel() => speech.cancel();

  @override
  Future<void> dispose() => speech.dispose();
}

class MlsrSpeechBackend implements SpeechBackend {
  MlsrSpeechBackend({MlsrSessionFactory? createSession})
    : _createSession = createSession ?? MlsrSdkSession.openBundled;

  final MlsrSessionFactory _createSession;
  final _events = StreamController<SpeechBackendEvent>.broadcast();
  final Set<Future<void>> _operations = {};
  MlsrSession? _session;
  MlsrPlayback? _active;
  Future<void>? _initializing, _closing;
  PlayerSettings _settings = const PlayerSettings(
    backend: SpeechBackendKind.mlsr,
  );
  int _generation = 0;
  bool _disposed = false;

  @override
  SpeechBackendKind get backendId => SpeechBackendKind.mlsr;
  @override
  String get displayName => 'MLSR';
  @override
  SpeechBackendCapabilities get capabilities => const SpeechBackendCapabilities(
    supportsPitch: false,
    supportsVoiceSelection: true,
    supportsPause: true,
  );
  @override
  Stream<SpeechBackendEvent> get events => _events.stream;

  @override
  Future<void> initialize() {
    if (_disposed) return Future.error(StateError('MLSR backend is closed'));
    if (_session != null) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    final stopwatch = Stopwatch()..start();
    final session = await _createSession();
    if (_disposed) {
      await session.dispose();
      throw StateError('MLSR backend closed while loading');
    }
    _session = session;
    logTtsDebug(
      'Model ready in ${stopwatch.elapsedMilliseconds} ms',
      category: 'tts.mlsr',
    );
  }

  @override
  Future<List<SpeechVoiceOption>> listVoices() async {
    await initialize();
    return _session!.listVoices();
  }

  @override
  Future<void> applySettings(PlayerSettings settings) async {
    if (_disposed) throw StateError('MLSR backend is closed');
    _settings = settings;
  }

  @override
  Future<void> speak(String text, {String? languageCode}) {
    if (_disposed) return Future.error(StateError('MLSR backend is closed'));
    final generation = ++_generation;
    final previous = List<Future<void>>.of(_operations);
    _active?.cancel();
    final operation = _speak(
      text,
      languageCode,
      generation,
      previous,
      _settings,
    );
    _operations.add(operation);
    operation.then<void>(
      (_) => _operations.remove(operation),
      onError: (Object _, StackTrace _) {
        _operations.remove(operation);
      },
    );
    return operation;
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  Future<void> _speak(
    String text,
    String? languageCode,
    int generation,
    List<Future<void>> previous,
    PlayerSettings settings,
  ) async {
    await initialize();
    await _join(previous);
    if (!_current(generation)) return;
    final locale = languageCode?.trim().replaceAll('_', '-');
    final speech = _session!.speak(
      text,
      request: RequestOptions(
        locale: locale == null || locale.isEmpty ? 'en' : locale,
        voice: settings.voiceId ?? '',
        fallback: VoiceFallback.sameLanguage,
      ),
      options: SpeechOptions(
        playbackRate: settings.speed,
        // Sentence navigation regenerates text. Do not retain an entire book.
        retainAudio: false,
      ),
    );
    _active = speech;
    final subscription = speech.starts.listen(
      (_) {
        if (_current(generation)) {
          _events.add(
            const SpeechBackendEvent(type: SpeechBackendEventType.start),
          );
        }
      },
      // The authoritative result/error arrives through done below.
      onError: (Object _, StackTrace _) {},
    );
    try {
      final completed = await speech.done;
      if (!_current(generation)) return;
      if (!completed) throw StateError('MLSR playback was cancelled');
      _events.add(
        const SpeechBackendEvent(type: SpeechBackendEventType.complete),
      );
    } catch (error) {
      if (_current(generation)) {
        _events.add(
          SpeechBackendEvent(
            type: SpeechBackendEventType.error,
            message: error.toString(),
          ),
        );
        rethrow;
      }
    } finally {
      await subscription.cancel();
      await speech.dispose();
      if (identical(_active, speech)) _active = null;
    }
  }

  static Future<void> _join(Iterable<Future<void>> operations) => Future.wait([
    for (final operation in operations)
      operation.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
  ]);

  @override
  Future<void> stop() async {
    ++_generation;
    _active?.cancel();
    await _join(List.of(_operations));
  }

  /// Audiobookify currently resumes by replaying the selected sentence.
  @override
  Future<void> pause() => stop();

  @override
  Future<void> dispose() => _closing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await stop();
    final initializing = _initializing;
    if (initializing != null) await _join([initializing]);
    await _session?.dispose();
    _session = null;
    await _events.close();
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kokoro_flutter/kokoro_flutter.dart';
import 'package:kokoro_flutter/src/coreml/platform_interface.dart';

import 'package:audiobookify/models/player_settings.dart';
import 'package:audiobookify/services/bundled_kokoro_onnx.dart';
import 'package:audiobookify/services/kokoro_coreml_backend.dart';
import 'package:audiobookify/services/open_tts_backend.dart';
import 'package:audiobookify/services/open_tts_renderer_support.dart';
import 'package:audiobookify/services/speech_backend.dart';
import 'package:audiobookify/services/tts_service.dart';

void main() {
  test('TtsService advances through sentences on the active backend', () async {
    final backend = _FakeSpeechBackend(SpeechBackendKind.system);
    final service = TtsService(backends: [backend]);
    addTearDown(service.dispose);

    service.loadContent(
      const ['Paragraph'],
      sentences: const [
        ['First sentence.', 'Second sentence.'],
      ],
    );

    await service.play();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(backend.spokenTexts, ['First sentence.', 'Second sentence.']);
    expect(service.state.status, TtsStatus.stopped);
    expect(service.state.sentenceIndex, 1);
  });

  test(
    'TtsService switches backend and resumes from the current sentence',
    () async {
      final openBackend = _FakeSpeechBackend(
        SpeechBackendKind.openTts,
        autoCompleteSpeak: false,
      );
      final systemBackend = _FakeSpeechBackend(SpeechBackendKind.system);
      final service = TtsService(backends: [systemBackend, openBackend]);
      addTearDown(service.dispose);

      service.loadContent(
        const ['Paragraph'],
        sentences: const [
          ['First sentence.', 'Second sentence.'],
        ],
      );
      await service.applySettings(
        const PlayerSettings(backend: SpeechBackendKind.openTts),
      );
      await service.play();
      await openBackend.awaitSpeakStarted();

      await service.applySettings(
        const PlayerSettings(backend: SpeechBackendKind.system),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(openBackend.spokenTexts, ['First sentence.']);
      expect(systemBackend.spokenTexts, [
        'First sentence.',
        'Second sentence.',
      ]);
      expect(service.activeBackendKind, SpeechBackendKind.system);
    },
  );

  test('TtsService falls back to the system backend when init fails', () async {
    final failingBackend = _FakeSpeechBackend(
      SpeechBackendKind.openTts,
      failInitialize: true,
    );
    final systemBackend = _FakeSpeechBackend(SpeechBackendKind.system);
    final service = TtsService(backends: [systemBackend, failingBackend]);
    addTearDown(service.dispose);

    service.loadContent(
      const ['Paragraph'],
      sentences: const [
        ['Fallback sentence.'],
      ],
    );
    await service.applySettings(
      const PlayerSettings(backend: SpeechBackendKind.openTts),
    );
    await service.play();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(service.activeBackendKind, SpeechBackendKind.system);
    expect(systemBackend.spokenTexts, ['Fallback sentence.']);
  });

  test('TtsService exposes CoreML capabilities', () async {
    final backend = _RecordingCoreMlBackend(
      coreMl: KokoroCoreMl(platform: _TestCoreMlPlatform()),
      renderer: _TestManagedRenderer(),
    );
    final service = TtsService(
      backends: [_FakeSpeechBackend(SpeechBackendKind.system), backend],
      initialSettings: const PlayerSettings(
        backend: SpeechBackendKind.coreMlKokoro,
      ),
    );
    addTearDown(service.dispose);

    final capabilities = service.capabilitiesFor(
      SpeechBackendKind.coreMlKokoro,
    );
    expect(capabilities.supportsPitch, isFalse);
    expect(capabilities.supportsVoiceSelection, isTrue);
    expect(capabilities.supportsPause, isTrue);
  });

  test(
    'TtsService requests next-sentence prefetch on OpenTts backend',
    () async {
      final engine = _TestKokoroEngine();
      final backend = _RecordingOpenTtsBackend(
        createOpenTts: (renderer) async => OpenTts(
          engine: engine,
          renderer: renderer,
          useStreamingForSpeak: false,
        ),
        renderer: _TestOpenTtsRenderer(),
      );
      final service = TtsService(
        backends: [_FakeSpeechBackend(SpeechBackendKind.system), backend],
        initialSettings: const PlayerSettings(
          backend: SpeechBackendKind.openTts,
        ),
      );
      addTearDown(service.dispose);

      service.loadContent(
        const ['Paragraph'],
        sentences: const [
          ['First sentence.', 'Second sentence.'],
        ],
      );

      await service.play();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(backend.prefetchedTexts, contains('Second sentence.'));
    },
  );

  test('TtsService clears OpenTts prefetch on stop', () async {
    final backend = _RecordingOpenTtsBackend(
      createOpenTts: (renderer) async => OpenTts(
        engine: _TestKokoroEngine(),
        renderer: renderer,
        useStreamingForSpeak: false,
      ),
      renderer: _TestOpenTtsRenderer(),
    );
    final service = TtsService(
      backends: [_FakeSpeechBackend(SpeechBackendKind.system), backend],
      initialSettings: const PlayerSettings(backend: SpeechBackendKind.openTts),
    );
    addTearDown(service.dispose);

    service.loadContent(
      const ['Paragraph'],
      sentences: const [
        ['First sentence.', 'Second sentence.'],
      ],
    );

    await service.play();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await service.stop();

    expect(backend.clearPrefetchCalls, greaterThan(0));
  });

  test(
    'TtsService can play, stop, and prefetch with a CoreML backend',
    () async {
      final backend = _RecordingCoreMlBackend(
        coreMl: KokoroCoreMl(platform: _TestCoreMlPlatform()),
        renderer: _TestManagedRenderer(),
      );
      final service = TtsService(
        backends: [_FakeSpeechBackend(SpeechBackendKind.system), backend],
        initialSettings: const PlayerSettings(
          backend: SpeechBackendKind.coreMlKokoro,
        ),
      );
      addTearDown(service.dispose);

      service.loadContent(
        const ['Paragraph'],
        sentences: const [
          ['First sentence.', 'Second sentence.'],
        ],
      );

      await service.play();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await service.stop();

      expect(backend.prefetchedTexts, contains('Second sentence.'));
      expect(backend.clearPrefetchCalls, greaterThan(0));
      expect(service.state.status, TtsStatus.stopped);
    },
  );

  test(
    'TtsService refreshes OpenTts engine when provider override changes',
    () async {
      final backend = _RecordingOpenTtsBackend(
        createOpenTts: (renderer) async => OpenTts(
          engine: _TestKokoroEngine(),
          renderer: renderer,
          useStreamingForSpeak: false,
        ),
        renderer: _TestOpenTtsRenderer(),
      );
      final service = TtsService(
        backends: [_FakeSpeechBackend(SpeechBackendKind.system), backend],
        initialSettings: const PlayerSettings(
          backend: SpeechBackendKind.openTts,
        ),
      );
      addTearDown(service.dispose);

      await service.refreshOpenTtsExecutionProviderOverride(
        previous: OpenTtsExecutionProviderOverride.auto,
        next: OpenTtsExecutionProviderOverride.cpu,
      );

      expect(backend.invalidateEngineCalls, 1);
    },
  );
}

class _FakeSpeechBackend implements SpeechBackend {
  _FakeSpeechBackend(
    this.backendId, {
    this.autoCompleteSpeak = true,
    this.failInitialize = false,
  });

  @override
  final SpeechBackendKind backendId;

  final bool autoCompleteSpeak;
  final bool failInitialize;
  final List<String> spokenTexts = <String>[];
  final StreamController<SpeechBackendEvent> _events =
      StreamController<SpeechBackendEvent>.broadcast();

  Completer<void>? _pendingSpeak;
  Completer<void>? _speakStarted;

  @override
  String get displayName => backendId.label;

  @override
  SpeechBackendCapabilities get capabilities => const SpeechBackendCapabilities(
    supportsPitch: true,
    supportsVoiceSelection: true,
    supportsPause: true,
  );

  @override
  Stream<SpeechBackendEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {
    if (failInitialize) {
      throw StateError('init failed');
    }
  }

  @override
  Future<List<SpeechVoiceOption>> listVoices() async => const [];

  @override
  Future<void> applySettings(PlayerSettings settings) async {}

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
    _events.add(const SpeechBackendEvent(type: SpeechBackendEventType.start));
    final completer = Completer<void>();
    _pendingSpeak = completer;
    _speakStarted?.complete();
    if (autoCompleteSpeak) {
      completer.complete();
    }
    await completer.future;
    _events.add(
      const SpeechBackendEvent(type: SpeechBackendEventType.complete),
    );
  }

  Future<void> awaitSpeakStarted() async {
    final completer = Completer<void>();
    _speakStarted = completer;
    if (spokenTexts.isNotEmpty) {
      completer.complete();
    }
    await completer.future;
  }

  @override
  Future<void> pause() async {
    await stop();
  }

  @override
  Future<void> stop() async {
    final completer = _pendingSpeak;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _pendingSpeak = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _events.close();
  }
}

class _RecordingOpenTtsBackend extends OpenTtsBackend {
  _RecordingOpenTtsBackend({
    required super.createOpenTts,
    required super.renderer,
  });

  final List<String> prefetchedTexts = <String>[];
  int clearPrefetchCalls = 0;
  int invalidateEngineCalls = 0;

  @override
  Future<void> prefetch(String text) {
    prefetchedTexts.add(text);
    return super.prefetch(text);
  }

  @override
  void clearPrefetch() {
    clearPrefetchCalls += 1;
    super.clearPrefetch();
  }

  @override
  Future<void> invalidateEngine({String? reason}) {
    invalidateEngineCalls += 1;
    return super.invalidateEngine(reason: reason);
  }
}

class _RecordingCoreMlBackend extends KokoroCoreMlBackend {
  _RecordingCoreMlBackend({required super.coreMl, required super.renderer});

  final List<String> prefetchedTexts = <String>[];
  int clearPrefetchCalls = 0;

  @override
  Future<void> prefetch(String text) {
    prefetchedTexts.add(text);
    return super.prefetch(text);
  }

  @override
  void clearPrefetch() {
    clearPrefetchCalls += 1;
    super.clearPrefetch();
  }
}

class _TestKokoroEngine implements KokoroEngine {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> warmup() async {}

  @override
  Future<SynthesisResult> synthesizeResult({
    required SynthesisInput input,
    double? speed,
    int? voiceIndex,
    String? voiceId,
  }) async {
    return SynthesisResult(
      audio: Float32List.fromList(const <double>[0.1, -0.1, 0.2]),
      sampleRate: 24000,
      diagnostics: const SynthesisDiagnostics(
        inputKind: 'text',
        inputTextLen: 0,
        phonemeLen: 0,
        phonemes: '',
        whitespaceLeading: 0,
        whitespaceTrailing: 0,
        whitespaceTrimmed: false,
        droppedSymbols: 0,
        timings: InferenceTimings(
          totalMs: 1,
          g2PMs: 0,
          vocabMs: 0,
          pipelineMs: 0,
          bertMs: 0,
          durationMs: 0,
          alignmentBuildMs: 0,
          alignmentGatherMs: 0,
          pitchEnergyMs: 0,
          textEncoderMs: 0,
          decoderMs: 0,
        ),
      ),
    );
  }

  @override
  Stream<AudioChunk> synthesizeStream({
    required SynthesisInput input,
    required KokoroCancelToken cancelToken,
    double? speed,
    int? chunkSizeMs,
    int? voiceIndex,
    String? voiceId,
  }) async* {}

  @override
  Future<KokoroCancelToken> createCancelToken() async => _TestCancelToken();

  @override
  Future<void> cancel(KokoroCancelToken token) async {}

  @override
  Future<List<VoiceInfo>> getVoices() async => const <VoiceInfo>[];

  @override
  Future<List<String>> getLanguages() async => const <String>['en-US'];
}

class _TestCancelToken implements KokoroCancelToken {
  @override
  bool get isCancelled => false;
}

class _TestOpenTtsRenderer implements OpenTtsAudioRenderer {
  @override
  Future<void> play(
    Float32List audio,
    int sampleRate, {
    required String requestId,
  }) async {}

  @override
  Future<void> stop({String? requestId}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}
}

class _TestCoreMlPlatform extends KokoroCoreMlPlatform {
  @override
  Future<bool> isCoreMlAvailable() async => true;

  @override
  Future<void> initializeCoreMl({String? assetsRoot}) async {}

  @override
  Future<List<KokoroCoreMlVoice>> listCoreMlVoices() async {
    return const <KokoroCoreMlVoice>[
      KokoroCoreMlVoice(id: 'af_heart', name: 'Heart'),
    ];
  }

  @override
  Future<void> selectCoreMlVoice(String voiceId) async {}

  @override
  Future<KokoroCoreMlAudioResult> synthesizeCoreMl(
    String text, {
    String? voiceId,
    double speed = 1.0,
  }) async {
    return KokoroCoreMlAudioResult(
      audio: Float32List.fromList(const <double>[0.1, -0.1, 0.2]),
      sampleRate: 24000,
      voiceId: voiceId ?? 'af_heart',
    );
  }

  @override
  Future<void> warmupCoreMl() async {}
}

class _TestManagedRenderer implements ManagedOpenTtsAudioRenderer {
  @override
  void Function(String requestId)? onPlaybackComplete;

  @override
  void Function(String requestId)? onPlaybackStart;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play(
    Float32List audio,
    int sampleRate, {
    required String requestId,
  }) async {
    onPlaybackStart?.call(requestId);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    onPlaybackComplete?.call(requestId);
  }

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop({String? requestId}) async {}
}

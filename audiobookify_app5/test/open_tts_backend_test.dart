import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kokoro_flutter/kokoro_flutter.dart';

import 'package:audiobookify/models/player_settings.dart';
import 'package:audiobookify/services/open_tts_backend.dart';
import 'package:audiobookify/services/soloud_sentence_renderer.dart';

void main() {
  test(
    'OpenTtsBackend maps voices and speaks with the selected voice id',
    () async {
      final engine = _FakeKokoroEngine();
      final renderer = _FakeOpenTtsRenderer();
      final backend = OpenTtsBackend(
        createOpenTts: (renderer) async => OpenTts(
          engine: engine,
          renderer: renderer,
          useStreamingForSpeak: false,
        ),
        renderer: renderer,
      );
      addTearDown(backend.dispose);

      await backend.initialize();
      final voices = await backend.listVoices();
      expect(voices.map((voice) => voice.id), ['voice_a', 'voice_b']);

      await backend.applySettings(
        const PlayerSettings(
          backend: SpeechBackendKind.openTts,
          voiceId: 'voice_b',
          speed: 1.25,
        ),
      );
      await backend.speak('hello');

      expect(engine.lastVoiceId, 'voice_b');
      expect(engine.lastSpeed, 1.25);
      expect(renderer.playCallCount, 1);
      expect(backend.capabilities.supportsPitch, isFalse);
    },
  );

  test('OpenTtsBackend uses the SoLoud renderer by default', () async {
    final engine = _FakeKokoroEngine();
    late OpenTtsAudioRenderer receivedRenderer;
    final backend = OpenTtsBackend(
      createOpenTts: (renderer) async {
        receivedRenderer = renderer;
        return OpenTts(
          engine: engine,
          renderer: renderer,
          useStreamingForSpeak: false,
        );
      },
    );
    addTearDown(backend.dispose);

    await backend.initialize();

    expect(receivedRenderer, isA<SoLoudSentenceRenderer>());
  });

  test('OpenTtsBackend shares concurrent initialize work', () async {
    final engine = _FakeKokoroEngine(initializeCompleter: Completer<void>());
    var createCalls = 0;
    final backend = OpenTtsBackend(
      createOpenTts: (renderer) async {
        createCalls += 1;
        return OpenTts(
          engine: engine,
          renderer: renderer,
          useStreamingForSpeak: false,
        );
      },
      renderer: _FakeOpenTtsRenderer(),
    );
    addTearDown(backend.dispose);

    final first = backend.initialize();
    final second = backend.initialize();
    expect(createCalls, 1);

    engine.completeInitialize();
    await Future.wait([first, second]);

    expect(createCalls, 1);
    expect(engine.initializeCalls, 1);
  });

  test('OpenTtsBackend consumes prefetched audio on exact match', () async {
    final engine = _FakeKokoroEngine();
    final renderer = _FakeOpenTtsRenderer();
    final backend = OpenTtsBackend(
      createOpenTts: (renderer) async => OpenTts(
        engine: engine,
        renderer: renderer,
        useStreamingForSpeak: false,
      ),
      renderer: renderer,
    );
    addTearDown(backend.dispose);

    await backend.initialize();
    await backend.prefetch('hello');
    await Future<void>.delayed(Duration.zero);
    await backend.speak('hello');

    expect(engine.synthesizedTexts, <String>['hello']);
    expect(renderer.playCallCount, 1);
  });

  test(
    'OpenTtsBackend discards prefetched audio after settings change',
    () async {
      final engine = _FakeKokoroEngine();
      final renderer = _FakeOpenTtsRenderer();
      final backend = OpenTtsBackend(
        createOpenTts: (renderer) async => OpenTts(
          engine: engine,
          renderer: renderer,
          useStreamingForSpeak: false,
        ),
        renderer: renderer,
      );
      addTearDown(backend.dispose);

      await backend.initialize();
      await backend.prefetch('hello');
      await Future<void>.delayed(Duration.zero);
      await backend.applySettings(
        const PlayerSettings(
          backend: SpeechBackendKind.openTts,
          voiceId: 'voice_b',
          speed: 1.25,
        ),
      );
      await backend.speak('hello');

      expect(engine.synthesizedTexts, <String>['hello', 'hello']);
      expect(engine.lastVoiceId, 'voice_b');
      expect(engine.lastSpeed, 1.25);
    },
  );

  test('OpenTtsBackend clearPrefetch drops cached audio', () async {
    final engine = _FakeKokoroEngine();
    final backend = OpenTtsBackend(
      createOpenTts: (renderer) async => OpenTts(
        engine: engine,
        renderer: renderer,
        useStreamingForSpeak: false,
      ),
      renderer: _FakeOpenTtsRenderer(),
    );
    addTearDown(backend.dispose);

    await backend.initialize();
    await backend.prefetch('hello');
    await Future<void>.delayed(Duration.zero);
    backend.clearPrefetch();
    await backend.speak('hello');

    expect(engine.synthesizedTexts, <String>['hello', 'hello']);
  });

  test(
    'OpenTtsBackend prefetch failure does not break foreground speak',
    () async {
      final engine = _FakeKokoroEngine(failSynthesizeCalls: <int>{1});
      final renderer = _FakeOpenTtsRenderer();
      final backend = OpenTtsBackend(
        createOpenTts: (renderer) async => OpenTts(
          engine: engine,
          renderer: renderer,
          useStreamingForSpeak: false,
        ),
        renderer: renderer,
      );
      addTearDown(backend.dispose);

      await backend.initialize();
      await backend.prefetch('hello');
      await Future<void>.delayed(Duration.zero);
      await backend.speak('hello');

      expect(engine.synthesizedTexts, <String>['hello', 'hello']);
      expect(renderer.playCallCount, 1);
    },
  );

  test('OpenTtsBackend recreates OpenTTS after engine invalidation', () async {
    final renderer = _FakeOpenTtsRenderer();
    var createCalls = 0;
    final backend = OpenTtsBackend(
      createOpenTts: (renderer) async {
        createCalls += 1;
        return OpenTts(
          engine: _FakeKokoroEngine(),
          renderer: renderer,
          useStreamingForSpeak: false,
        );
      },
      renderer: renderer,
    );
    addTearDown(backend.dispose);

    await backend.initialize();
    await backend.invalidateEngine(reason: 'test');
    await backend.initialize();

    expect(createCalls, 2);
  });
}

class _FakeKokoroEngine implements KokoroEngine {
  _FakeKokoroEngine({this.initializeCompleter, Set<int>? failSynthesizeCalls})
    : _failSynthesizeCalls = failSynthesizeCalls ?? <int>{};

  final Completer<void>? initializeCompleter;
  final Set<int> _failSynthesizeCalls;
  int initializeCalls = 0;
  int synthesizeCalls = 0;
  final List<String> synthesizedTexts = <String>[];

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
    await initializeCompleter?.future;
  }

  @override
  Future<void> warmup() async {}

  @override
  Future<SynthesisResult> synthesizeResult({
    required SynthesisInput input,
    double? speed,
    int? voiceIndex,
    String? voiceId,
  }) async {
    synthesizeCalls += 1;
    if (input case TextSynthesisInput(:final text)) {
      synthesizedTexts.add(text);
    }
    if (_failSynthesizeCalls.contains(synthesizeCalls)) {
      throw StateError('synthesize failed');
    }
    lastVoiceId = voiceId;
    lastSpeed = speed;
    return SynthesisResult(
      audio: Float32List.fromList(const [0.1, -0.1, 0.2]),
      sampleRate: 24000,
      diagnostics: SynthesisDiagnostics(
        inputKind: 'text',
        inputTextLen: 5,
        phonemeLen: 5,
        phonemes: 'hello',
        whitespaceLeading: 0,
        whitespaceTrailing: 0,
        whitespaceTrimmed: false,
        droppedSymbols: 0,
        timings: const InferenceTimings(
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
  Future<KokoroCancelToken> createCancelToken() async => _FakeCancelToken();

  @override
  Future<void> cancel(KokoroCancelToken token) async {
    if (token is _FakeCancelToken) {
      token.cancelled = true;
    }
  }

  @override
  Future<List<VoiceInfo>> getVoices() async => const [
    VoiceInfo(id: 'voice_a', name: 'Voice A', language: 'en-US', gender: 'f'),
    VoiceInfo(id: 'voice_b', name: 'Voice B', language: 'en-US', gender: 'm'),
  ];

  @override
  Future<List<String>> getLanguages() async => const ['en-US'];

  String? lastVoiceId;
  double? lastSpeed;

  void completeInitialize() {
    final completer = initializeCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}

class _FakeCancelToken implements KokoroCancelToken {
  @override
  bool get isCancelled => cancelled;

  bool cancelled = false;
}

class _FakeOpenTtsRenderer implements OpenTtsAudioRenderer {
  int playCallCount = 0;

  @override
  Future<void> play(
    Float32List audio,
    int sampleRate, {
    required String requestId,
  }) async {
    playCallCount += 1;
  }

  @override
  Future<void> stop({String? requestId}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}
}

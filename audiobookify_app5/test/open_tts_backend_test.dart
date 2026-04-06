import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kokoro_flutter/kokoro_flutter.dart';

import 'package:audiobookify/models/player_settings.dart';
import 'package:audiobookify/services/open_tts_backend.dart';

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
}

class _FakeKokoroEngine implements KokoroEngine {
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

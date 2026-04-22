import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kokoro_flutter/kokoro_coreml.dart';
import 'package:kokoro_flutter/src/coreml/platform_interface.dart';

import 'package:audiobookify/models/player_settings.dart';
import 'package:audiobookify/services/kokoro_coreml_backend.dart';
import 'package:audiobookify/services/open_tts_renderer_support.dart';

void main() {
  test(
    'KokoroCoreMlBackend maps voices and speaks with the selected voice id',
    () async {
      final platform = _FakeKokoroCoreMlPlatform();
      final renderer = _FakeRenderer();
      final backend = KokoroCoreMlBackend(
        coreMl: KokoroCoreMl(platform: platform),
        renderer: renderer,
      );
      addTearDown(backend.dispose);

      await backend.initialize();
      final voices = await backend.listVoices();
      expect(voices.map((voice) => voice.id), ['af_heart', 'am_puck']);

      await backend.applySettings(
        const PlayerSettings(
          backend: SpeechBackendKind.coreMlKokoro,
          voiceId: 'am_puck',
          speed: 1.25,
        ),
      );
      await backend.speak('hello');

      expect(platform.selectedVoiceId, 'am_puck');
      expect(platform.lastVoiceId, 'am_puck');
      expect(platform.lastSpeed, 1.25);
      expect(renderer.playCallCount, 1);
      expect(backend.capabilities.supportsPitch, isFalse);
    },
  );

  test('KokoroCoreMlBackend shares concurrent initialize work', () async {
    final platform = _FakeKokoroCoreMlPlatform();
    final backend = KokoroCoreMlBackend(
      coreMl: KokoroCoreMl(platform: platform),
      renderer: _FakeRenderer(),
    );
    addTearDown(backend.dispose);

    await Future.wait(<Future<void>>[
      backend.initialize(),
      backend.initialize(),
    ]);

    expect(platform.initializeCalls, 1);
    expect(platform.warmupCalls, 1);
  });

  test(
    'KokoroCoreMlBackend consumes prefetched audio on exact match',
    () async {
      final platform = _FakeKokoroCoreMlPlatform();
      final backend = KokoroCoreMlBackend(
        coreMl: KokoroCoreMl(platform: platform),
        renderer: _FakeRenderer(),
      );
      addTearDown(backend.dispose);

      await backend.initialize();
      await backend.prefetch('hello');
      await Future<void>.delayed(Duration.zero);
      await backend.speak('hello');

      expect(platform.synthesizedTexts, <String>['hello']);
    },
  );

  test(
    'KokoroCoreMlBackend discards prefetched audio after settings change',
    () async {
      final platform = _FakeKokoroCoreMlPlatform();
      final backend = KokoroCoreMlBackend(
        coreMl: KokoroCoreMl(platform: platform),
        renderer: _FakeRenderer(),
      );
      addTearDown(backend.dispose);

      await backend.initialize();
      await backend.prefetch('hello');
      await Future<void>.delayed(Duration.zero);
      await backend.applySettings(
        const PlayerSettings(
          backend: SpeechBackendKind.coreMlKokoro,
          voiceId: 'am_puck',
          speed: 1.25,
        ),
      );
      await backend.speak('hello');

      expect(platform.synthesizedTexts, <String>['hello', 'hello']);
      expect(platform.lastVoiceId, 'am_puck');
      expect(platform.lastSpeed, 1.25);
    },
  );
}

class _FakeKokoroCoreMlPlatform extends KokoroCoreMlPlatform {
  final List<String> synthesizedTexts = <String>[];
  int initializeCalls = 0;
  int warmupCalls = 0;
  String? selectedVoiceId;
  String? lastVoiceId;
  double? lastSpeed;

  @override
  Future<bool> isCoreMlAvailable() async => true;

  @override
  Future<void> initializeCoreMl({String? assetsRoot}) async {
    initializeCalls += 1;
  }

  @override
  Future<List<KokoroCoreMlVoice>> listCoreMlVoices() async {
    return const <KokoroCoreMlVoice>[
      KokoroCoreMlVoice(
        id: 'af_heart',
        name: 'Heart',
        languageCode: 'en-US',
        localeLabel: 'English (US)',
        gender: 'female',
      ),
      KokoroCoreMlVoice(
        id: 'am_puck',
        name: 'Puck',
        languageCode: 'en-US',
        localeLabel: 'English (US)',
        gender: 'male',
      ),
    ];
  }

  @override
  Future<void> selectCoreMlVoice(String voiceId) async {
    selectedVoiceId = voiceId;
  }

  @override
  Future<KokoroCoreMlAudioResult> synthesizeCoreMl(
    String text, {
    String? voiceId,
    double speed = 1.0,
  }) async {
    synthesizedTexts.add(text);
    lastVoiceId = voiceId;
    lastSpeed = speed;
    return KokoroCoreMlAudioResult(
      audio: Float32List.fromList(const <double>[0.1, -0.1, 0.2]),
      sampleRate: 24000,
      voiceId: voiceId ?? 'af_heart',
    );
  }

  @override
  Future<void> warmupCoreMl() async {
    warmupCalls += 1;
  }
}

class _FakeRenderer implements ManagedOpenTtsAudioRenderer {
  @override
  void Function(String requestId)? onPlaybackComplete;

  @override
  void Function(String requestId)? onPlaybackStart;

  int playCallCount = 0;

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
    playCallCount += 1;
    onPlaybackStart?.call(requestId);
    onPlaybackComplete?.call(requestId);
  }

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop({String? requestId}) async {}
}

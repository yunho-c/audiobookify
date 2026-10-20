import 'dart:async';

import 'package:audiobookify/models/player_settings.dart';
import 'package:audiobookify/services/tts_audio_handler.dart';
import 'package:audiobookify/services/tts_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tts_service_test.dart' show FakeSpeechBackend, waitUntil;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.ryanheise.audio_session');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  for (final command in ['pause', 'stop', 'close']) {
    test(
      '$command cancels play waiting for audio-session initialization',
      () async {
        final ready = Completer<void>();
        var configuring = false;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'setConfiguration') {
            configuring = true;
            await ready.future;
          }
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final backend = FakeSpeechBackend();
        final service = TtsService(
          backends: [backend],
          initialSettings: const PlayerSettings(
            backend: SpeechBackendKind.mlsr,
          ),
        )..loadContent(['Hello.']);
        final handler = TtsAudioHandler(service);
        final playing = handler.play();
        await waitUntil(() => configuring);
        final cancelled = switch (command) {
          'pause' => handler.pause(),
          'stop' => handler.stop(),
          _ => handler.close(),
        };
        ready.complete();
        await Future.wait([playing, cancelled]);
        expect(backend.texts, isEmpty);
        expect(handler.playbackState.value.playing, isFalse);
        await handler.close();
        await service.close();
      },
    );
  }

  test('media state reports buffering, playback and stopped', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final ready = Completer<void>();
    final backend = FakeSpeechBackend()..initializeGate = ready.future;
    final service = TtsService(
      backends: [backend],
      initialSettings: const PlayerSettings(backend: SpeechBackendKind.mlsr),
    )..loadContent(['Hello.']);
    final handler = TtsAudioHandler(service);
    await handler.play();
    await waitUntil(() => backend.initializeCalls > 0);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.buffering,
    );
    ready.complete();
    await waitUntil(() => backend.texts.isNotEmpty);
    expect(handler.playbackState.value.playing, isTrue);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.ready,
    );
    await handler.close();
    expect(handler.playbackState.value.playing, isFalse);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.idle,
    );
    await service.close();
  });
}

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlsr/mlsr.dart';
import 'package:audiobookify/models/player_settings.dart';
import 'package:audiobookify/services/mlsr_speech_backend.dart';
import 'package:audiobookify/services/speech_backend.dart';

Future<void> settleUntil(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) fail('Backend transition timed out');
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  test(
    'one persistent model applies voice and synthesis speed without stretching',
    () async {
      final session = FakeSession();
      var opens = 0;
      final backend = MlsrSpeechBackend(
        createSession: () async {
          opens++;
          return session;
        },
      );
      addTearDown(backend.dispose);
      await Future.wait([backend.initialize(), backend.initialize()]);
      expect(opens, 1);
      expect((await backend.listVoices()).single.id, 'supertonic3:F1');
      expect(backend.capabilities.supportsPitch, isFalse);
      await backend.applySettings(
        const PlayerSettings(
          backend: SpeechBackendKind.mlsr,
          speed: 1.5,
          pitch: 1.8,
          voiceId: 'supertonic3:F1',
        ),
      );
      final playing = backend.speak('안녕하세요.', languageCode: 'ko_KR');
      await settleUntil(() => session.playbacks.isNotEmpty);
      expect(session.request!.locale, 'ko-KR');
      expect(session.request!.fallback, VoiceFallback.sameLanguage);
      expect(session.request!.voice, 'supertonic3:F1');
      expect(session.request!.speakingRate, 1.5);
      expect(session.options!.playbackRate, 1.0);
      expect(session.options!.retainAudio, isFalse);
      session.playbacks.single.result.complete(true);
      await playing;
      expect(session.playbacks.single.disposed, isTrue);
      expect(opens, 1);
    },
  );

  test(
    'start follows native playback and speak waits for native drain',
    () async {
      final session = FakeSession();
      final backend = MlsrSpeechBackend(createSession: () async => session);
      addTearDown(backend.dispose);
      final events = <SpeechBackendEventType>[];
      final subscription = backend.events.listen((e) => events.add(e.type));
      addTearDown(subscription.cancel);
      var finished = false;
      final playing = backend.speak('Hello.').then((_) => finished = true);
      await settleUntil(() => session.playbacks.isNotEmpty);
      expect(events, isEmpty);
      expect(finished, isFalse);
      session.playbacks.single.started.add(null);
      await settleUntil(() => events.isNotEmpty);
      expect(events, [SpeechBackendEventType.start]);
      expect(finished, isFalse);
      session.playbacks.single.result.complete(true);
      await playing;
      expect(events, [
        SpeechBackendEventType.start,
        SpeechBackendEventType.complete,
      ]);
    },
  );

  test(
    'stop during model loading prevents speech without discarding the reusable model',
    () async {
      final gate = Completer<MlsrSession>();
      final session = FakeSession();
      final backend = MlsrSpeechBackend(createSession: () => gate.future);
      addTearDown(backend.dispose);
      final speaking = backend.speak('Obsolete.');
      final stopping = backend.stop();
      gate.complete(session);
      await Future.wait([speaking, stopping]);
      expect(session.playbacks, isEmpty);
      final next = backend.speak('Current.');
      await settleUntil(() => session.playbacks.isNotEmpty);
      session.playbacks.single.result.complete(true);
      await next;
      expect(session.texts, ['Current.']);
    },
  );

  test(
    'replacement cancels and releases the previous request before admission',
    () async {
      final session = FakeSession();
      final backend = MlsrSpeechBackend(createSession: () async => session);
      addTearDown(backend.dispose);
      final first = backend.speak('First.');
      await settleUntil(() => session.playbacks.length == 1);
      final firstRequest = session.request!;
      expect(firstRequest.speakingRate, 1.0);
      expect(session.options!.playbackRate, 1.0);
      await backend.applySettings(
        const PlayerSettings(backend: SpeechBackendKind.mlsr, speed: 1.4),
      );
      final second = backend.speak('Second.');
      await settleUntil(() => session.playbacks.length == 2);
      expect(session.playbacks.first.cancelled, isTrue);
      expect(session.playbacks.first.disposed, isTrue);
      expect(firstRequest.speakingRate, 1.0);
      expect(session.request!.speakingRate, 1.4);
      expect(session.options!.playbackRate, 1.0);
      session.playbacks.last.result.complete(true);
      await Future.wait([first, second]);
    },
  );

  test(
    'dispose during load releases the late session and cannot reopen',
    () async {
      final gate = Completer<MlsrSession>();
      final session = FakeSession();
      final backend = MlsrSpeechBackend(createSession: () => gate.future);
      final loading = expectLater(backend.initialize(), throwsStateError);
      final closing = backend.dispose();
      gate.complete(session);
      await Future.wait([loading, closing]);
      expect(session.disposeCount, 1);
      await backend.dispose();
      expect(session.disposeCount, 1);
      await expectLater(backend.speak('Closed.'), throwsStateError);
    },
  );

  test(
    'failed initialization can retry, and failed playback still releases its handle',
    () async {
      final session = FakeSession();
      var opens = 0;
      final backend = MlsrSpeechBackend(
        createSession: () async {
          if (++opens == 1) throw StateError('Corrupt model');
          return session;
        },
      );
      addTearDown(backend.dispose);
      await expectLater(backend.initialize(), throwsStateError);
      await backend.initialize();
      final failed = expectLater(backend.speak('Hello.'), throwsStateError);
      await settleUntil(() => session.playbacks.isNotEmpty);
      session.playbacks.single.result.completeError(
        StateError('Native output failed'),
      );
      await failed;
      expect(session.playbacks.single.disposed, isTrue);
      expect(opens, 2);
    },
  );
}

class FakeSession implements MlsrSession {
  final texts = <String>[];
  final playbacks = <FakePlayback>[];
  RequestOptions? request;
  SpeechOptions? options;
  int disposeCount = 0;
  @override
  Future<List<SpeechVoiceOption>> listVoices() async => [
    const SpeechVoiceOption(
      backend: SpeechBackendKind.mlsr,
      id: 'supertonic3:F1',
      label: 'Sarah',
    ),
  ];
  @override
  MlsrPlayback speak(
    String text, {
    required RequestOptions request,
    required SpeechOptions options,
  }) {
    this.request = request;
    this.options = options;
    texts.add(text);
    final playback = FakePlayback();
    playbacks.add(playback);
    return playback;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}

class FakePlayback implements MlsrPlayback {
  final result = Completer<bool>();
  final started = StreamController<void>.broadcast();
  bool cancelled = false, disposed = false;
  @override
  Stream<void> get starts => started.stream;
  @override
  Future<bool> get done => result.future;
  @override
  void cancel() {
    cancelled = true;
    if (!result.isCompleted) result.complete(false);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await started.close();
  }
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:audiobookify/models/player_settings.dart';
import 'package:audiobookify/services/speech_backend.dart';
import 'package:audiobookify/services/tts_service.dart';

Future<void> waitUntil(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) fail('State transition timed out');
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  TtsService serviceFor(
    FakeSpeechBackend backend, {
    FakeSpeechBackend? system,
  }) {
    final service = TtsService(
      backends: [if (system != null) system, backend],
      initialSettings: PlayerSettings(
        backend: backend.backendId,
        voiceId: 'supertonic3:M1',
      ),
    );
    addTearDown(service.close);
    service.loadContent(
      ['Chapter'],
      sentences: [
        ['First.', 'Second.', 'Third.'],
      ],
      languageCode: 'ko-KR',
    );
    return service;
  }

  test(
    'advances only when playback completes, then completes the chapter once',
    () async {
      final backend = FakeSpeechBackend();
      final service = serviceFor(backend);
      var completed = 0;
      service.onComplete = () => completed++;
      await service.play();
      await waitUntil(() => backend.texts.length == 1);
      expect(service.state.sentenceIndex, 0);
      expect(completed, 0);
      backend.finish();
      await waitUntil(() => backend.texts.length == 2);
      expect(service.state.sentenceIndex, 1);
      backend.finish();
      await waitUntil(() => backend.texts.length == 3);
      backend.finish();
      await waitUntil(() => completed == 1);
      expect(backend.texts, ['First.', 'Second.', 'Third.']);
      expect(backend.languages, everyElement('ko-KR'));
      expect(service.state.status, TtsStatus.stopped);
      expect(service.state.isPreparing, isFalse);
    },
  );

  test('pause and resume replay the selected sentence', () async {
    final backend = FakeSpeechBackend();
    final service = serviceFor(backend);
    await service.play();
    await waitUntil(() => backend.texts.isNotEmpty);
    await service.pause();
    expect(service.state.status, TtsStatus.paused);
    expect(service.state.sentenceIndex, 0);
    await service.play();
    await waitUntil(() => backend.texts.length == 2);
    expect(backend.texts, ['First.', 'First.']);
  });

  test('backend and voice changes restart at the current sentence', () async {
    final backend = FakeSpeechBackend();
    final system = FakeSpeechBackend(kind: SpeechBackendKind.system);
    final service = serviceFor(backend, system: system);
    await service.play();
    await waitUntil(() => backend.texts.isNotEmpty);
    await service.applySettings(
      const PlayerSettings(
        backend: SpeechBackendKind.system,
        voiceId: 'en-US::Test',
      ),
    );
    await waitUntil(() => system.texts.isNotEmpty);
    expect(system.texts, ['First.']);
    expect(system.settings.last.voiceId, 'en-US::Test');
    expect(service.activeBackendKind, SpeechBackendKind.system);
  });

  test('idle settings do not initialize models', () async {
    final backend = FakeSpeechBackend();
    final service = serviceFor(backend);
    await service.applySettings(
      const PlayerSettings(backend: SpeechBackendKind.mlsr, speed: 1.5),
    );
    expect(backend.initializeCalls, 0);
    expect(backend.settings, isEmpty);
  });

  for (final phase in ['initialize', 'settings']) {
    test('stop during $phase prevents late speech and permits reuse', () async {
      final gate = Completer<void>();
      final backend = FakeSpeechBackend();
      if (phase == 'initialize') backend.initializeGate = gate.future;
      if (phase == 'settings') backend.settingsGate = gate.future;
      final service = serviceFor(backend);
      await service.play();
      await waitUntil(
        () => phase == 'initialize'
            ? backend.initializeCalls > 0
            : backend.settings.isNotEmpty,
      );
      await service.stop();
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(backend.texts, isEmpty);
      expect(service.state.status, TtsStatus.stopped);
      await service.play();
      await waitUntil(() => backend.texts.isNotEmpty);
      expect(backend.texts, ['First.']);
    });
  }

  test(
    'rapid seeks while stop drains admit only the newest sentence',
    () async {
      final backend = FakeSpeechBackend();
      final service = serviceFor(backend);
      await service.play();
      await waitUntil(() => backend.texts.isNotEmpty);
      final gate = Completer<void>();
      backend.stopGate = gate.future;
      final first = service.jumpToSentence(0, 1);
      final second = service.jumpToSentence(0, 2);
      gate.complete();
      await Future.wait([first, second]);
      await waitUntil(() => backend.texts.length == 2);
      expect(backend.texts, ['First.', 'Third.']);
      expect(service.state.sentenceIndex, 2);
    },
  );

  test(
    'loading another chapter invalidates old completion and clears locale',
    () async {
      final backend = FakeSpeechBackend();
      final service = serviceFor(backend);
      var completed = 0;
      service.onComplete = () => completed++;
      await service.play();
      await waitUntil(() => backend.texts.isNotEmpty);
      service.loadContent(
        ['New chapter.'],
        sentences: [
          ['New chapter.'],
        ],
      );
      await service.play();
      await waitUntil(() => backend.texts.length == 2);
      expect(backend.texts, ['First.', 'New chapter.']);
      expect(backend.languages.last, isNull);
      expect(completed, 0);
      backend.finish();
      await waitUntil(() => completed == 1);
    },
  );

  test(
    'failed initialization is visible, cached for the run, and retryable',
    () async {
      final backend = FakeSpeechBackend()..failInitialize = true;
      final system = FakeSpeechBackend(kind: SpeechBackendKind.system);
      final service = serviceFor(backend, system: system);
      await service.play();
      await waitUntil(() => system.texts.isNotEmpty);
      expect(service.state.notice, contains('Using System voice'));
      expect(service.activeBackendKind, SpeechBackendKind.system);
      expect(system.settings.last.voiceId, isNull);
      system.finish();
      await waitUntil(() => system.texts.length == 2);
      expect(backend.initializeCalls, 1);
      backend.failInitialize = false;
      await service.retry();
      await waitUntil(() => backend.texts.isNotEmpty);
      expect(backend.texts, ['Second.']);
      expect(service.state.notice, isNull);
      expect(service.activeBackendKind, SpeechBackendKind.mlsr);
    },
  );

  test(
    'speech failure stops without skipping or completing the chapter',
    () async {
      final backend = FakeSpeechBackend();
      final service = serviceFor(backend);
      var completed = false;
      service.onComplete = () => completed = true;
      await service.play();
      await waitUntil(() => backend.texts.isNotEmpty);
      backend.finish(error: StateError('Unsupported text'));
      await waitUntil(() => service.state.status == TtsStatus.stopped);
      expect(service.state.sentenceIndex, 0);
      expect(service.state.notice, contains('could not continue'));
      expect(completed, isFalse);
    },
  );

  test('voice listing does not silently cross backend identities', () async {
    final backend = FakeSpeechBackend()..failInitialize = true;
    final service = serviceFor(
      backend,
      system: FakeSpeechBackend(kind: SpeechBackendKind.system),
    );
    await expectLater(service.listVoices(), throwsStateError);
  });

  test(
    'disposal joins initialization and never speaks after closure',
    () async {
      final gate = Completer<void>();
      final backend = FakeSpeechBackend()..initializeGate = gate.future;
      final service = serviceFor(backend);
      await service.play();
      await waitUntil(() => backend.initializeCalls > 0);
      final closing = service.close();
      gate.complete();
      await closing;
      expect(backend.texts, isEmpty);
      expect(backend.disposed, isTrue);
    },
  );

  test(
    'empty paragraphs are skipped without inventing negative cursors',
    () async {
      final backend = FakeSpeechBackend();
      final service = serviceFor(backend);
      service.loadContent(
        ['', 'Hello', ''],
        sentences: [
          [],
          ['Hello.'],
          [],
        ],
      );
      await service.jumpToParagraph(0);
      expect(service.state.sentenceIndex, 0);
      await service.play();
      await waitUntil(() => backend.texts.isNotEmpty);
      expect(service.state.paragraphIndex, 1);
      backend.finish();
      await waitUntil(() => service.state.status == TtsStatus.stopped);
    },
  );
}

class FakeSpeechBackend implements SpeechBackend {
  FakeSpeechBackend({this.kind = SpeechBackendKind.mlsr});
  final SpeechBackendKind kind;
  final texts = <String>[];
  final languages = <String?>[];
  final settings = <PlayerSettings>[];
  final controller = StreamController<SpeechBackendEvent>.broadcast();
  Completer<void>? speaking;
  Future<void>? initializeGate, settingsGate, stopGate;
  bool failInitialize = false, disposed = false;
  int initializeCalls = 0;
  @override
  SpeechBackendKind get backendId => kind;
  @override
  String get displayName => kind.label;
  @override
  SpeechBackendCapabilities get capabilities => const SpeechBackendCapabilities(
    supportsPitch: false,
    supportsVoiceSelection: true,
    supportsPause: true,
  );
  @override
  Stream<SpeechBackendEvent> get events => controller.stream;
  @override
  Future<void> initialize() async {
    initializeCalls++;
    await initializeGate;
    if (failInitialize) throw StateError('Model missing');
  }

  @override
  Future<void> applySettings(PlayerSettings value) async {
    settings.add(value);
    await settingsGate;
  }

  @override
  Future<List<SpeechVoiceOption>> listVoices() async {
    await initialize();
    return [];
  }

  @override
  Future<void> speak(String text, {String? languageCode}) async {
    texts.add(text);
    languages.add(languageCode);
    speaking = Completer<void>();
    controller.add(
      const SpeechBackendEvent(type: SpeechBackendEventType.start),
    );
    await speaking!.future;
  }

  void finish({Object? error}) {
    final current = speaking;
    speaking = null;
    if (current == null || current.isCompleted) return;
    if (error == null) {
      current.complete();
    } else {
      current.completeError(error);
    }
  }

  @override
  Future<void> stop() async {
    finish();
    await stopGate;
  }

  @override
  Future<void> pause() => stop();
  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await stop();
    await controller.close();
  }
}

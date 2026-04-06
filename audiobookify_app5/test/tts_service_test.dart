import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:audiobookify/models/player_settings.dart';
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

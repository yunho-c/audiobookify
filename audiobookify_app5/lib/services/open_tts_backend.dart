import 'dart:async';

import 'package:kokoro_flutter/kokoro_flutter.dart';

import '../models/player_settings.dart';
import 'just_audio_sentence_renderer.dart';
import 'speech_backend.dart';

typedef OpenTtsFactory =
    Future<OpenTts> Function(OpenTtsAudioRenderer renderer);

class OpenTtsBackend implements SpeechBackend {
  OpenTtsBackend({
    required OpenTtsFactory createOpenTts,
    OpenTtsAudioRenderer? renderer,
  }) : _createOpenTts = createOpenTts,
       _renderer = renderer ?? JustAudioSentenceRenderer();

  final OpenTtsFactory _createOpenTts;
  final OpenTtsAudioRenderer _renderer;
  final StreamController<SpeechBackendEvent> _events =
      StreamController<SpeechBackendEvent>.broadcast();

  OpenTts? _openTts;
  StreamSubscription<TtsEvent>? _eventSubscription;
  bool _initialized = false;

  @override
  SpeechBackendKind get backendId => SpeechBackendKind.openTts;

  @override
  String get displayName => 'OpenTTS';

  @override
  SpeechBackendCapabilities get capabilities => const SpeechBackendCapabilities(
    supportsPitch: false,
    supportsVoiceSelection: true,
    supportsPause: true,
  );

  @override
  Stream<SpeechBackendEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    final openTts = await _createOpenTts(_renderer);
    await openTts.awaitSpeakCompletion(true);
    await openTts.init(warmup: false);
    _eventSubscription = openTts.events.listen(_handleEvent);
    _openTts = openTts;
    _initialized = true;
  }

  @override
  Future<List<SpeechVoiceOption>> listVoices() async {
    await initialize();
    final voices = await _openTts!.getVoices();
    final mapped = voices
        .map(
          (voice) => SpeechVoiceOption(
            backend: backendId,
            id: voice.id,
            label: voice.name ?? voice.id,
            languageCode: voice.language,
            localeLabel: voice.language,
            gender: voice.gender,
          ),
        )
        .toList();
    mapped.sort((a, b) => a.label.compareTo(b.label));
    return mapped;
  }

  @override
  Future<void> applySettings(PlayerSettings settings) async {
    await initialize();
    final openTts = _openTts!;
    await openTts.setRate(settings.speed);
    await openTts.setVolume(1.0);
    if (settings.voiceId != null) {
      await openTts.setVoice(settings.voiceId!);
    } else {
      await openTts.clearVoice();
    }
  }

  @override
  Future<void> speak(String text) async {
    await initialize();
    final result = await _openTts!.speak(text, queueMode: QueueMode.flush);
    if (result == SpeakResult.rejected) {
      throw StateError('OpenTTS rejected the utterance.');
    }
  }

  @override
  Future<void> pause() async {
    await stop();
  }

  @override
  Future<void> stop() async {
    if (!_initialized) return;
    await _openTts!.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _openTts?.dispose();
    if (_renderer case final JustAudioSentenceRenderer renderer) {
      await renderer.dispose();
    }
    await _events.close();
  }

  void _handleEvent(TtsEvent event) {
    switch (event.type) {
      case TtsEventType.start:
        _events.add(
          const SpeechBackendEvent(type: SpeechBackendEventType.start),
        );
      case TtsEventType.complete:
        _events.add(
          const SpeechBackendEvent(type: SpeechBackendEventType.complete),
        );
      case TtsEventType.error:
        _events.add(
          SpeechBackendEvent(
            type: SpeechBackendEventType.error,
            message: event.error?.message,
          ),
        );
      case TtsEventType.pause:
      case TtsEventType.resume:
      case TtsEventType.cancel:
      case TtsEventType.progress:
      case TtsEventType.diagnostic:
        break;
    }
  }
}

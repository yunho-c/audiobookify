import 'dart:async';

import 'package:kokoro_flutter/kokoro_flutter.dart';

import '../models/player_settings.dart';
import 'just_audio_sentence_renderer.dart';
import 'speech_backend.dart';
import 'tts_debug_logging.dart';

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
  Future<void>? _initializeFuture;

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
    final inFlight = _initializeFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _initializeImpl();
    _initializeFuture = future;
    try {
      await future;
    } finally {
      if (identical(_initializeFuture, future)) {
        _initializeFuture = null;
      }
    }
  }

  Future<void> _initializeImpl() async {
    logTtsDebug('Initializing OpenTTS backend', category: 'tts.open_tts');
    final openTts = await _createOpenTts(_renderer);
    try {
      await openTts.awaitSpeakCompletion(true);
      await openTts.init(warmup: false);
      _eventSubscription = openTts.events.listen(_handleEvent);
      _openTts = openTts;
      _initialized = true;
      logTtsDebug('OpenTTS backend initialized', category: 'tts.open_tts');
    } catch (_) {
      openTts.dispose();
      rethrow;
    }
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
    logTtsDebug(
      'OpenTTS listed ${mapped.length} voices',
      category: 'tts.open_tts',
    );
    return mapped;
  }

  @override
  Future<void> applySettings(PlayerSettings settings) async {
    await initialize();
    logTtsDebug(
      'OpenTTS applySettings voiceId=${settings.voiceId ?? "default"} speed=${settings.speed}',
      category: 'tts.open_tts',
    );
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
    logTtsDebug('OpenTTS speak "$text"', category: 'tts.open_tts');
    final stopwatch = Stopwatch()..start();
    final result = await _openTts!.speak(text, queueMode: QueueMode.flush);
    stopwatch.stop();
    logTtsDebug(
      'OpenTTS speak completed textLength=${text.length} result=${result.name} elapsedMs=${stopwatch.elapsedMilliseconds}',
      category: 'tts.open_tts',
    );
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
    logTtsDebug('OpenTTS stop', category: 'tts.open_tts');
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
    final diagnostics = event.diagnostics;
    final diagnosticsSuffix = diagnostics == null
        ? ''
        : ' totalMs=${diagnostics.timings.totalMs} '
              'g2pMs=${diagnostics.timings.g2PMs} '
              'vocabMs=${diagnostics.timings.vocabMs} '
              'pipelineMs=${diagnostics.timings.pipelineMs} '
              'bertMs=${diagnostics.timings.bertMs} '
              'durationMs=${diagnostics.timings.durationMs} '
              'alignBuildMs=${diagnostics.timings.alignmentBuildMs} '
              'alignGatherMs=${diagnostics.timings.alignmentGatherMs} '
              'pitchEnergyMs=${diagnostics.timings.pitchEnergyMs} '
              'textEncoderMs=${diagnostics.timings.textEncoderMs} '
              'decoderMs=${diagnostics.timings.decoderMs} '
              'inputKind=${diagnostics.inputKind} '
              'inputTextLen=${diagnostics.inputTextLen ?? 0} '
              'phonemeLen=${diagnostics.phonemeLen}';
    logTtsDebug(
      'OpenTTS event=${event.type.name} requestId=${event.requestId}$diagnosticsSuffix',
      category: 'tts.open_tts',
      error: event.error,
    );
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

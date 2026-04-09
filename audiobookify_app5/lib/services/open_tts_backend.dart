import 'dart:async';

import 'package:kokoro_flutter/kokoro_flutter.dart';

import '../models/player_settings.dart';
import 'open_tts_renderer_support.dart';
import 'soloud_sentence_renderer.dart';
import 'speech_backend.dart';
import 'tts_debug_logging.dart';

typedef OpenTtsFactory =
    Future<OpenTts> Function(OpenTtsAudioRenderer renderer);

class OpenTtsBackend implements SpeechBackend {
  OpenTtsBackend({
    required OpenTtsFactory createOpenTts,
    OpenTtsAudioRenderer? renderer,
  }) : _createOpenTts = createOpenTts,
       _renderer = renderer ?? SoLoudSentenceRenderer() {
    if (_renderer case final ManagedOpenTtsAudioRenderer renderer) {
      renderer.onPlaybackStart = _handlePlaybackStarted;
    }
  }

  final OpenTtsFactory _createOpenTts;
  final OpenTtsAudioRenderer _renderer;
  final StreamController<SpeechBackendEvent> _events =
      StreamController<SpeechBackendEvent>.broadcast();

  OpenTts? _openTts;
  StreamSubscription<TtsEvent>? _eventSubscription;
  bool _initialized = false;
  Future<void>? _initializeFuture;
  PlayerSettings _currentSettings = const PlayerSettings(
    backend: SpeechBackendKind.openTts,
  );
  _PrefetchedSentence? _prefetchedSentence;
  _PrefetchTask? _prefetchTask;
  _PrefetchKey? _scheduledPrefetchKey;
  int _prefetchToken = 0;
  int _requestCounter = 0;
  bool _speakInProgress = false;

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
    clearPrefetch();
    _currentSettings = settings;
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
    _speakInProgress = true;
    await initialize();
    try {
      logTtsDebug('OpenTTS speak "$text"', category: 'tts.open_tts');
      final _PrefetchKey key = _prefetchKeyFor(text);
      final _PrefetchedSentence? prefetched = await _takePrefetchedSentence(
        key,
      );
      if (prefetched != null) {
        final requestId = _nextRequestId();
        _events.add(
          const SpeechBackendEvent(type: SpeechBackendEventType.start),
        );
        logTtsDebug(
          'OpenTTS prefetch hit requestId=$requestId textLength=${text.length} prefetchedMs=${prefetched.elapsedMs}',
          category: 'tts.open_tts',
        );
        logTtsDebug(
          'OpenTTS prefetched diagnostics requestId=$requestId '
          'totalMs=${prefetched.result.diagnostics.timings.totalMs} '
          'g2pMs=${prefetched.result.diagnostics.timings.g2PMs} '
          'vocabMs=${prefetched.result.diagnostics.timings.vocabMs} '
          'pipelineMs=${prefetched.result.diagnostics.timings.pipelineMs} '
          'bertMs=${prefetched.result.diagnostics.timings.bertMs} '
          'durationMs=${prefetched.result.diagnostics.timings.durationMs} '
          'alignBuildMs=${prefetched.result.diagnostics.timings.alignmentBuildMs} '
          'alignGatherMs=${prefetched.result.diagnostics.timings.alignmentGatherMs} '
          'pitchEnergyMs=${prefetched.result.diagnostics.timings.pitchEnergyMs} '
          'textEncoderMs=${prefetched.result.diagnostics.timings.textEncoderMs} '
          'decoderMs=${prefetched.result.diagnostics.timings.decoderMs}',
          category: 'tts.open_tts',
        );
        await _renderer.play(
          prefetched.result.audio,
          prefetched.result.sampleRate,
          requestId: requestId,
        );
        _events.add(
          const SpeechBackendEvent(type: SpeechBackendEventType.complete),
        );
        return;
      }

      logTtsDebug(
        'OpenTTS prefetch miss textLength=${text.length}',
        category: 'tts.open_tts',
      );
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
    } finally {
      _speakInProgress = false;
    }
  }

  Future<void> prefetch(String text) async {
    await initialize();
    final _PrefetchKey key = _prefetchKeyFor(text);
    if (_prefetchedSentence?.key == key) {
      logTtsDebug(
        'OpenTTS prefetch requested for cached textLength=${text.length}',
        category: 'tts.open_tts',
      );
      return;
    }
    if (_prefetchTask?.key == key) {
      logTtsDebug(
        'OpenTTS prefetch already in flight textLength=${text.length}',
        category: 'tts.open_tts',
      );
      return;
    }

    _scheduledPrefetchKey = key;
    logTtsDebug(
      'OpenTTS prefetch scheduled textLength=${text.length}',
      category: 'tts.open_tts',
    );

    final bool supportsDeferredPrefetch =
        _renderer is ManagedOpenTtsAudioRenderer;
    if (!_speakInProgress || !supportsDeferredPrefetch) {
      unawaited(_startScheduledPrefetchIfAny());
    }
  }

  void clearPrefetch() {
    final bool hadPrefetch =
        _scheduledPrefetchKey != null ||
        _prefetchedSentence != null ||
        _prefetchTask != null;
    _prefetchToken += 1;
    _scheduledPrefetchKey = null;
    _prefetchedSentence = null;
    _prefetchTask = null;
    if (hadPrefetch) {
      logTtsDebug('OpenTTS prefetch cleared', category: 'tts.open_tts');
    }
  }

  @override
  Future<void> pause() async {
    await stop();
  }

  @override
  Future<void> stop() async {
    if (!_initialized) return;
    clearPrefetch();
    logTtsDebug('OpenTTS stop', category: 'tts.open_tts');
    await _openTts!.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _openTts?.dispose();
    if (_renderer case final ManagedOpenTtsAudioRenderer renderer) {
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

  void _handlePlaybackStarted(String requestId) {
    logTtsDebug(
      'OpenTTS playback started requestId=$requestId',
      category: 'tts.open_tts',
    );
    unawaited(_startScheduledPrefetchIfAny());
  }

  Future<void> _startScheduledPrefetchIfAny() async {
    final _PrefetchKey? key = _scheduledPrefetchKey;
    if (key == null) {
      return;
    }
    if (_prefetchedSentence?.key == key || _prefetchTask?.key == key) {
      _scheduledPrefetchKey = null;
      return;
    }

    _scheduledPrefetchKey = null;
    final int token = ++_prefetchToken;
    final Stopwatch stopwatch = Stopwatch()..start();
    logTtsDebug(
      'OpenTTS prefetch starting textLength=${key.text.length}',
      category: 'tts.open_tts',
    );
    final Future<_PrefetchedSentence?> future = _synthesizePrefetchedSentence(
      key,
      token,
      stopwatch,
    );
    _prefetchTask = _PrefetchTask(key: key, token: token, future: future);
    unawaited(future);
  }

  Future<_PrefetchedSentence?> _synthesizePrefetchedSentence(
    _PrefetchKey key,
    int token,
    Stopwatch stopwatch,
  ) async {
    try {
      final SynthesisResult result = await _openTts!.synthesizeTextResult(
        key.text,
      );
      stopwatch.stop();
      if (token != _prefetchToken) {
        logTtsDebug(
          'OpenTTS prefetch stale discard textLength=${key.text.length}',
          category: 'tts.open_tts',
        );
        return null;
      }
      final prefetched = _PrefetchedSentence(
        key: key,
        result: result,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
      _prefetchedSentence = prefetched;
      if (_prefetchTask?.token == token) {
        _prefetchTask = null;
      }
      logTtsDebug(
        'OpenTTS prefetch completed textLength=${key.text.length} elapsedMs=${prefetched.elapsedMs}',
        category: 'tts.open_tts',
      );
      return prefetched;
    } on Object catch (error, stackTrace) {
      stopwatch.stop();
      if (_prefetchTask?.token == token) {
        _prefetchTask = null;
      }
      logTtsDebug(
        'OpenTTS prefetch failed textLength=${key.text.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
        category: 'tts.open_tts',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<_PrefetchedSentence?> _takePrefetchedSentence(_PrefetchKey key) async {
    final _PrefetchedSentence? cached = _prefetchedSentence;
    if (cached != null) {
      if (cached.key == key) {
        _prefetchedSentence = null;
        return cached;
      }
      logTtsDebug(
        'OpenTTS prefetch stale cache discarded textLength=${cached.key.text.length}',
        category: 'tts.open_tts',
      );
      _prefetchedSentence = null;
    }

    final _PrefetchTask? task = _prefetchTask;
    if (task != null && task.key == key) {
      logTtsDebug(
        'OpenTTS awaiting in-flight prefetch textLength=${key.text.length}',
        category: 'tts.open_tts',
      );
      final _PrefetchedSentence? prefetched = await task.future;
      if (prefetched != null && prefetched.key == key) {
        _prefetchedSentence = null;
        return prefetched;
      }
      return null;
    }
    return null;
  }

  _PrefetchKey _prefetchKeyFor(String text) {
    return _PrefetchKey(
      text: text,
      voiceId: _currentSettings.voiceId,
      speed: _currentSettings.speed,
    );
  }

  String _nextRequestId() {
    _requestCounter += 1;
    return 'prefetch_${DateTime.now().microsecondsSinceEpoch}_$_requestCounter';
  }
}

class _PrefetchKey {
  const _PrefetchKey({
    required this.text,
    required this.voiceId,
    required this.speed,
  });

  final String text;
  final String? voiceId;
  final double speed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PrefetchKey &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          voiceId == other.voiceId &&
          speed == other.speed;

  @override
  int get hashCode => Object.hash(text, voiceId, speed);
}

class _PrefetchedSentence {
  const _PrefetchedSentence({
    required this.key,
    required this.result,
    required this.elapsedMs,
  });

  final _PrefetchKey key;
  final SynthesisResult result;
  final int elapsedMs;
}

class _PrefetchTask {
  const _PrefetchTask({
    required this.key,
    required this.token,
    required this.future,
  });

  final _PrefetchKey key;
  final int token;
  final Future<_PrefetchedSentence?> future;
}

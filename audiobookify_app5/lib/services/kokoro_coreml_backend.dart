import 'dart:async';

import 'package:kokoro_flutter/kokoro_coreml.dart';
import 'package:kokoro_flutter/open_tts.dart';

import '../models/player_settings.dart';
import 'open_tts_renderer_support.dart';
import 'soloud_sentence_renderer.dart';
import 'speech_backend.dart';
import 'tts_debug_logging.dart';

class KokoroCoreMlBackend
    implements SpeechBackend, SentencePrefetchingSpeechBackend {
  KokoroCoreMlBackend({KokoroCoreMl? coreMl, OpenTtsAudioRenderer? renderer})
    : _coreMl = coreMl ?? KokoroCoreMl(),
      _renderer = renderer ?? SoLoudSentenceRenderer() {
    if (_renderer case final ManagedOpenTtsAudioRenderer managedRenderer) {
      managedRenderer.onPlaybackStart = _handlePlaybackStarted;
    }
  }

  final KokoroCoreMl _coreMl;
  final OpenTtsAudioRenderer _renderer;
  final StreamController<SpeechBackendEvent> _events =
      StreamController<SpeechBackendEvent>.broadcast();

  bool _initialized = false;
  Future<void>? _initializeFuture;
  PlayerSettings _currentSettings = const PlayerSettings(
    backend: SpeechBackendKind.coreMlKokoro,
  );
  _PrefetchedSentence? _prefetchedSentence;
  _PrefetchTask? _prefetchTask;
  _PrefetchKey? _scheduledPrefetchKey;
  int _prefetchToken = 0;
  int _requestCounter = 0;
  bool _speakInProgress = false;

  @override
  SpeechBackendKind get backendId => SpeechBackendKind.coreMlKokoro;

  @override
  String get displayName => 'Kokoro CoreML';

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
    logTtsDebug('Initializing Kokoro CoreML backend', category: 'tts.coreml');
    await _coreMl.initializeCoreMl();
    await _coreMl.warmupCoreMl();
    _initialized = true;
    logTtsDebug('Kokoro CoreML backend initialized', category: 'tts.coreml');
  }

  @override
  Future<List<SpeechVoiceOption>> listVoices() async {
    await initialize();
    final mapped =
        (await _coreMl.listCoreMlVoices())
            .map(
              (voice) => SpeechVoiceOption(
                backend: backendId,
                id: voice.id,
                label: voice.name,
                languageCode: voice.languageCode,
                localeLabel: voice.localeLabel,
                gender: voice.gender,
              ),
            )
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));
    logTtsDebug(
      'Kokoro CoreML listed ${mapped.length} voices',
      category: 'tts.coreml',
    );
    return mapped;
  }

  @override
  Future<void> applySettings(PlayerSettings settings) async {
    await initialize();
    clearPrefetch();
    _currentSettings = settings;
    logTtsDebug(
      'Kokoro CoreML applySettings voiceId=${settings.voiceId ?? "default"} speed=${settings.speed}',
      category: 'tts.coreml',
    );
    if (settings.voiceId != null) {
      await _coreMl.selectCoreMlVoice(settings.voiceId!);
    }
  }

  @override
  Future<void> speak(String text) async {
    _speakInProgress = true;
    await initialize();
    try {
      logTtsDebug('Kokoro CoreML speak "$text"', category: 'tts.coreml');
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
          'Kokoro CoreML prefetch hit requestId=$requestId textLength=${text.length} prefetchedMs=${prefetched.elapsedMs}',
          category: 'tts.coreml',
        );
        _logDiagnostics(
          prefetched.result,
          requestId: requestId,
          prefetched: true,
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
        'Kokoro CoreML prefetch miss textLength=${text.length}',
        category: 'tts.coreml',
      );
      final requestId = _nextRequestId();
      _events.add(const SpeechBackendEvent(type: SpeechBackendEventType.start));
      final stopwatch = Stopwatch()..start();
      final result = await _coreMl.synthesizeCoreMl(
        text,
        voiceId: _currentSettings.voiceId,
        speed: _currentSettings.speed,
      );
      stopwatch.stop();
      logTtsDebug(
        'Kokoro CoreML synth completed requestId=$requestId textLength=${text.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
        category: 'tts.coreml',
      );
      _logDiagnostics(result, requestId: requestId, prefetched: false);
      await _renderer.play(
        result.audio,
        result.sampleRate,
        requestId: requestId,
      );
      _events.add(
        const SpeechBackendEvent(type: SpeechBackendEventType.complete),
      );
    } finally {
      _speakInProgress = false;
    }
  }

  void _logDiagnostics(
    KokoroCoreMlAudioResult result, {
    required String requestId,
    required bool prefetched,
  }) {
    final diagnostics = result.diagnostics;
    if (diagnostics == null) {
      return;
    }
    logTtsDebug(
      'Kokoro CoreML diagnostics requestId=$requestId '
      'prefetched=$prefetched '
      'voiceId=${result.voiceId} '
      'totalMs=${diagnostics.timings.totalMs} '
      'g2pMs=${diagnostics.timings.g2PMs} '
      'vocabMs=${diagnostics.timings.vocabMs} '
      'pipelineMs=${diagnostics.timings.pipelineMs} '
      'bertMs=${diagnostics.timings.bertMs} '
      'durationMs=${diagnostics.timings.durationMs} '
      'alignBuildMs=${diagnostics.timings.alignmentBuildMs} '
      'alignGatherMs=${diagnostics.timings.alignmentGatherMs} '
      'pitchEnergyMs=${diagnostics.timings.pitchEnergyMs} '
      'textEncoderMs=${diagnostics.timings.textEncoderMs} '
      'decoderMs=${diagnostics.timings.decoderMs}',
      category: 'tts.coreml',
    );
  }

  @override
  Future<void> prefetch(String text) async {
    await initialize();
    final _PrefetchKey key = _prefetchKeyFor(text);
    if (_prefetchedSentence?.key == key) {
      logTtsDebug(
        'Kokoro CoreML prefetch requested for cached textLength=${text.length}',
        category: 'tts.coreml',
      );
      return;
    }
    if (_prefetchTask?.key == key) {
      logTtsDebug(
        'Kokoro CoreML prefetch already in flight textLength=${text.length}',
        category: 'tts.coreml',
      );
      return;
    }

    _scheduledPrefetchKey = key;
    logTtsDebug(
      'Kokoro CoreML prefetch scheduled textLength=${text.length}',
      category: 'tts.coreml',
    );

    final bool supportsDeferredPrefetch =
        _renderer is ManagedOpenTtsAudioRenderer;
    if (!_speakInProgress || !supportsDeferredPrefetch) {
      unawaited(_startScheduledPrefetchIfAny());
    }
  }

  @override
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
      logTtsDebug('Kokoro CoreML prefetch cleared', category: 'tts.coreml');
    }
  }

  @override
  Future<void> pause() async {
    await stop();
  }

  @override
  Future<void> stop() async {
    clearPrefetch();
    logTtsDebug('Kokoro CoreML stop', category: 'tts.coreml');
    await _renderer.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    if (_renderer case final ManagedOpenTtsAudioRenderer managedRenderer) {
      await managedRenderer.dispose();
    }
    await _events.close();
  }

  void _handlePlaybackStarted(String requestId) {
    logTtsDebug(
      'Kokoro CoreML playback started requestId=$requestId',
      category: 'tts.coreml',
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
      'Kokoro CoreML prefetch starting textLength=${key.text.length}',
      category: 'tts.coreml',
    );
    final future = _synthesizePrefetchedSentence(key, token, stopwatch);
    _prefetchTask = _PrefetchTask(key: key, token: token, future: future);
    unawaited(future);
  }

  Future<_PrefetchedSentence?> _synthesizePrefetchedSentence(
    _PrefetchKey key,
    int token,
    Stopwatch stopwatch,
  ) async {
    try {
      final result = await _coreMl.synthesizeCoreMl(
        key.text,
        voiceId: key.voiceId,
        speed: key.speed,
      );
      stopwatch.stop();
      if (token != _prefetchToken) {
        logTtsDebug(
          'Kokoro CoreML prefetch stale discard textLength=${key.text.length}',
          category: 'tts.coreml',
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
        'Kokoro CoreML prefetch completed textLength=${key.text.length} elapsedMs=${prefetched.elapsedMs}',
        category: 'tts.coreml',
      );
      return prefetched;
    } on Object catch (error, stackTrace) {
      stopwatch.stop();
      if (_prefetchTask?.token == token) {
        _prefetchTask = null;
      }
      logTtsDebug(
        'Kokoro CoreML prefetch failed textLength=${key.text.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
        category: 'tts.coreml',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<_PrefetchedSentence?> _takePrefetchedSentence(_PrefetchKey key) async {
    final cached = _prefetchedSentence;
    if (cached != null) {
      if (cached.key == key) {
        _prefetchedSentence = null;
        return cached;
      }
      logTtsDebug(
        'Kokoro CoreML prefetch stale cache discarded textLength=${cached.key.text.length}',
        category: 'tts.coreml',
      );
      _prefetchedSentence = null;
    }

    final task = _prefetchTask;
    if (task != null && task.key == key) {
      logTtsDebug(
        'Kokoro CoreML awaiting in-flight prefetch textLength=${key.text.length}',
        category: 'tts.coreml',
      );
      final prefetched = await task.future;
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
    return 'coreml_${DateTime.now().microsecondsSinceEpoch}_$_requestCounter';
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
  final KokoroCoreMlAudioResult result;
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

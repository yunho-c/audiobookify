import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

import 'open_tts_renderer_support.dart';
import 'tts_debug_logging.dart';

class SoLoudSentenceRenderer implements ManagedOpenTtsAudioRenderer {
  SoLoudSentenceRenderer({SoLoudDriver? driver})
    : _driver = driver ?? _RealSoLoudDriver();

  final SoLoudDriver _driver;

  @override
  void Function(String requestId)? onPlaybackStart;

  @override
  void Function(String requestId)? onPlaybackComplete;

  bool _initialized = false;
  Future<void>? _initializeFuture;
  _ActiveSoLoudPlayback? _currentPlayback;

  @override
  Future<void> play(
    Float32List audio,
    int sampleRate, {
    required String requestId,
  }) async {
    final totalStopwatch = Stopwatch()..start();
    await stop(requestId: requestId);
    await _ensureInitialized();

    final bufferPrepareStopwatch = Stopwatch()..start();
    final SoLoudStreamSource source = _driver.createBufferStream(
      maxBufferSizeBytes: audio.lengthInBytes,
      bufferingType: BufferingType.released,
      sampleRate: sampleRate,
      channels: Channels.mono,
      format: BufferType.f32le,
    );
    final Uint8List audioBytes = audio.buffer.asUint8List(
      audio.offsetInBytes,
      audio.lengthInBytes,
    );
    _driver.addAudioDataStream(source, audioBytes);
    _driver.setDataIsEnded(source);
    bufferPrepareStopwatch.stop();

    final double audioDurationMs = (audio.length / sampleRate) * 1000.0;
    logTtsDebug(
      'SoLoud renderer prepared requestId=$requestId '
      'samples=${audio.length} sampleRate=$sampleRate '
      'audioDurationMs=${audioDurationMs.toStringAsFixed(1)} '
      'bufferPrepareMs=${bufferPrepareStopwatch.elapsedMilliseconds}',
      category: 'tts.renderer',
    );

    final playback = _ActiveSoLoudPlayback(requestId: requestId, source: source);
    _currentPlayback = playback;
    playback.eventsSubscription = _driver.soundEvents(source).listen((event) {
      final handle = playback.handle;
      if (event.type == SoLoudStreamEventType.sourceDisposed) {
        playback.complete();
        return;
      }
      if (handle != null &&
          event.type == SoLoudStreamEventType.handleIsNoMoreValid &&
          event.handle == handle) {
        playback.complete();
      }
    });

    try {
      final playStartStopwatch = Stopwatch()..start();
      final SoLoudPlaybackHandle handle = await _driver.play(source);
      playback.handle = handle;
      if (playback.released || playback.stopped) {
        try {
          await _driver.stop(handle);
        } on Object {
          // Best-effort cleanup if playback was stopped while waiting for play().
        }
        return;
      }
      playStartStopwatch.stop();
      logTtsDebug(
        'SoLoud renderer starting playback requestId=$requestId playStartMs=${playStartStopwatch.elapsedMilliseconds}',
        category: 'tts.renderer',
      );
      onPlaybackStart?.call(requestId);

      final playbackStopwatch = Stopwatch()..start();
      await playback.completion.future;
      playbackStopwatch.stop();
      if (!playback.stopped) {
        onPlaybackComplete?.call(requestId);
      }
      totalStopwatch.stop();
      logTtsDebug(
        'SoLoud renderer completed playback requestId=$requestId '
        'playbackMs=${playbackStopwatch.elapsedMilliseconds} '
        'totalRendererMs=${totalStopwatch.elapsedMilliseconds}',
        category: 'tts.renderer',
      );
    } on Object catch (error, stackTrace) {
      totalStopwatch.stop();
      logTtsDebug(
        'SoLoud renderer playback failed requestId=$requestId totalRendererMs=${totalStopwatch.elapsedMilliseconds}',
        category: 'tts.renderer',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      await _releasePlayback(playback, stopHandle: false);
    }
  }

  @override
  Future<void> stop({String? requestId}) async {
    final playback = _currentPlayback;
    if (playback == null) {
      return;
    }
    playback.stopped = true;
    logTtsDebug(
      'SoLoud renderer stop requestId=${requestId ?? playback.requestId}',
      category: 'tts.renderer',
    );
    await _releasePlayback(playback, stopHandle: true);
  }

  @override
  Future<void> pause() async {
    final playback = _currentPlayback;
    final handle = playback?.handle;
    if (handle == null) {
      return;
    }
    _driver.setPause(handle, true);
  }

  @override
  Future<void> resume() async {
    final playback = _currentPlayback;
    final handle = playback?.handle;
    if (handle == null) {
      return;
    }
    _driver.setPause(handle, false);
  }

  @override
  Future<void> dispose() async {
    await stop();
    if (_initialized) {
      _driver.deinit();
      _initialized = false;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
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
    final stopwatch = Stopwatch()..start();
    if (!_driver.isInitialized) {
      await _driver.init();
    }
    stopwatch.stop();
    _initialized = true;
    logTtsDebug(
      'SoLoud renderer initialized initMs=${stopwatch.elapsedMilliseconds}',
      category: 'tts.renderer',
    );
  }

  Future<void> _releasePlayback(
    _ActiveSoLoudPlayback playback, {
    required bool stopHandle,
  }) async {
    if (playback.released) {
      return;
    }
    playback.released = true;
    if (identical(_currentPlayback, playback)) {
      _currentPlayback = null;
    }

    final handle = playback.handle;
    if (stopHandle && handle != null) {
      await _driver.stop(handle);
    }
    if (stopHandle) {
      playback.complete();
    }

    await playback.eventsSubscription?.cancel();
    await _driver.disposeSource(playback.source);
  }
}

class _ActiveSoLoudPlayback {
  _ActiveSoLoudPlayback({required this.requestId, required this.source});

  final String requestId;
  final SoLoudStreamSource source;
  final Completer<void> completion = Completer<void>();
  SoLoudPlaybackHandle? handle;
  StreamSubscription<SoLoudStreamEvent>? eventsSubscription;
  bool stopped = false;
  bool released = false;

  void complete() {
    if (!completion.isCompleted) {
      completion.complete();
    }
  }
}

abstract interface class SoLoudDriver {
  bool get isInitialized;

  Future<void> init();

  void deinit();

  SoLoudStreamSource createBufferStream({
    required int maxBufferSizeBytes,
    required BufferingType bufferingType,
    required int sampleRate,
    required Channels channels,
    required BufferType format,
  });

  void addAudioDataStream(SoLoudStreamSource source, Uint8List audioChunk);

  void setDataIsEnded(SoLoudStreamSource source);

  Stream<SoLoudStreamEvent> soundEvents(SoLoudStreamSource source);

  Future<SoLoudPlaybackHandle> play(SoLoudStreamSource source);

  void setPause(SoLoudPlaybackHandle handle, bool paused);

  Future<void> stop(SoLoudPlaybackHandle handle);

  Future<void> disposeSource(SoLoudStreamSource source);
}

class SoLoudStreamSource {
  const SoLoudStreamSource(this.inner);

  final Object inner;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoLoudStreamSource && other.inner == inner;

  @override
  int get hashCode => inner.hashCode;
}

class SoLoudPlaybackHandle {
  const SoLoudPlaybackHandle(this.inner);

  final int inner;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoLoudPlaybackHandle && other.inner == inner;

  @override
  int get hashCode => inner.hashCode;
}

enum SoLoudStreamEventType { handleIsNoMoreValid, sourceDisposed }

class SoLoudStreamEvent {
  const SoLoudStreamEvent({
    required this.type,
    required this.source,
    required this.handle,
  });

  final SoLoudStreamEventType type;
  final SoLoudStreamSource source;
  final SoLoudPlaybackHandle handle;
}

class _RealSoLoudDriver implements SoLoudDriver {
  @override
  bool get isInitialized => SoLoud.instance.isInitialized;

  @override
  Future<void> init() => SoLoud.instance.init();

  @override
  void deinit() => SoLoud.instance.deinit();

  @override
  SoLoudStreamSource createBufferStream({
    required int maxBufferSizeBytes,
    required BufferingType bufferingType,
    required int sampleRate,
    required Channels channels,
    required BufferType format,
  }) {
    final source = SoLoud.instance.setBufferStream(
      maxBufferSizeBytes: maxBufferSizeBytes,
      bufferingType: bufferingType,
      sampleRate: sampleRate,
      channels: channels,
      format: format,
    );
    return SoLoudStreamSource(source);
  }

  @override
  void addAudioDataStream(SoLoudStreamSource source, Uint8List audioChunk) {
    SoLoud.instance.addAudioDataStream(source.inner as AudioSource, audioChunk);
  }

  @override
  void setDataIsEnded(SoLoudStreamSource source) {
    SoLoud.instance.setDataIsEnded(source.inner as AudioSource);
  }

  @override
  Stream<SoLoudStreamEvent> soundEvents(SoLoudStreamSource source) {
    return (source.inner as AudioSource).soundEvents.map(
      (event) => SoLoudStreamEvent(
        type: switch (event.event) {
          SoundEventType.handleIsNoMoreValid =>
            SoLoudStreamEventType.handleIsNoMoreValid,
          SoundEventType.soundDisposed => SoLoudStreamEventType.sourceDisposed,
        },
        source: source,
        handle: SoLoudPlaybackHandle(event.handle.id),
      ),
    );
  }

  @override
  Future<SoLoudPlaybackHandle> play(SoLoudStreamSource source) async {
    final handle = await SoLoud.instance.play(source.inner as AudioSource);
    return SoLoudPlaybackHandle(handle.id);
  }

  @override
  void setPause(SoLoudPlaybackHandle handle, bool paused) {
    SoLoud.instance.setPause(SoundHandle(handle.inner), paused);
  }

  @override
  Future<void> stop(SoLoudPlaybackHandle handle) {
    return SoLoud.instance.stop(SoundHandle(handle.inner));
  }

  @override
  Future<void> disposeSource(SoLoudStreamSource source) {
    return SoLoud.instance.disposeSource(source.inner as AudioSource);
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:audiobookify/services/soloud_sentence_renderer.dart';

void main() {
  test('SoLoudSentenceRenderer play starts and completes once', () async {
    final driver = _FakeSoLoudDriver();
    addTearDown(driver.dispose);
    final renderer = SoLoudSentenceRenderer(driver: driver);
    var starts = 0;
    var completes = 0;
    renderer.onPlaybackStart = (_) => starts += 1;
    renderer.onPlaybackComplete = (_) => completes += 1;

    await renderer.play(
      Float32List.fromList(const <double>[0.1, -0.1, 0.2]),
      24000,
      requestId: 'req_1',
    );

    expect(driver.initCalls, 1);
    expect(driver.playCalls, 1);
    expect(driver.disposeSourceCalls, 1);
    expect(starts, 1);
    expect(completes, 1);
  });

  test('SoLoudSentenceRenderer stop interrupts active playback', () async {
    final driver = _FakeSoLoudDriver(autoCompletePlayback: false);
    addTearDown(driver.dispose);
    final renderer = SoLoudSentenceRenderer(driver: driver);

    final playFuture = renderer.play(
      Float32List.fromList(const <double>[0.1, -0.1, 0.2]),
      24000,
      requestId: 'req_2',
    );
    await driver.awaitPlayStarted();
    await Future<void>.delayed(Duration.zero);
    await renderer.stop(requestId: 'req_2');
    await playFuture;

    expect(driver.stopCalls, 1);
    expect(driver.disposeSourceCalls, 1);
  });

  test('SoLoudSentenceRenderer pause and resume control the active handle', () async {
    final driver = _FakeSoLoudDriver(autoCompletePlayback: false);
    addTearDown(driver.dispose);
    final renderer = SoLoudSentenceRenderer(driver: driver);

    final playFuture = renderer.play(
      Float32List.fromList(const <double>[0.1, -0.1, 0.2]),
      24000,
      requestId: 'req_3',
    );
    await driver.awaitPlayStarted();
    await Future<void>.delayed(Duration.zero);

    await renderer.pause();
    await renderer.resume();
    await renderer.stop(requestId: 'req_3');
    await playFuture;

    expect(driver.pauseStates, <bool>[true, false]);
  });
}

class _FakeSoLoudDriver implements SoLoudDriver {
  _FakeSoLoudDriver({this.autoCompletePlayback = true});

  final bool autoCompletePlayback;
  final StreamController<SoLoudStreamEvent> _events =
      StreamController<SoLoudStreamEvent>.broadcast();
  final Completer<void> _playStarted = Completer<void>();

  bool _initialized = false;
  int _sourceId = 0;
  int _handleId = 0;

  int initCalls = 0;
  int playCalls = 0;
  int stopCalls = 0;
  int disposeSourceCalls = 0;
  final List<bool> pauseStates = <bool>[];
  SoLoudStreamSource? _lastSource;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> init() async {
    initCalls += 1;
    _initialized = true;
  }

  @override
  void deinit() {
    _initialized = false;
  }

  @override
  SoLoudStreamSource createBufferStream({
    required int maxBufferSizeBytes,
    required BufferingType bufferingType,
    required int sampleRate,
    required Channels channels,
    required BufferType format,
  }) {
    _sourceId += 1;
    final source = SoLoudStreamSource(_sourceId);
    _lastSource = source;
    return source;
  }

  @override
  void addAudioDataStream(SoLoudStreamSource source, Uint8List audioChunk) {}

  @override
  void setDataIsEnded(SoLoudStreamSource source) {}

  @override
  Stream<SoLoudStreamEvent> soundEvents(SoLoudStreamSource source) =>
      _events.stream.where((event) => event.source == source);

  @override
  Future<SoLoudPlaybackHandle> play(SoLoudStreamSource source) async {
    playCalls += 1;
    _handleId += 1;
    final handle = SoLoudPlaybackHandle(_handleId);
    if (!_playStarted.isCompleted) {
      _playStarted.complete();
    }
    if (autoCompletePlayback) {
      scheduleMicrotask(() {
        _events.add(
          SoLoudStreamEvent(
            type: SoLoudStreamEventType.handleIsNoMoreValid,
            source: source,
            handle: handle,
          ),
        );
      });
    }
    return handle;
  }

  @override
  void setPause(SoLoudPlaybackHandle handle, bool paused) {
    pauseStates.add(paused);
  }

  @override
  Future<void> stop(SoLoudPlaybackHandle handle) async {
    stopCalls += 1;
    final source = _lastSource ?? const SoLoudStreamSource(-1);
    _events.add(
      SoLoudStreamEvent(
        type: SoLoudStreamEventType.handleIsNoMoreValid,
        source: source,
        handle: handle,
      ),
    );
  }

  @override
  Future<void> disposeSource(SoLoudStreamSource source) async {
    disposeSourceCalls += 1;
    _events.add(
      SoLoudStreamEvent(
        type: SoLoudStreamEventType.sourceDisposed,
        source: source,
        handle: const SoLoudPlaybackHandle(-1),
      ),
    );
  }

  Future<void> awaitPlayStarted() => _playStarted.future;

  Future<void> dispose() async {
    await _events.close();
  }
}

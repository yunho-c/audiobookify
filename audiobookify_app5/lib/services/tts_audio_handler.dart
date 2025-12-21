import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'tts_service.dart';

class TtsAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final TtsService _ttsService;
  AudioSession? _session;
  bool _sessionActive = false;
  bool _resumeAfterInterruption = false;
  late final void Function() _removeListener;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _noisySub;

  VoidCallback? onSkipNext;
  VoidCallback? onSkipPrevious;

  TtsAudioHandler(this._ttsService) {
    _removeListener =
        _ttsService.addListener(_handleTtsState, fireImmediately: true);
    _initSession();
  }

  Future<void> _initSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    _session = session;

    _interruptionSub = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        _resumeAfterInterruption =
            _ttsService.state.status == TtsStatus.playing;
        pause();
        return;
      }
      if (_resumeAfterInterruption) {
        _resumeAfterInterruption = false;
        play();
      }
    });
    _noisySub = session.becomingNoisyEventStream.listen((_) {
      pause();
    });
  }

  void _handleTtsState(TtsPlaybackState state) {
    final playing = state.status == TtsStatus.playing;
    final processingState = state.status == TtsStatus.stopped
        ? AudioProcessingState.idle
        : AudioProcessingState.ready;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState,
        playing: playing,
      ),
    );

    unawaited(_setSessionActive(playing));
  }

  Future<void> _setSessionActive(bool active) async {
    final session = _session;
    if (session == null || _sessionActive == active) return;
    _sessionActive = active;
    await session.setActive(active);
  }

  Future<void> _disposeResources() async {
    _removeListener();
    await _interruptionSub?.cancel();
    await _noisySub?.cancel();
    await _setSessionActive(false);
  }

  void updateNowPlaying({
    required String id,
    required String title,
    String? artist,
    String? album,
    Uri? artUri,
  }) {
    mediaItem.add(
      MediaItem(
        id: id,
        title: title,
        artist: artist,
        album: album,
        artUri: artUri,
      ),
    );
  }

  @override
  Future<void> play() async {
    await _setSessionActive(true);
    await _ttsService.play();
  }

  @override
  Future<void> pause() async {
    await _ttsService.pause();
    await _setSessionActive(false);
  }

  @override
  Future<void> stop() async {
    await _ttsService.stop();
    await _setSessionActive(false);
    return super.stop();
  }

  @override
  Future<void> skipToNext() async {
    onSkipNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipPrevious?.call();
  }

  @override
  Future<void> onNotificationDeleted() async {
    await _disposeResources();
    return super.onNotificationDeleted();
  }

  @override
  Future<void> onTaskRemoved() async {
    await _disposeResources();
    return super.onTaskRemoved();
  }
}

import 'dart:async';

import 'package:state_notifier/state_notifier.dart';

import '../core/error_reporter.dart';
import '../models/player_settings.dart';
import 'speech_backend.dart';
import 'system_flutter_tts_backend.dart';
import 'tts_debug_logging.dart';

enum TtsStatus { stopped, playing, paused }

const _unchanged = Object();

class TtsPlaybackState {
  final TtsStatus status;
  final int paragraphIndex, sentenceIndex;
  final List<String> paragraphs;
  final List<List<String>> sentencesPerParagraph;
  final SpeechBackendKind activeBackend;
  final bool isPreparing;
  final String? notice;

  const TtsPlaybackState({
    this.status = TtsStatus.stopped,
    this.paragraphIndex = 0,
    this.sentenceIndex = 0,
    this.paragraphs = const [],
    this.sentencesPerParagraph = const [],
    this.activeBackend = SpeechBackendKind.system,
    this.isPreparing = false,
    this.notice,
  });

  TtsPlaybackState copyWith({
    TtsStatus? status,
    int? paragraphIndex,
    int? sentenceIndex,
    List<String>? paragraphs,
    List<List<String>>? sentencesPerParagraph,
    SpeechBackendKind? activeBackend,
    bool? isPreparing,
    Object? notice = _unchanged,
  }) => TtsPlaybackState(
    status: status ?? this.status,
    paragraphIndex: paragraphIndex ?? this.paragraphIndex,
    sentenceIndex: sentenceIndex ?? this.sentenceIndex,
    paragraphs: paragraphs ?? this.paragraphs,
    sentencesPerParagraph: sentencesPerParagraph ?? this.sentencesPerParagraph,
    activeBackend: activeBackend ?? this.activeBackend,
    isPreparing: isPreparing ?? this.isPreparing,
    notice: identical(notice, _unchanged) ? this.notice : notice as String?,
  );

  List<String> get currentSentences =>
      paragraphIndex >= 0 && paragraphIndex < sentencesPerParagraph.length
      ? sentencesPerParagraph[paragraphIndex]
      : const [];
}

/// App sentence navigation. Each backend owns its synthesis and playback.
class TtsService extends StateNotifier<TtsPlaybackState> {
  TtsService({
    Iterable<SpeechBackend>? backends,
    PlayerSettings initialSettings = const PlayerSettings(),
  }) : _backends = {
         for (final backend in backends ?? [SystemFlutterTtsBackend()])
           backend.backendId: backend,
       },
       _settings = initialSettings,
       super(TtsPlaybackState(activeBackend: initialSettings.backend));

  final Map<SpeechBackendKind, SpeechBackend> _backends;
  final Set<SpeechBackendKind> _failedBackends = {};
  PlayerSettings _settings;
  String? _languageCode;
  int _generation = 0;
  bool _isDisposed = false;
  Future<void> _stopping = Future.value();
  Future<void> _configuring = Future.value();
  Future<void>? _closing;
  Function()? onComplete;

  List<SpeechBackendKind> get availableBackends => _backends.keys.toList();
  SpeechBackendKind get activeBackendKind => state.activeBackend;
  TtsPlaybackState get playbackState => state;

  SpeechBackendCapabilities capabilitiesFor(SpeechBackendKind backend) =>
      _backends[backend]?.capabilities ??
      const SpeechBackendCapabilities(
        supportsPitch: false,
        supportsVoiceSelection: false,
        supportsPause: false,
      );

  Future<List<SpeechVoiceOption>> listVoices({
    SpeechBackendKind? backend,
  }) async {
    final selected = _backends[backend ?? _settings.backend];
    if (selected == null) {
      throw StateError('This speech backend is unavailable');
    }
    // A failed voice list must not offer System IDs under the MLSR selector.
    return selected.listVoices();
  }

  void loadContent(
    List<String> paragraphs, {
    List<List<String>>? sentences,
    String? languageCode,
  }) {
    if (_isDisposed) return;
    ++_generation;
    unawaited(_stopBackends());
    _languageCode = languageCode;
    state = TtsPlaybackState(
      paragraphs: paragraphs,
      sentencesPerParagraph:
          sentences != null && sentences.length == paragraphs.length
          ? sentences
          : paragraphs.map(_splitIntoSentences).toList(),
      activeBackend: state.activeBackend,
    );
  }

  Future<void> play() async {
    if (_isDisposed ||
        state.paragraphs.isEmpty ||
        state.status == TtsStatus.playing) {
      return;
    }
    _failedBackends.clear();
    final generation = ++_generation;
    state = state.copyWith(
      status: TtsStatus.playing,
      isPreparing: true,
      notice: null,
    );
    await _start(generation);
  }

  /// Resume intentionally replays the current sentence, including for MLSR.
  Future<void> pause() async {
    if (_isDisposed) return;
    ++_generation;
    state = state.copyWith(status: TtsStatus.paused, isPreparing: false);
    await _stopBackends();
  }

  Future<void> stop() async {
    if (_isDisposed) return;
    ++_generation;
    state = state.copyWith(status: TtsStatus.stopped, isPreparing: false);
    await _stopBackends();
  }

  Future<void> jumpToParagraph(int index) => jumpToSentence(index, 0);

  Future<void> jumpToSentence(int paragraphIndex, int sentenceIndex) async {
    if (_isDisposed ||
        paragraphIndex < 0 ||
        paragraphIndex >= state.paragraphs.length) {
      return;
    }
    final wasPlaying = state.status == TtsStatus.playing;
    final generation = ++_generation;
    final sentences = state.sentencesPerParagraph[paragraphIndex];
    state = state.copyWith(
      paragraphIndex: paragraphIndex,
      sentenceIndex: sentences.isEmpty
          ? 0
          : sentenceIndex.clamp(0, sentences.length - 1),
      isPreparing: wasPlaying,
    );
    await _stopBackends();
    if (wasPlaying) await _start(generation);
  }

  Future<void> applySettings(PlayerSettings settings) async {
    if (_isDisposed || _settings == settings) return;
    _settings = settings;
    _failedBackends.clear();
    // Loading voices is lazy: opening the library never waits on a model.
    if (state.status != TtsStatus.playing) return;
    final generation = ++_generation;
    state = state.copyWith(isPreparing: true, notice: null);
    await _stopBackends();
    await _start(generation);
  }

  Future<void> retry() async {
    if (_isDisposed) return;
    _failedBackends.clear();
    final generation = ++_generation;
    state = state.copyWith(
      status: TtsStatus.playing,
      isPreparing: true,
      notice: null,
    );
    await _stopBackends();
    await _start(generation);
  }

  bool _current(int generation) => !_isDisposed && generation == _generation;

  Future<void> _start(int generation) async {
    await _stopping;
    if (_current(generation) && state.status == TtsStatus.playing) {
      unawaited(_run(generation));
    }
  }

  Future<void> _run(int generation) async {
    while (_current(generation) && state.status == TtsStatus.playing) {
      final sentence = _currentSentence();
      if (sentence == null) {
        _complete();
        return;
      }
      StreamSubscription<SpeechBackendEvent>? subscription;
      try {
        state = state.copyWith(isPreparing: true);
        final backend = await _configure(generation);
        if (backend == null || !_current(generation)) return;
        subscription = backend.events.listen((event) {
          if (_current(generation) &&
              event.type == SpeechBackendEventType.start) {
            state = state.copyWith(isPreparing: false);
          }
        });
        await backend.speak(sentence, languageCode: _languageCode);
      } catch (error, stackTrace) {
        if (!_current(generation)) return;
        _report(error, stackTrace, 'speak');
        state = state.copyWith(
          status: TtsStatus.stopped,
          isPreparing: false,
          notice:
              'Speech could not continue. Try again or choose another voice.',
        );
        return;
      } finally {
        await subscription?.cancel();
      }
      if (!_current(generation)) return;
      if (!_advanceAfterSentence()) {
        _complete();
        return;
      }
    }
  }

  void _complete() {
    state = state.copyWith(status: TtsStatus.stopped, isPreparing: false);
    onComplete?.call();
  }

  /// Serialize native settings, but let stop invalidate/cancel immediately.
  Future<SpeechBackend?> _configure(int generation) {
    final previous = _configuring;
    final operation = () async {
      await previous;
      if (!_current(generation)) return null;
      final settings = _settings;
      SpeechBackend? backend = _backends[settings.backend];
      if (backend != null && !_failedBackends.contains(settings.backend)) {
        try {
          await backend.initialize();
        } catch (error, stackTrace) {
          _report(error, stackTrace, 'initialize-${settings.backend.name}');
          if (!_current(generation)) return null;
          _failedBackends.add(settings.backend);
          backend = null;
        }
      } else {
        backend = null;
      }
      if (!_current(generation)) return null;
      if (backend == null) {
        backend = _backends[SpeechBackendKind.system];
        if (backend == null || settings.backend == SpeechBackendKind.system) {
          throw StateError('No speech backend is available');
        }
        state = state.copyWith(
          notice:
              '${settings.backend.label} is unavailable. Using System voice.',
        );
        await backend.initialize();
      }
      if (!_current(generation)) return null;
      await backend.applySettings(
        backend.backendId == settings.backend
            ? settings
            : settings.copyWith(backend: backend.backendId, voiceId: null),
      );
      if (!_current(generation)) return null;
      state = state.copyWith(activeBackend: backend.backendId);
      return backend;
    }();
    _configuring = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _stopBackends() {
    final previous = _stopping;
    // Stop every backend, including one still initializing or being replaced.
    final stops = _backends.values.map((backend) async {
      try {
        await backend.stop();
      } catch (error, stackTrace) {
        _report(error, stackTrace, 'stop');
      }
    }).toList();
    return _stopping = Future.wait<void>([previous, ...stops]).then((_) {});
  }

  String? _currentSentence() {
    while (state.paragraphIndex < state.sentencesPerParagraph.length) {
      final sentences = state.currentSentences;
      if (state.sentenceIndex < sentences.length) {
        return sentences[state.sentenceIndex];
      }
      if (!_advanceAfterSentence()) return null;
    }
    return null;
  }

  bool _advanceAfterSentence() {
    final next = state.sentenceIndex + 1;
    if (next < state.currentSentences.length) {
      state = state.copyWith(sentenceIndex: next);
      return true;
    }
    if (state.paragraphIndex + 1 >= state.paragraphs.length) return false;
    state = state.copyWith(
      paragraphIndex: state.paragraphIndex + 1,
      sentenceIndex: 0,
    );
    return true;
  }

  void _report(Object error, StackTrace stackTrace, String context) {
    logTtsDebug(
      'Speech failure: $context',
      category: 'tts.service',
      error: error,
      stackTrace: stackTrace,
    );
    reportError(error, stackTrace, context: 'tts:$context');
  }

  List<String> _splitIntoSentences(String text) {
    final boundary = RegExp(
      r'(?<!\b(?:Mr|Mrs|Ms|Dr|Prof|Sr|Jr|vs|etc|e\.g|i\.e))\s*[.!?]+\s+',
      caseSensitive: false,
    );
    final sentences = <String>[];
    var remaining = text.trim();
    while (remaining.isNotEmpty) {
      final match = boundary.firstMatch(remaining);
      if (match == null) {
        sentences.add(remaining);
        break;
      }
      sentences.add(remaining.substring(0, match.end).trim());
      remaining = remaining.substring(match.end).trim();
    }
    return sentences;
  }

  /// Deterministic shutdown for the app owner and native integration checks.
  Future<void> close() {
    dispose();
    return _closing!;
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    ++_generation;
    _closing = () async {
      await _stopBackends();
      await _configuring;
      await Future.wait(_backends.values.map((backend) => backend.dispose()));
    }();
    unawaited(
      _closing!.catchError((Object error, StackTrace stackTrace) {
        _report(error, stackTrace, 'dispose');
      }),
    );
    super.dispose();
  }
}

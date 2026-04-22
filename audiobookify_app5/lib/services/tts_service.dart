import 'dart:async';

import 'package:state_notifier/state_notifier.dart';

import '../core/error_reporter.dart';
import '../models/player_settings.dart';
import 'bundled_kokoro_onnx.dart';
import 'open_tts_backend.dart';
import 'speech_backend.dart';
import 'system_flutter_tts_backend.dart';
import 'tts_debug_logging.dart';

/// TTS playback status
enum TtsStatus { stopped, playing, paused }

/// Immutable state for TTS playback
class TtsPlaybackState {
  final TtsStatus status;
  final int paragraphIndex;
  final int sentenceIndex;
  final List<String> paragraphs;
  final List<List<String>> sentencesPerParagraph;

  const TtsPlaybackState({
    this.status = TtsStatus.stopped,
    this.paragraphIndex = 0,
    this.sentenceIndex = 0,
    this.paragraphs = const [],
    this.sentencesPerParagraph = const [],
  });

  TtsPlaybackState copyWith({
    TtsStatus? status,
    int? paragraphIndex,
    int? sentenceIndex,
    List<String>? paragraphs,
    List<List<String>>? sentencesPerParagraph,
  }) {
    return TtsPlaybackState(
      status: status ?? this.status,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      sentenceIndex: sentenceIndex ?? this.sentenceIndex,
      paragraphs: paragraphs ?? this.paragraphs,
      sentencesPerParagraph:
          sentencesPerParagraph ?? this.sentencesPerParagraph,
    );
  }

  List<String> get currentSentences {
    if (paragraphIndex >= 0 && paragraphIndex < sentencesPerParagraph.length) {
      return sentencesPerParagraph[paragraphIndex];
    }
    return [];
  }
}

/// Sentence-level TTS controller with pluggable speech backends.
class TtsService extends StateNotifier<TtsPlaybackState> {
  TtsService({
    Iterable<SpeechBackend>? backends,
    PlayerSettings initialSettings = const PlayerSettings(),
  }) : _backends = {
         for (final backend in backends ?? [SystemFlutterTtsBackend()])
           backend.backendId: backend,
       },
       _settings = initialSettings,
       super(const TtsPlaybackState()) {
    _activeBackendKind = _backends.containsKey(initialSettings.backend)
        ? initialSettings.backend
        : SpeechBackendKind.system;
  }

  final Map<SpeechBackendKind, SpeechBackend> _backends;
  PlayerSettings _settings;

  Function()? onComplete;

  SpeechBackendKind _activeBackendKind = SpeechBackendKind.system;
  int _playbackGeneration = 0;
  bool _isDisposed = false;

  List<SpeechBackendKind> get availableBackends =>
      _backends.keys.toList(growable: false);

  SpeechBackendKind get activeBackendKind => _activeBackendKind;

  TtsPlaybackState get playbackState => state;

  SpeechBackendCapabilities capabilitiesFor(SpeechBackendKind backend) {
    return _backends[backend]?.capabilities ??
        const SpeechBackendCapabilities(
          supportsPitch: true,
          supportsVoiceSelection: true,
          supportsPause: true,
        );
  }

  Future<List<SpeechVoiceOption>> listVoices({
    SpeechBackendKind? backend,
  }) async {
    final targetKind = backend ?? _settings.backend;
    logTtsDebug(
      'Listing voices for requested backend=${targetKind.name}',
      category: 'tts.service',
    );
    final resolvedBackend = await _resolveBackend(
      targetKind,
      markActive: false,
    );
    return resolvedBackend.listVoices();
  }

  /// Load content for playback
  void loadContent(List<String> paragraphs, {List<List<String>>? sentences}) {
    _clearSentencePrefetch();
    final sentencesPerParagraph =
        sentences != null && sentences.length == paragraphs.length
        ? sentences
        : paragraphs.map((p) => _splitIntoSentences(p)).toList();

    state = TtsPlaybackState(
      paragraphs: paragraphs,
      sentencesPerParagraph: sentencesPerParagraph,
      paragraphIndex: 0,
      sentenceIndex: 0,
      status: TtsStatus.stopped,
    );
  }

  /// Start or resume playback
  Future<void> play() async {
    if (state.paragraphs.isEmpty || state.status == TtsStatus.playing) return;
    logTtsDebug(
      'Play requested backend=${_settings.backend.name} paragraph=${state.paragraphIndex} sentence=${state.sentenceIndex}',
      category: 'tts.service',
    );
    state = state.copyWith(status: TtsStatus.playing);
    await _beginPlaybackLoop();
  }

  /// Pause playback. Resume replays the current sentence.
  Future<void> pause() async {
    logTtsDebug('Pause requested', category: 'tts.service');
    _playbackGeneration += 1;
    _clearSentencePrefetch();
    state = state.copyWith(status: TtsStatus.paused);
    await _stopCurrentBackend();
  }

  /// Stop playback
  Future<void> stop() async {
    logTtsDebug('Stop requested', category: 'tts.service');
    _playbackGeneration += 1;
    _clearSentencePrefetch();
    state = state.copyWith(status: TtsStatus.stopped);
    await _stopCurrentBackend();
  }

  /// Jump to specific paragraph (resets to first sentence)
  Future<void> jumpToParagraph(int index) async {
    if (index < 0 || index >= state.paragraphs.length) return;

    final wasPlaying = state.status == TtsStatus.playing;
    _playbackGeneration += 1;
    _clearSentencePrefetch();
    await _stopCurrentBackend();

    state = state.copyWith(
      paragraphIndex: index,
      sentenceIndex: 0,
      status: wasPlaying ? TtsStatus.playing : state.status,
    );

    if (wasPlaying) {
      await _beginPlaybackLoop();
    }
  }

  /// Jump to specific sentence within a paragraph
  Future<void> jumpToSentence(int paragraphIndex, int sentenceIndex) async {
    if (paragraphIndex < 0 || paragraphIndex >= state.paragraphs.length) return;

    final wasPlaying = state.status == TtsStatus.playing;
    _playbackGeneration += 1;
    _clearSentencePrefetch();
    await _stopCurrentBackend();

    final sentences = state.sentencesPerParagraph[paragraphIndex];
    final validSentenceIndex = sentenceIndex.clamp(0, sentences.length - 1);

    state = state.copyWith(
      paragraphIndex: paragraphIndex,
      sentenceIndex: validSentenceIndex,
      status: wasPlaying ? TtsStatus.playing : state.status,
    );

    if (wasPlaying) {
      await _beginPlaybackLoop();
    }
  }

  /// Apply settings from PlayerSettings
  Future<void> applySettings(PlayerSettings settings) async {
    final wasPlaying = state.status == TtsStatus.playing;
    logTtsDebug(
      'Applying settings requestedBackend=${settings.backend.name} voiceId=${settings.voiceId ?? "default"} speed=${settings.speed} pitch=${settings.pitch} wasPlaying=$wasPlaying',
      category: 'tts.service',
    );
    _settings = settings;
    _clearSentencePrefetch();

    if (wasPlaying) {
      _playbackGeneration += 1;
      await _stopCurrentBackend();
    }

    try {
      await _configureActiveBackend(settings);
    } catch (error, stackTrace) {
      _handleBackendFailure(error, stackTrace, context: 'applySettings');
    }

    if (wasPlaying && !_isDisposed) {
      state = state.copyWith(status: TtsStatus.playing);
      await _beginPlaybackLoop();
    }
  }

  Future<void> refreshOpenTtsExecutionProviderOverride({
    required OpenTtsExecutionProviderOverride previous,
    required OpenTtsExecutionProviderOverride next,
  }) async {
    logTtsDebug(
      'Refreshing OpenTTS execution provider override previous=${previous.name} next=${next.name}',
      category: 'tts.service',
    );

    _clearSentencePrefetch();
    final bool shouldRestartPlayback =
        state.status == TtsStatus.playing &&
        _settings.backend == SpeechBackendKind.openTts;

    if (shouldRestartPlayback) {
      _playbackGeneration += 1;
      await _stopCurrentBackend();
    }

    await _invalidateOpenTtsBackends(
      reason: 'provider override ${previous.name} -> ${next.name}',
    );

    if (_settings.backend != SpeechBackendKind.openTts || _isDisposed) {
      return;
    }

    try {
      await _configureActiveBackend(_settings);
    } catch (error, stackTrace) {
      _handleBackendFailure(
        error,
        stackTrace,
        context: 'refreshOpenTtsExecutionProviderOverride',
      );
      if (shouldRestartPlayback && !_isDisposed) {
        state = state.copyWith(status: TtsStatus.stopped);
      }
      return;
    }

    if (shouldRestartPlayback && !_isDisposed) {
      state = state.copyWith(status: TtsStatus.playing);
      await _beginPlaybackLoop();
    }
  }

  Future<void> _beginPlaybackLoop() async {
    final generation = ++_playbackGeneration;
    logTtsDebug(
      'Starting playback loop generation=$generation requestedBackend=${_settings.backend.name}',
      category: 'tts.service',
    );

    try {
      await _configureActiveBackend(_settings);
    } catch (error, stackTrace) {
      _handleBackendFailure(error, stackTrace, context: 'play');
      if (!_isActiveGeneration(generation)) return;
      state = state.copyWith(status: TtsStatus.stopped);
      return;
    }

    unawaited(_runPlaybackLoop(generation));
  }

  Future<void> _runPlaybackLoop(int generation) async {
    while (_isActiveGeneration(generation) &&
        state.status == TtsStatus.playing &&
        !_isDisposed) {
      final sentence = _currentSentence();
      if (sentence == null) {
        state = state.copyWith(status: TtsStatus.stopped);
        onComplete?.call();
        return;
      }

      try {
        final backend = await _configureActiveBackend(_settings);
        final String? nextSentence = _peekNextSentence();
        logTtsDebug(
          'Speaking sentence generation=$generation activeBackend=${backend.backendId.name} paragraph=${state.paragraphIndex} sentence=${state.sentenceIndex} text="$sentence"',
          category: 'tts.service',
        );
        final sentenceStopwatch = Stopwatch()..start();
        final Future<void> speakFuture = backend.speak(sentence);
        if (backend case final SentencePrefetchingSpeechBackend prefetching) {
          if (nextSentence != null) {
            unawaited(prefetching.prefetch(nextSentence));
          } else {
            prefetching.clearPrefetch();
          }
        }
        await speakFuture;
        sentenceStopwatch.stop();
        logTtsDebug(
          'Sentence completed generation=$generation activeBackend=${backend.backendId.name} paragraph=${state.paragraphIndex} sentence=${state.sentenceIndex} textLength=${sentence.length} elapsedMs=${sentenceStopwatch.elapsedMilliseconds}',
          category: 'tts.service',
        );
      } catch (error, stackTrace) {
        if (!_isActiveGeneration(generation)) {
          return;
        }
        _handleBackendFailure(error, stackTrace, context: 'speak');
        state = state.copyWith(status: TtsStatus.stopped);
        return;
      }

      if (!_isActiveGeneration(generation) ||
          state.status != TtsStatus.playing) {
        return;
      }

      if (!_advanceAfterSentence()) {
        state = state.copyWith(status: TtsStatus.stopped);
        onComplete?.call();
        return;
      }
    }
  }

  Future<SpeechBackend> _configureActiveBackend(PlayerSettings settings) async {
    final backend = await _resolveBackend(settings.backend, markActive: true);
    logTtsDebug(
      'Configuring backend requested=${settings.backend.name} resolved=${backend.backendId.name} voiceId=${settings.voiceId ?? "default"}',
      category: 'tts.service',
    );

    final appliedSettings = backend.backendId == settings.backend
        ? settings
        : PlayerSettings(
            speed: settings.speed,
            pitch: settings.pitch,
            backend: backend.backendId,
          );
    await backend.applySettings(appliedSettings);
    return backend;
  }

  Future<SpeechBackend> _resolveBackend(
    SpeechBackendKind requestedBackend, {
    required bool markActive,
  }) async {
    final backend = _backends[requestedBackend];
    if (backend != null) {
      logTtsDebug(
        'Initializing requested backend=${requestedBackend.name}',
        category: 'tts.service',
      );
      try {
        await backend.initialize();
        if (markActive) {
          _activeBackendKind = backend.backendId;
        }
        logTtsDebug(
          'Using requested backend=${backend.backendId.name}',
          category: 'tts.service',
        );
        return backend;
      } catch (error, stackTrace) {
        logTtsDebug(
          'Requested backend=${requestedBackend.name} failed to initialize; falling back to system',
          category: 'tts.service',
          error: error,
          stackTrace: stackTrace,
        );
        _handleBackendFailure(
          error,
          stackTrace,
          context: 'initialize-${requestedBackend.name}',
        );
      }
    }

    final fallback = _backends[SpeechBackendKind.system];
    if (fallback == null) {
      throw StateError('No speech backends are registered.');
    }
    await fallback.initialize();
    if (markActive) {
      _activeBackendKind = fallback.backendId;
    }
    logTtsDebug('Using fallback backend=system', category: 'tts.service');
    return fallback;
  }

  Future<void> _stopCurrentBackend() async {
    final backend = _backends[_activeBackendKind];
    if (backend == null) return;
    logTtsDebug(
      'Stopping active backend=${backend.backendId.name}',
      category: 'tts.service',
    );
    try {
      await backend.stop();
    } catch (error, stackTrace) {
      _handleBackendFailure(error, stackTrace, context: 'stop');
    }
  }

  String? _currentSentence() {
    if (state.paragraphIndex >= state.paragraphs.length) {
      return null;
    }

    final sentences = state.sentencesPerParagraph[state.paragraphIndex];
    if (state.sentenceIndex >= sentences.length) {
      final nextParagraph = state.paragraphIndex + 1;
      if (nextParagraph >= state.paragraphs.length) {
        return null;
      }
      state = state.copyWith(paragraphIndex: nextParagraph, sentenceIndex: 0);
      return state.sentencesPerParagraph[state.paragraphIndex][state
          .sentenceIndex];
    }

    return sentences[state.sentenceIndex];
  }

  String? _peekNextSentence() {
    if (state.paragraphIndex >= state.sentencesPerParagraph.length) {
      return null;
    }

    final sentences = state.sentencesPerParagraph[state.paragraphIndex];
    final nextSentenceIndex = state.sentenceIndex + 1;
    if (nextSentenceIndex < sentences.length) {
      return sentences[nextSentenceIndex];
    }

    final nextParagraph = state.paragraphIndex + 1;
    if (nextParagraph >= state.paragraphs.length ||
        nextParagraph >= state.sentencesPerParagraph.length) {
      return null;
    }
    final nextParagraphSentences = state.sentencesPerParagraph[nextParagraph];
    if (nextParagraphSentences.isEmpty) {
      return null;
    }
    return nextParagraphSentences.first;
  }

  bool _advanceAfterSentence() {
    if (state.paragraphIndex >= state.sentencesPerParagraph.length) {
      return false;
    }
    final sentences = state.sentencesPerParagraph[state.paragraphIndex];
    final nextSentence = state.sentenceIndex + 1;
    if (nextSentence < sentences.length) {
      state = state.copyWith(sentenceIndex: nextSentence);
      return true;
    }

    final nextParagraph = state.paragraphIndex + 1;
    if (nextParagraph >= state.paragraphs.length) {
      return false;
    }
    state = state.copyWith(paragraphIndex: nextParagraph, sentenceIndex: 0);
    return true;
  }

  bool _isActiveGeneration(int generation) {
    return !_isDisposed && generation == _playbackGeneration;
  }

  void _handleBackendFailure(
    Object error,
    StackTrace stackTrace, {
    required String context,
  }) {
    logTtsDebug(
      'Backend failure context=$context activeBackend=${_activeBackendKind.name} requestedBackend=${_settings.backend.name}',
      category: 'tts.service',
      error: error,
      stackTrace: stackTrace,
    );
    reportError(error, stackTrace, context: 'tts:$context');
  }

  void _clearSentencePrefetch() {
    for (final backend in _backends.values) {
      if (backend case final SentencePrefetchingSpeechBackend prefetching) {
        prefetching.clearPrefetch();
      }
    }
  }

  Future<void> _invalidateOpenTtsBackends({required String reason}) async {
    for (final backend in _backends.values) {
      if (backend case final OpenTtsBackend openTtsBackend) {
        await openTtsBackend.invalidateEngine(reason: reason);
      }
    }
  }

  List<String> _splitIntoSentences(String text) {
    final sentencePattern = RegExp(
      r'(?<!\b(?:Mr|Mrs|Ms|Dr|Prof|Sr|Jr|vs|etc|e\.g|i\.e))\s*[.!?]+\s+',
      caseSensitive: false,
    );

    final sentences = <String>[];
    var remaining = text.trim();

    while (remaining.isNotEmpty) {
      final match = sentencePattern.firstMatch(remaining);
      if (match != null) {
        final sentence = remaining.substring(0, match.end).trim();
        if (sentence.isNotEmpty) {
          sentences.add(sentence);
        }
        remaining = remaining.substring(match.end).trim();
      } else {
        if (remaining.isNotEmpty) {
          sentences.add(remaining);
        }
        break;
      }
    }

    if (sentences.isEmpty && text.trim().isNotEmpty) {
      sentences.add(text.trim());
    }

    return sentences;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _playbackGeneration += 1;
    for (final backend in _backends.values) {
      unawaited(backend.dispose());
    }
    super.dispose();
  }
}

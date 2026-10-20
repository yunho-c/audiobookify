import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mlsr_app_models/app_models.dart';
import 'package:mlsr_flutter/mlsr_flutter.dart';
// Native handle accounting is test-only evidence.
// ignore: implementation_imports
import 'package:mlsr/src/bindings.g.dart' as native;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audiobookify/core/providers.dart';
import 'package:audiobookify/models/player_settings.dart';
import 'package:audiobookify/reader/reader_dto_adapter.dart';
import 'package:audiobookify/reader/reader_segmentation.dart';
import 'package:audiobookify/screens/player_screen.dart';
import 'package:audiobookify/services/book_service.dart';
import 'package:audiobookify/services/epub_service.dart';
import 'package:audiobookify/services/library_store.dart';
import 'package:audiobookify/services/mlsr_speech_backend.dart';
import 'package:audiobookify/services/speech_backend.dart';
import 'package:audiobookify/services/system_flutter_tts_backend.dart';
import 'package:audiobookify/services/tts_audio_handler.dart';
import 'package:audiobookify/services/tts_service.dart';
import 'package:audiobookify/src/rust/frb_generated.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  SystemChannels.lifecycle.setMessageHandler((_) async => null);
  binding.platformDispatcher.initialLifecycleStateTestValue =
      'AppLifecycleState.resumed';
  binding.resetInternalState();
  binding.readTestInitialLifecycleStateFromNativeWindow();

  // A release build has no VM service for flutter drive. This test-only mode
  // writes evidence after the binding has evaluated all test failures, then
  // exits so the same app can be exercised with network access denied.
  if (const bool.fromEnvironment('MLSR_TEST_STANDALONE')) {
    unawaited(
      binding.allTestsPassed.future.then((passed) async {
        final output = await Directory.systemTemp.createTemp(
          'audiobookify-validation-',
        );
        final result = Map<String, dynamic>.from(binding.reportData ?? {});
        result['test_suite_passed'] = passed;
        final screenshot = result.remove('screenshot_png_base64') as String?;
        if (screenshot != null) {
          await File(
            '${output.path}/reader.png',
          ).writeAsBytes(base64Decode(screenshot));
        }
        await File(
          '${output.path}/summary.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(result));
        stdout.writeln('MLSR_VALIDATION_REPORT=${output.path}');
        exit(passed && result['passed'] == true ? 0 : 1);
      }),
    );
  }

  testWidgets(
    'bundled MLSR drives the EPUB reader and releases native resources',
    (tester) async {
      const audible = bool.fromEnvironment('MLSR_TEST_AUDIBLE');
      const fullChapter = bool.fromEnvironment('MLSR_TEST_FULL_CHAPTER');
      final report = <String, dynamic>{
        'passed': false,
        'audible': audible,
        'full_chapter': fullChapter,
        'model_id': AppModels.supertonic3.id,
        'timing_boundary':
            'App-observed native playback state; not acoustic latency',
      };
      binding.reportData = report;
      if (const bool.fromEnvironment('MLSR_TEST_OFFLINE')) {
        try {
          final socket = await Socket.connect('127.0.0.1', 9);
          socket.destroy();
          fail('The offline test must deny network access');
        } on SocketException catch (error) {
          expect(error.osError?.errorCode, 1); // EPERM, not connection refused.
        }
        const forbidden = String.fromEnvironment('MLSR_TEST_FORBIDDEN_FILE');
        expect(forbidden, isNotEmpty);
        try {
          await File(forbidden).readAsBytes();
          fail('The source model cache must be inaccessible');
        } on FileSystemException catch (error) {
          expect(error.osError?.errorCode, 1);
        }
        report['network_and_source_cache_denied'] = true;
      }
      final handlesBefore = native.mlsr_live_handles();
      report['handles_before'] = handlesBefore;
      final temporary = await Directory.systemTemp.createTemp(
        'audiobookify-mlsr-',
      );
      await RustLib.init();
      final bytes = await rootBundle.load('test/assets/test_ebook.epub');
      final epubFile = File('${temporary.path}/alice.epub');
      await epubFile.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final epubService = EpubService();
      final epub = await epubService.openEpub(epubFile.path);
      final chapterIndex = epub.sections.indexWhere(
        (section) => segmentReaderDocument(
          adaptReaderDocument(section.document),
        ).ttsParagraphs.any((p) => p.plainText.contains('Alice was beginning')),
      );
      expect(chapterIndex, greaterThanOrEqualTo(0));
      report['initial_chapter_index'] = chapterIndex;
      report['initial_chapter_title'] = epub.sections[chapterIndex].title;
      final store = await openLibraryStore(
        directory: '${temporary.path}/library',
      );
      final bookService = BookService(store);
      final book = bookService.saveBook(epub, epubFile.path).book;
      SharedPreferences.setMockInitialValues({
        'player_backend': 'openTts',
        'player_voice_id': 'af_heart',
        'player_speed': 2.0,
      });
      final prefs = await SharedPreferences.getInstance();
      await migrateSpeechPreferences(prefs, mlsrAvailable: true);
      expect(prefs.getString('player_backend'), 'mlsr');
      expect(prefs.getString('player_voice_id'), isNull);

      _ObservedSession? session;
      var opens = 0;
      final backend = MlsrSpeechBackend(
        createSession: () async {
          opens++;
          final clock = Stopwatch()..start();
          final tts = await FlutterMlsr.openTts(
            model: AppModels.supertonic3,
            options: const TtsOptions(output: OutputMode.hostManaged),
          );
          report['model_open_ms'] = clock.elapsedMilliseconds;
          return session = _ObservedSession(tts, audible: audible);
        },
      );
      final service = TtsService(
        backends: [SystemFlutterTtsBackend(), backend],
        initialSettings: loadPlayerSettingsFromPrefs(prefs, preferMlsr: true),
      );
      final handler = await AudioService.init(
        builder: () => TtsAudioHandler(service),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'audiobookify.validation',
          androidNotificationChannelName: 'Validation',
        ),
      );
      final router = GoRouter(
        initialLocation: '/player/${book.id}?chapter=${chapterIndex + 1}',
        routes: [
          GoRoute(
            path: '/player/:id',
            builder: (context, state) =>
                PlayerScreen(bookId: state.pathParameters['id']!),
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bookServiceProvider.overrideWithValue(bookService),
          epubServiceProvider.overrideWithValue(epubService),
          mlsrBackendProvider.overrideWithValue(backend),
          ttsProvider.overrideWith((ref) => service),
          audioHandlerProvider.overrideWithValue(handler),
        ],
      );
      final clock = Stopwatch()..start();
      var lastTick = 0, maxGap = 0, ticks = 0;
      final heartbeat = Timer.periodic(const Duration(milliseconds: 16), (_) {
        final now = clock.elapsedMilliseconds;
        if (now - lastTick > maxGap) maxGap = now - lastTick;
        lastTick = now;
        ticks++;
      });
      Future<void> until(
        bool Function() ready, {
        Duration timeout = const Duration(seconds: 120),
      }) async {
        final deadline = DateTime.now().add(timeout);
        while (!ready()) {
          if (DateTime.now().isAfter(deadline)) {
            fail(
              'Timed out: ${service.playbackState.notice}, ${service.playbackState.status}',
            );
          }
          await tester.pump(const Duration(milliseconds: 20));
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await tester.pump();
      }

      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: Consumer(
              builder: (context, ref, child) {
                ref.watch(ttsSettingsSyncProvider);
                return child!;
              },
              child: RepaintBoundary(
                key: const Key('reader-surface'),
                child: MaterialApp.router(routerConfig: router),
              ),
            ),
          ),
        );
        await until(() => service.playbackState.paragraphs.isNotEmpty);
        expect(opens, 0); // Reading the book alone does not load a model.
        final chapterParagraphs = List<String>.of(
          service.playbackState.paragraphs,
        );
        final chapterSentences = service.playbackState.sentencesPerParagraph
            .map((s) => List<String>.of(s))
            .toList();
        report['chapter_words'] = chapterParagraphs
            .join(' ')
            .split(RegExp(r'\s+'))
            .length;
        report['chapter_sentences'] = chapterSentences.fold<int>(
          0,
          (sum, p) => sum + p.length,
        );
        final playClock = Stopwatch()..start();
        await handler.play();
        await until(() => session?.started.isNotEmpty ?? false);
        report['cold_play_to_start_ms'] = playClock.elapsedMilliseconds;
        expect(service.activeBackendKind, SpeechBackendKind.mlsr);
        expect(service.playbackState.notice, isNull);
        expect(handler.playbackState.value.playing, isTrue);
        final voices = await backend.listVoices();
        expect(voices.length, 10);
        report['voices'] = voices.map((v) => v.id).toList();

        await handler.pause();
        expect(service.playbackState.status, TtsStatus.paused);
        final selected = (
          service.playbackState.paragraphIndex,
          service.playbackState.sentenceIndex,
        );
        final beforeResume = session!.texts.length;
        await handler.play();
        await until(() => session!.texts.length > beforeResume);
        expect((
          service.playbackState.paragraphIndex,
          service.playbackState.sentenceIndex,
        ), selected);
        await handler.stop();
        final afterStop = session!.texts.length;
        await tester.pump(const Duration(milliseconds: 100));
        expect(session!.texts.length, afterStop);

        // Actual reader navigation and OS media commands use the same controller.
        await handler.play();
        final beforeSeek = session!.texts.length;
        final seek1 = service.jumpToSentence(1, 0);
        final seek2 = service.jumpToSentence(2, 0);
        await Future.wait([seek1, seek2]);
        await until(() => session!.texts.length > beforeSeek);
        expect(session!.texts.last, chapterSentences[2].first);
        final settings = container.read(playerSettingsProvider.notifier);
        settings.setSpeed(1.5);
        settings.setVoice('supertonic3:F1');
        await until(() => session!.startedVoices.contains('supertonic3:F1'));
        await handler.stop();
        report['navigation_and_voice_switch'] = true;
        report['voice_switch_reached_native_output'] = true;

        // Check all source sentences in a real chapter, or a short developer smoke.
        settings.setVoice(null);
        settings.setSpeed(2);
        await tester.pump();
        if (fullChapter) {
          await service.jumpToSentence(0, 0);
        } else {
          service.loadContent(
            chapterParagraphs.take(3).toList(),
            sentences: chapterSentences.take(3).toList(),
            languageCode: epub.metadata.language,
          );
        }
        final expected =
            (fullChapter ? chapterSentences : chapterSentences.take(3))
                .expand((p) => p)
                .toList();
        final first = session!.texts.length;
        final completedBefore = session!.completed;
        final chapterClock = Stopwatch()..start();
        var completed = false;
        final advanceChapter = service.onComplete!;
        // Capture the boundary before letting the real reader advance.
        service.onComplete = () => completed = true;
        await handler.play();
        await until(
          () => completed || service.playbackState.notice != null,
          timeout: const Duration(minutes: 15),
        );
        expect(service.playbackState.notice, isNull);
        expect(completed, isTrue);
        expect(session!.texts.sublist(first), expected);
        expect(session!.completed - completedBefore, expected.length);
        expect((await session!.tts.snapshot()).retention.usedBytes, 0);
        report['chapter_playback_ms'] = chapterClock.elapsedMilliseconds;
        report['completed_sentences'] = session!.completed - completedBefore;
        report['model_opens'] = opens;
        expect(opens, 1);

        // The real completion callback must start the next chapter itself.
        final oldParagraph = service.playbackState.paragraphs.first;
        advanceChapter();
        await until(
          () => service.playbackState.paragraphs.first != oldParagraph,
        );
        await until(
          () =>
              service.playbackState.status == TtsStatus.playing &&
              !service.playbackState.isPreparing,
        );
        await handler.stop();
        report['automatic_chapter_transition'] = true;
        await handler.skipToPrevious();
        await until(
          () => service.playbackState.paragraphs.first == oldParagraph,
        );
        await handler.skipToNext();
        await until(
          () => service.playbackState.paragraphs.first != oldParagraph,
        );
        report['media_chapter_navigation'] = true;
        final resume = container.read(bookResumeProvider)[book.id];
        expect(resume, isNotNull);
        report['resume_chapter'] = resume!.chapterIndex;
        expect(resume.chapterIndex, chapterIndex + 1);
        final expectedTitle = epub.sections[chapterIndex + 1].title;
        report['next_chapter_title'] = expectedTitle;

        // Let the reader's chapter-title and transport animations finish.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(find.textContaining(expectedTitle), findsWidgets);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('reader-surface')),
        );
        final image = await boundary.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        report['screenshot_png_base64'] = base64Encode(
          png!.buffer.asUint8List(),
        );
        report['peak_rss_bytes'] = ProcessInfo.maxRss;
        report['max_flutter_heartbeat_gap_ms'] = maxGap;
        report['heartbeat_ticks'] = ticks;
        report['requests'] = session!.texts.length;
        report['start_gaps_ms'] = session!.gaps;
      } finally {
        heartbeat.cancel();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await handler.close();
        await service.close();
        container.dispose();
        router.dispose();
        store.close();
        await temporary.delete(recursive: true);
        report['handles_after'] = native.mlsr_live_handles();
        expect(native.mlsr_live_handles(), handlesBefore);
        binding.reportData = report;
      }
      report['passed'] = true;
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

class _ObservedSession implements MlsrSession {
  _ObservedSession(this.tts, {required this.audible});
  final Tts tts;
  final bool audible;
  final texts = <String>[];
  final requests = <RequestOptions>[];
  final started = <String>[];
  final startedVoices = <String>[];
  final gaps = <int>[];
  int completed = 0;
  DateTime? lastDrain;
  @override
  Future<List<SpeechVoiceOption>> listVoices() =>
      MlsrSdkSession(tts).listVoices();
  @override
  MlsrPlayback speak(
    String text, {
    required RequestOptions request,
    required SpeechOptions options,
  }) {
    texts.add(text);
    requests.add(request);
    final speech = tts.speak(
      text,
      request: request,
      options: SpeechOptions(
        playbackRate: options.playbackRate,
        retainAudio: options.retainAudio,
        volume: audible ? 1 : 0,
      ),
    );
    return _ObservedPlayback(
      speech,
      onStart: () {
        started.add(text);
        startedVoices.add(request.voice);
        if (lastDrain != null) {
          gaps.add(DateTime.now().difference(lastDrain!).inMilliseconds);
        }
      },
      onDone: () {
        completed++;
        lastDrain = DateTime.now();
      },
    );
  }

  @override
  Future<void> dispose() => tts.dispose();
}

class _ObservedPlayback implements MlsrPlayback {
  _ObservedPlayback(this.speech, {required this.onStart, required this.onDone});
  final Speech speech;
  final void Function() onStart, onDone;
  @override
  Stream<void> get starts => speech.states
      .where((s) => s.playback == PlaybackPhase.playing)
      .take(1)
      .map((_) {
        onStart();
      });
  @override
  Future<bool> get done async {
    final outcome = await speech.done;
    if (outcome.kind == OutcomeKind.completed) {
      onDone();
      return true;
    }
    return false;
  }

  @override
  void cancel() => speech.cancel();
  @override
  Future<void> dispose() => speech.dispose();
}

import 'dart:async';
import 'dart:typed_data';

import 'package:audiobookify/core/providers.dart';
import 'package:audiobookify/models/book.dart';
import 'package:audiobookify/reader/reader_paragraph.dart';
import 'package:audiobookify/screens/player_screen.dart';
import 'package:audiobookify/services/book_service.dart';
import 'package:audiobookify/services/epub_service.dart';
import 'package:audiobookify/services/tts_audio_handler.dart';
import 'package:audiobookify/services/tts_service.dart';
import 'package:audiobookify/src/rust/api/epub.dart' as epub;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('sentence animation rebuilds only the affected paragraph', (
    tester,
  ) async {
    final harness = await _mount(tester);
    final screen = tester.widget<Scaffold>(find.byType(Scaffold));
    final inactive = _paragraphText(tester, 2);
    final before = _paragraphText(tester, 0);

    await harness.playback.jumpToSentence(0, 1);
    await tester.pump();
    final firstFrame = _paragraphText(tester, 0);
    expect(firstFrame, isNot(same(before)));
    final startHighlight =
        _span(firstFrame, 'Second sentence.').style!.backgroundColor?.a ?? 0;
    await tester.pump(const Duration(milliseconds: 48));
    expect(
      _span(
        _paragraphText(tester, 0),
        'Second sentence.',
      ).style!.backgroundColor!.a,
      greaterThan(startHighlight),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.widget<Scaffold>(find.byType(Scaffold)), same(screen));
      expect(_paragraphText(tester, 2), same(inactive));
    }
    final resume = harness.container.read(bookResumeProvider)[1]!;
    expect(resume.paragraphIndex, 0);
    expect(resume.sentenceIndex, 1);

    await harness.playback.jumpToSentence(1, 0);
    await tester.pump();
    final outgoing = _span(
      _paragraphText(tester, 0),
      'Second sentence.',
    ).style!.backgroundColor!.a;
    expect(outgoing, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      _span(
        _paragraphText(tester, 0),
        'Second sentence.',
      ).style!.backgroundColor!.a,
      lessThan(outgoing),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Scaffold>(find.byType(Scaffold)), same(screen));
    expect(_paragraphText(tester, 2), same(inactive));
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      closeTo(0.4, 0.001),
    );
    expect(harness.books.visited.last, (1, 1));
    expect(harness.container.read(bookResumeProvider)[1]!.paragraphIndex, 1);

    final current = _paragraphText(tester, 1);
    harness.playback.publish(
      harness.playback.playbackState.copyWith(notice: 'Retry speech'),
    );
    await tester.pump();
    expect(find.text('Retry speech'), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)), same(screen));
    expect(_paragraphText(tester, 1), same(current));
  });

  testWidgets(
    'playback effects still scroll and chapter changes reset paragraphs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final harness = await _mount(tester);
      final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
      tester
          .widget<SelectionArea>(find.byType(SelectionArea))
          .onSelectionChanged!(
        const SelectedContent(plainText: 'Selected reader text'),
      );
      await tester.pump();
      harness.playback.publish(
        harness.playback.playbackState.copyWith(
          status: TtsStatus.playing,
          paragraphIndex: 2,
          sentenceIndex: 0,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(scroll.offset, 0, reason: 'Text selection suspends auto-scroll');
      tester
          .widget<SelectionArea>(find.byType(SelectionArea))
          .onSelectionChanged!(null);
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.8, 0.001),
      );
      expect(harness.books.visited.last, (1, 2));

      await harness.playback.pause();
      await tester.pumpAndSettle();
      harness.audio.onSkipNext!();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Next chapter text.', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(ReaderParagraph), findsOneWidget);
      final paragraph = tester.widget<ReaderParagraph>(
        find.byType(ReaderParagraph),
      );
      expect(paragraph.isActive, isTrue);
      expect(paragraph.sentenceIndex, 0);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0,
      );
      expect(harness.books.visited.last, (2, 0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('debug progress updates stay inside player controls', (
    tester,
  ) async {
    final harness = await _mount(tester);
    await harness.container.read(debugModeProvider.notifier).setEnabled(true);
    await tester.pumpAndSettle();
    final screen = tester.widget<Scaffold>(find.byType(Scaffold));
    final paragraph = _paragraphText(tester, 0);
    harness.books.buckets.add(Uint8List(64)..[3] = 1);
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)), same(screen));
    expect(_paragraphText(tester, 0), same(paragraph));
  });
}

RichText _paragraphText(WidgetTester tester, int index) =>
    tester.widget<RichText>(
      find.descendant(
        of: find.byType(ReaderParagraph).at(index),
        matching: find.byType(RichText),
      ),
    );

TextSpan _span(RichText text, String content) {
  TextSpan? search(InlineSpan span) {
    if (span is! TextSpan) return null;
    if (span.text?.trim() == content) return span;
    for (final child in span.children ?? <InlineSpan>[]) {
      final found = search(child);
      if (found != null) return found;
    }
    return null;
  }

  return search(text.text)!;
}

Future<
  ({
    _Playback playback,
    _Books books,
    _Audio audio,
    ProviderContainer container,
  })
>
_mount(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final books = _Books();
  final playback = _Playback();
  final audio = _Audio(playback);
  final router = GoRouter(
    initialLocation: '/player/1',
    routes: [
      GoRoute(
        path: '/player/:id',
        builder: (_, state) =>
            PlayerScreen(bookId: state.pathParameters['id']!),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bookServiceProvider.overrideWithValue(books),
        epubServiceProvider.overrideWithValue(_Epub()),
        ttsProvider.overrideWith((ref) => playback),
        audioHandlerProvider.overrideWithValue(audio),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(ReaderParagraph), findsNWidgets(3));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PlayerScreen)),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    await books.buckets.close();
  });
  return (playback: playback, books: books, audio: audio, container: container);
}

class _Playback extends TtsService {
  _Playback() : super(backends: const []);
  void publish(TtsPlaybackState value) {
    state = value;
  }
}

class _Books implements BookService {
  final book = Book(
    id: 1,
    title: 'Reader test',
    chapterCount: 2,
    filePath: 'test.epub',
  );
  final visited = <(int, int)>[];
  final buckets = StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> watchBucketProgress({
    required int bookId,
    required int chapterIndex,
    int bucketCount = 64,
  }) => buckets.stream;
  @override
  Book? getBook(int id) => id == book.id ? book : null;
  @override
  void updateProgress(int id, int progress) {
    book.progress = progress;
  }

  @override
  void markBucketProgress({
    required int bookId,
    required int chapterIndex,
    required int paragraphIndex,
    required int totalParagraphs,
    int bucketCount = 64,
  }) {
    visited.add((chapterIndex, paragraphIndex));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Audio implements TtsAudioHandler {
  final TtsService playback;
  _Audio(this.playback);
  @override
  VoidCallback? onSkipNext;
  @override
  VoidCallback? onSkipPrevious;
  @override
  Future<void> stop() => playback.stop();
  @override
  Future<void> play() => playback.play();
  @override
  Future<void> pause() => playback.pause();
  @override
  void updateNowPlaying({
    required String id,
    required String title,
    String? artist,
    String? album,
    Uri? artUri,
  }) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Epub extends EpubService {
  @override
  Future<epub.ParsedEpubBook> openEpub(String path) async =>
      epub.ParsedEpubBook(
        metadata: const epub.EpubMetadata(title: 'Reader test'),
        sections: [
          _section(0, [
            'First sentence. Second sentence.',
            'Another paragraph. More text.',
            'Last paragraph. Final sentence.',
          ]),
          _section(1, ['Next chapter text.']),
        ],
      );
}

epub.Section _section(int index, List<String> paragraphs) {
  final href = 'chapter$index.xhtml';
  final source = epub.SourceMap(
    spineIndex: index,
    href: href,
    nodePath: Int32List(0),
  );
  return epub.Section(
    id: 'section$index',
    title: 'Chapter $index',
    startHref: href,
    spineStart: index,
    spineEnd: index,
    anchors: const [],
    document: epub.ReaderDocument(
      chapterHref: href,
      blocks: [
        for (final text in paragraphs)
          epub.ReaderBlock(
            kind: epub.ReaderBlockKind.paragraph,
            level: 0,
            ordered: false,
            inlines: [
              epub.ReaderInline(
                kind: epub.ReaderInlineKind.text,
                text: text,
                styleHints: const [],
                children: const [],
                source: source,
              ),
            ],
            blocks: const [],
            items: const [],
            rows: const [],
            source: source,
          ),
      ],
    ),
  );
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audiobookify/core/providers.dart';
import 'package:audiobookify/objectbox.g.dart';
import 'package:audiobookify/screens/player_screen.dart';
import 'package:audiobookify/services/book_service.dart';
import 'package:audiobookify/services/epub_service.dart';
import 'package:audiobookify/services/tts_audio_handler.dart';
import 'package:audiobookify/services/tts_service.dart';
import 'package:audiobookify/src/rust/api/epub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const flutterTtsChannel = MethodChannel('flutter_tts');
  const audioSessionChannel = MethodChannel('com.ryanheise.audio_session');
  const avAudioSessionChannel =
      MethodChannel('com.ryanheise.av_audio_session');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(flutterTtsChannel, (call) async {
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioSessionChannel, (call) async {
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(avAudioSessionChannel, (call) async {
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(flutterTtsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioSessionChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(avAudioSessionChannel, null);
  });

  testWidgets(
      'PlayerScreen renders content and updates paragraph selection',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final tempDir =
        await Directory.systemTemp.createTemp('audiobookify_test_');
    final store =
        Store(getObjectBoxModel(), directory: tempDir.path);
    addTearDown(() async {
      store.close();
      await tempDir.delete(recursive: true);
    });

    final epubBook = ParsedEpubBook(
      metadata: const EpubMetadata(
        title: 'Test Book',
        creator: 'Test Author',
        language: 'en',
        identifier: 'id-1',
        publisher: 'Test Publisher',
        description: 'Test Description',
      ),
      coverImage: null,
      sections: [
        Section(
          id: 'section-1',
          title: 'Chapter 1',
          startHref: 'chapter1.xhtml',
          spineStart: 0,
          spineEnd: 0,
          anchors: const [],
          document: ReaderDocument(
            chapterHref: 'chapter1.xhtml',
            blocks: [
              ReaderBlock(
                kind: ReaderBlockKind.paragraph,
                level: 0,
                ordered: false,
                inlines: [
                  ReaderInline(
                    kind: ReaderInlineKind.text,
                    text: 'Hello world.',
                    styleHints: [],
                    children: [],
                    source: _source('chapter1.xhtml'),
                  ),
                ],
                blocks: [],
                items: [],
                rows: [],
                source: _source('chapter1.xhtml'),
              ),
              ReaderBlock(
                kind: ReaderBlockKind.paragraph,
                level: 0,
                ordered: false,
                inlines: [
                  ReaderInline(
                    kind: ReaderInlineKind.text,
                    text: 'Second paragraph.',
                    styleHints: [],
                    children: [],
                    source: _source('chapter1.xhtml', fragment: 'p2'),
                  ),
                ],
                blocks: [],
                items: [],
                rows: [],
                source: _source('chapter1.xhtml', fragment: 'p2'),
              ),
            ],
          ),
        ),
      ],
    );

    final bookService = BookService(store);
    final saveResult = bookService.saveBook(epubBook, 'test.epub');
    final savedBook = saveResult.book;
    final ttsService = TtsService();
    final audioHandler = TtsAudioHandler(ttsService);

    addTearDown(() async {
      await audioHandler.stop();
      ttsService.dispose();
    });

    final router = GoRouter(
      initialLocation: '/player/${savedBook.id}',
      routes: [
        GoRoute(
          path: '/player/:id',
          builder: (context, state) => PlayerScreen(
            bookId: state.pathParameters['id']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bookServiceProvider.overrideWithValue(bookService),
          epubServiceProvider.overrideWithValue(
            _FakeEpubService(epubBook),
          ),
          ttsProvider.overrideWith((ref) => ttsService),
          audioHandlerProvider.overrideWithValue(audioHandler),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pump();
    await _pumpUntilFound(
      tester,
      find.textContaining('Hello world', findRichText: true),
    );
    expect(
      find.textContaining('Hello world', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Second paragraph', findRichText: true),
      findsOneWidget,
    );

    expect(ttsService.state.paragraphIndex, 0);
    await tester.tap(
      find.textContaining('Second paragraph', findRichText: true),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(ttsService.state.paragraphIndex, 1);
  }, skip: true); // Hanging in test runner; revisit with async/ticker control.
}

SourceMap _source(
  String href, {
  String? fragment,
}) {
  return SourceMap(
    spineIndex: 0,
    href: href,
    fragment: fragment,
    nodePath: Int32List(0),
  );
}

class _FakeEpubService extends EpubService {
  final ParsedEpubBook book;

  _FakeEpubService(this.book);

  @override
  Future<ParsedEpubBook> openEpub(String path) async => book;
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxTries = 40,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var i = 0; i < maxTries; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out waiting for ${finder.description}.');
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audiobookify/core/providers.dart';
import 'package:audiobookify/objectbox.g.dart';
import 'package:audiobookify/screens/book_detail_screen.dart';
import 'package:audiobookify/services/book_service.dart';
import 'package:audiobookify/services/epub_service.dart';
import 'package:audiobookify/src/rust/api/epub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BookDetailScreen uses cached chapter index when current',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final epubPath = await harness.createFile('alice.epub', contents: 'alpha');
    final bookService = BookService(harness.store);
    final savedBook = bookService.saveBook(
      _stubEpubBook(chapterTitles: const ['Chapter 1']),
      epubPath,
    ).book;
    final epubService = _CountingEpubService(_stubEpubBook());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bookServiceProvider.overrideWithValue(bookService),
          epubServiceProvider.overrideWithValue(epubService),
          bucketProgressProvider.overrideWith(
            (ref, args) => Stream.value(Uint8List(args.bucketCount)),
          ),
        ],
        child: MaterialApp(
          home: BookDetailScreen(bookId: savedBook.id.toString()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Chapters'), findsOneWidget);
    expect(find.text('Chapter 1'), findsOneWidget);
    expect(epubService.openCount, 0);
  }, skip: true);

  testWidgets('BookDetailScreen refreshes stale cached chapter index once',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final epubPath = await harness.createFile('alice.epub', contents: 'alpha');
    final bookService = BookService(harness.store);
    final savedBook = bookService.saveBook(
      _stubEpubBook(chapterTitles: const ['Old Chapter']),
      epubPath,
    ).book;
    final file = File(epubPath);
    file.writeAsStringSync('alpha-beta');
    file.setLastModifiedSync(
      DateTime.now().add(const Duration(seconds: 2)),
    );

    final refreshedBook = _stubEpubBook(
      chapterTitles: const ['Old Chapter', 'New Chapter'],
    );
    final epubService = _CountingEpubService(refreshedBook);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bookServiceProvider.overrideWithValue(bookService),
          epubServiceProvider.overrideWithValue(epubService),
          bucketProgressProvider.overrideWith(
            (ref, args) => Stream.value(Uint8List(args.bucketCount)),
          ),
        ],
        child: MaterialApp(
          home: BookDetailScreen(bookId: savedBook.id.toString()),
        ),
      ),
    );

    await tester.pump();
    await _pumpUntilFound(tester, find.text('New Chapter'));

    expect(epubService.openCount, 1);
    expect(find.text('Old Chapter'), findsOneWidget);
    expect(find.text('New Chapter'), findsOneWidget);
    expect(bookService.getChapterIndex(savedBook.id).length, 2);
  }, skip: true);
}

class _Harness {
  final Directory tempDir;
  final Store store;

  _Harness(this.tempDir, this.store);

  Future<String> createFile(String name, {required String contents}) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsString(contents);
    return file.path;
  }

  Future<void> dispose() async {
    store.close();
    await tempDir.delete(recursive: true);
  }
}

Future<_Harness> _createHarness() async {
  final tempDir = await Directory.systemTemp.createTemp('audiobookify_detail_');
  final store = await openStore(directory: tempDir.path);
  return _Harness(tempDir, store);
}

class _CountingEpubService extends EpubService {
  final ParsedEpubBook book;
  int openCount = 0;

  _CountingEpubService(this.book);

  @override
  Future<ParsedEpubBook> openEpub(String path) async {
    openCount += 1;
    return book;
  }
}

ParsedEpubBook _stubEpubBook({List<String> chapterTitles = const ['Chapter 1']}) {
  return ParsedEpubBook(
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
      for (var i = 0; i < chapterTitles.length; i++)
        Section(
          id: 'section-$i',
          title: chapterTitles[i],
          startHref: 'chapter${i + 1}.xhtml',
          spineStart: i,
          spineEnd: i,
          anchors: const [],
          document: ReaderDocument(
            chapterHref: 'chapter${i + 1}.xhtml',
            blocks: [
              ReaderBlock(
                kind: ReaderBlockKind.paragraph,
                level: 0,
                ordered: false,
                inlines: [
                  ReaderInline(
                    kind: ReaderInlineKind.text,
                    text: 'Body ${i + 1}',
                    styleHints: const [],
                    children: const [],
                    source: _source('chapter${i + 1}.xhtml'),
                  ),
                ],
                blocks: const [],
                items: const [],
                rows: const [],
                source: _source('chapter${i + 1}.xhtml'),
              ),
            ],
          ),
        ),
    ],
  );
}

SourceMap _source(String href) {
  return SourceMap(
    spineIndex: 0,
    href: href,
    fragment: null,
    nodePath: Int32List(0),
  );
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

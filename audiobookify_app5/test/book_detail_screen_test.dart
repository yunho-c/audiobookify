import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audiobookify_app5/core/providers.dart';
import 'package:audiobookify_app5/objectbox.g.dart';
import 'package:audiobookify_app5/screens/book_detail_screen.dart';
import 'package:audiobookify_app5/services/book_service.dart';
import 'package:audiobookify_app5/services/epub_service.dart';
import 'package:audiobookify_app5/src/rust/api/epub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BookDetailScreen renders metadata and chapters',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final tempDir =
        await Directory.systemTemp.createTemp('audiobookify_detail_');
    final store = Store(getObjectBoxModel(), directory: tempDir.path);
    addTearDown(() async {
      store.close();
      await tempDir.delete(recursive: true);
    });

    final epubBook = EpubBook(
      metadata: const EpubMetadata(
        title: 'Test Book',
        creator: 'Test Author',
        language: 'en',
        identifier: 'id-1',
        publisher: 'Test Publisher',
        description: 'Test Description',
      ),
      chapters: [
        ChapterInfo(
          index: BigInt.from(0),
          id: 'chapter-1',
          href: 'chapter1.xhtml',
          mediaType: 'application/xhtml+xml',
        ),
      ],
      toc: [
        const TocEntry(title: 'Chapter 1', href: 'chapter1.xhtml'),
      ],
      coverImage: null,
      chapterContents: const [
        '<p>Hello world.</p><p>Second paragraph.</p>',
      ],
    );

    final bookService = BookService(store);
    final savedBook = bookService.saveBook(epubBook, 'test.epub');
    bookService.updateProgress(savedBook.id, 40);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bookServiceProvider.overrideWithValue(bookService),
          epubServiceProvider.overrideWithValue(_FakeEpubService(epubBook)),
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
    await _pumpUntilFound(
      tester,
      find.text('Test Book'),
    );
    expect(find.text('Test Book'), findsWidgets);
    expect(find.text('Test Author'), findsWidgets);
    expect(find.text('40% listened'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Chapters'), findsOneWidget);
    expect(find.text('Chapter 1'), findsOneWidget);
  }, skip: true); // Hanging in test runner; revisit with font/ticker isolation.

  testWidgets('BookDetailScreen handles missing epub gracefully',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final tempDir =
        await Directory.systemTemp.createTemp('audiobookify_detail_');
    final store = Store(getObjectBoxModel(), directory: tempDir.path);
    addTearDown(() async {
      store.close();
      await tempDir.delete(recursive: true);
    });

    final bookService = BookService(store);
    final savedBook = bookService.saveBook(
      _stubEpubBook(),
      'missing.epub',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bookServiceProvider.overrideWithValue(bookService),
          epubServiceProvider.overrideWithValue(_ThrowingEpubService()),
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
    await _pumpUntilFound(
      tester,
      find.text('No chapters available'),
    );
    expect(find.text('Test Book'), findsWidgets);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('No chapters available'), findsOneWidget);
  }, skip: true); // Hanging in test runner; revisit with font/ticker isolation.
}

class _FakeEpubService extends EpubService {
  final EpubBook book;

  _FakeEpubService(this.book);

  @override
  Future<EpubBook> openEpub(String path) async => book;
}

class _ThrowingEpubService extends EpubService {
  @override
  Future<EpubBook> openEpub(String path) {
    throw Exception('Failed to load epub');
  }
}

EpubBook _stubEpubBook() {
  return EpubBook(
    metadata: const EpubMetadata(
      title: 'Test Book',
      creator: 'Test Author',
      language: 'en',
      identifier: 'id-1',
      publisher: 'Test Publisher',
      description: 'Test Description',
    ),
    chapters: [
      ChapterInfo(
        index: BigInt.from(0),
        id: 'chapter-1',
        href: 'chapter1.xhtml',
        mediaType: 'application/xhtml+xml',
      ),
    ],
    toc: [
      const TocEntry(title: 'Chapter 1', href: 'chapter1.xhtml'),
    ],
    coverImage: null,
    chapterContents: const [
      '<p>Hello world.</p><p>Second paragraph.</p>',
    ],
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

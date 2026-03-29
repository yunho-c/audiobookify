import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:audiobookify/objectbox.g.dart';
import 'package:audiobookify/services/book_service.dart';
import 'package:audiobookify/src/rust/api/epub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saveBook persists chapter index rows and cache fingerprint', () async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final epubPath = await harness.createFile('alice.epub', contents: 'alpha');
    final service = BookService(harness.store);

    final saved = service.saveBook(
      _stubEpubBook(
        title: 'Alice',
        chapterTitles: const ['Chapter 1', 'Chapter 2'],
      ),
      epubPath,
    ).book;

    final chapters = service.getChapterIndex(saved.id);

    expect(saved.chapterCount, 2);
    expect(saved.chapterIndexCacheVersion, BookService.chapterIndexCacheVersion);
    expect(saved.chapterIndexFileSizeBytes, greaterThan(0));
    expect(saved.chapterIndexFileModifiedAt, isNotNull);
    expect(chapters.map((c) => c.title), ['Chapter 1', 'Chapter 2']);
    expect(chapters.map((c) => c.chapterIndex), [0, 1]);
    expect(service.isChapterIndexCurrent(saved), isTrue);
  }, skip: true);

  test('refreshChapterIndex replaces old rows and updates chapter count',
      () async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final epubPath = await harness.createFile('alice.epub', contents: 'alpha');
    final service = BookService(harness.store);

    final book = service.saveBook(
      _stubEpubBook(
        title: 'Alice',
        chapterTitles: const ['Old 1', 'Old 2'],
      ),
      epubPath,
    ).book;

    service.refreshChapterIndex(
      book,
      _stubEpubBook(
        title: 'Alice',
        chapterTitles: const ['New 1'],
      ),
    );

    final chapters = service.getChapterIndex(book.id);
    expect(chapters.length, 1);
    expect(chapters.single.title, 'New 1');
    expect(book.chapterCount, 1);
  }, skip: true);

  test('isChapterIndexCurrent detects file stat changes', () async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final epubPath = await harness.createFile('alice.epub', contents: 'alpha');
    final service = BookService(harness.store);
    final book = service.saveBook(
      _stubEpubBook(title: 'Alice', chapterTitles: const ['Chapter 1']),
      epubPath,
    ).book;

    expect(service.isChapterIndexCurrent(book), isTrue);

    final file = File(epubPath);
    file.writeAsStringSync('alpha-beta');
    file.setLastModifiedSync(
      DateTime.now().add(const Duration(seconds: 2)),
    );

    expect(service.isChapterIndexCurrent(book), isFalse);
  }, skip: true);

  test('deleteBookAndAssets removes cached chapter rows', () async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final epubPath = await harness.createFile('alice.epub', contents: 'alpha');
    final service = BookService(harness.store);
    final book = service.saveBook(
      _stubEpubBook(
        title: 'Alice',
        chapterTitles: const ['Chapter 1', 'Chapter 2'],
      ),
      epubPath,
    ).book;

    final removed = await service.deleteBookAndAssets(book.id);

    expect(removed, isTrue);
    expect(service.getBook(book.id), isNull);
    expect(service.getChapterIndex(book.id), isEmpty);
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
  final tempDir = await Directory.systemTemp.createTemp('audiobookify_book_');
  final store = await openStore(directory: tempDir.path);
  return _Harness(tempDir, store);
}

ParsedEpubBook _stubEpubBook({
  required String title,
  required List<String> chapterTitles,
}) {
  return ParsedEpubBook(
    metadata: EpubMetadata(
      title: title,
      creator: 'Test Author',
      language: 'en',
      identifier: 'stub-id',
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
          startFragment: null,
          endHref: 'chapter${i + 1}.xhtml',
          endFragment: null,
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
                    text: 'Chapter ${i + 1} body',
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

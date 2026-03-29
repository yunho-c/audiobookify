import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:audiobookify/services/epub_service.dart';
import 'package:audiobookify/src/rust/api/epub.dart';

void main() {
  test('caches parsed books by path', () async {
    var loadCount = 0;
    final service = EpubService(
      loader: (path) async {
        loadCount += 1;
        return _stubBook(title: path);
      },
    );

    final first = await service.openEpub('/tmp/alice.epub');
    final second = await service.openEpub('/tmp/alice.epub');

    expect(loadCount, 1);
    expect(identical(first, second), isTrue);
  });

  test('deduplicates concurrent loads for the same path', () async {
    var loadCount = 0;
    final completer = Completer<ParsedEpubBook>();
    final service = EpubService(
      loader: (path) {
        loadCount += 1;
        return completer.future;
      },
    );

    final first = service.openEpub('/tmp/alice.epub');
    final second = service.openEpub('/tmp/alice.epub');

    expect(loadCount, 1);

    completer.complete(_stubBook(title: 'Alice'));
    final results = await Future.wait([first, second]);

    expect(identical(results[0], results[1]), isTrue);
  });

  test('does not cache failed loads', () async {
    var loadCount = 0;
    final service = EpubService(
      loader: (path) async {
        loadCount += 1;
        if (loadCount == 1) {
          throw StateError('parse failed');
        }
        return _stubBook(title: 'Recovered');
      },
    );

    await expectLater(
      service.openEpub('/tmp/alice.epub'),
      throwsA(isA<StateError>()),
    );

    final recovered = await service.openEpub('/tmp/alice.epub');

    expect(loadCount, 2);
    expect(recovered.metadata.title, 'Recovered');
  });
}

ParsedEpubBook _stubBook({required String title}) {
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
    sections: const [],
  );
}

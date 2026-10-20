import 'dart:async';
import 'dart:typed_data';

import 'package:audiobookify/reader/epub_resource_resolver.dart';
import 'package:audiobookify/reader/reader_ir.dart';
import 'package:flutter_test/flutter_test.dart';

ReaderResourceRef resource(String href) =>
    ReaderResourceRef(href: href, kind: ReaderResourceKind.image);

void main() {
  test(
    'shares concurrent normalized requests and returns cached bytes immediately',
    () async {
      final pending = Completer<Uint8List?>();
      final reads = <String>[];
      final resolver = EpubResourceResolver(
        epubPath: '',
        loader: (href) {
          reads.add(href);
          return pending.future;
        },
      );
      final first = resolver.loadResource(
        resource(' images/my%20pic.png#figure '),
      );
      final second = resolver.loadImage('/images/my pic.png');
      expect(reads, ['images/my pic.png']);
      final bytes = Uint8List.fromList([1, 2, 3]);
      pending.complete(bytes);
      expect(await first, same(bytes));
      expect(await second, same(bytes));

      Uint8List? cached;
      resolver.loadHref('images/my pic.png').then((value) {
        cached = value;
      });
      expect(cached, same(bytes));
      expect(reads, hasLength(1));
    },
  );

  test('shares failures while pending and allows a subsequent retry', () async {
    final pending = Completer<Uint8List?>();
    var reads = 0;
    final bytes = Uint8List.fromList([1]);
    final resolver = EpubResourceResolver(
      epubPath: '',
      loader: (_) {
        reads++;
        return reads == 1 ? pending.future : Future.value(bytes);
      },
    );
    final first = resolver.loadImage('pic.png');
    final second = resolver.loadImage('pic.png');
    final failures = [
      expectLater(first, throwsStateError),
      expectLater(second, throwsStateError),
    ];
    pending.completeError(StateError('temporary failure'));
    await Future.wait(failures);
    expect(reads, 1);
    expect(await resolver.loadImage('pic.png'), same(bytes));
    expect(reads, 2);
  });

  test(
    'missing resources can be retried and slash fallback still works',
    () async {
      final reads = <String>[];
      final bytes = Uint8List.fromList([1]);
      var available = false;
      final resolver = EpubResourceResolver(
        epubPath: '',
        loader: (href) async {
          reads.add(href);
          return available && href == '/pic.png' ? bytes : null;
        },
      );
      expect(await resolver.loadImage('pic.png'), isNull);
      available = true;
      expect(await resolver.loadImage('pic.png'), same(bytes));
      expect(reads, ['pic.png', '/pic.png', 'pic.png', '/pic.png']);
    },
  );

  test('completed futures do not bypass the bounded byte cache', () async {
    final reads = <String>[];
    final resolver = EpubResourceResolver(
      epubPath: '',
      cacheSize: 1,
      loader: (href) async {
        reads.add(href);
        return Uint8List.fromList([1]);
      },
    );
    await resolver.loadImage('a.png');
    await resolver.loadImage('b.png');
    await resolver.loadImage('a.png');
    expect(reads, ['a.png', 'b.png', 'a.png']);
  });

  test('malformed hrefs fail asynchronously', () async {
    final resolver = EpubResourceResolver.fromMemory({});
    await expectLater(resolver.loadImage('%zz'), throwsArgumentError);
  });
}

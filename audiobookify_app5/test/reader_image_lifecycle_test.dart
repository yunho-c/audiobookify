import 'dart:async';
import 'dart:typed_data';

import 'package:audiobookify/models/player_theme_settings.dart';
import 'package:audiobookify/reader/epub_resource_resolver.dart';
import 'package:audiobookify/reader/reader_ir.dart';
import 'package:audiobookify/reader/reader_renderer.dart';
import 'package:audiobookify/reader/reader_segmentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reader_fixtures.dart';

class _CountingResolver extends EpubResourceResolver {
  _CountingResolver(Future<Uint8List?> Function(String) loader)
    : super(epubPath: '', loader: loader);
  int requests = 0;

  @override
  Future<Uint8List?> loadResource(ReaderResourceRef resource) {
    requests++;
    return super.loadResource(resource);
  }
}

class _Harness extends StatefulWidget {
  final bool inline;
  final EpubResourceResolver resolver;
  const _Harness({super.key, required this.inline, required this.resolver});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late EpubResourceResolver resolver = widget.resolver;
  String href = 'a.png';
  bool active = false;
  bool visible = true;
  double width = 240;

  void update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: !visible
              ? const SizedBox.shrink()
              : ReaderBlockRenderer.buildBlock(
                  renderBlock: ReaderRenderBlock(
                    block: widget.inline
                        ? ParagraphBlock([
                            const TextInline('A sentence. Another sentence. '),
                            InlineImage(
                              resource: ReaderResourceRef(
                                href: href,
                                kind: ReaderResourceKind.image,
                              ),
                            ),
                          ])
                        : ImageBlock(
                            resource: ReaderResourceRef(
                              href: href,
                              kind: ReaderResourceKind.image,
                            ),
                          ),
                    style: const RenderBlockStyle(),
                    ttsIndex: widget.inline ? 0 : null,
                  ),
                  theme: readerTestTheme(
                    paragraphStyle: PlayerThemeActiveParagraphStyle.underline,
                  ),
                  resolver: resolver,
                  isActiveParagraph: active,
                  activeSentenceIndex: active ? 1 : -1,
                  previousSentenceIndex: -1,
                  transitionValue: 0.5,
                  sentenceRecognizer: null,
                  linkRecognizer: null,
                  onTapParagraph: null,
                ),
        ),
      ),
    ),
  );
}

void main() {
  for (final inline in [false, true]) {
    final label = inline ? 'inline' : 'block';
    testWidgets(
      '$label keeps pending and loaded images stable across rebuilds',
      (tester) async {
        final pending = Completer<Uint8List?>();
        final bytes = readerImageBytes();
        final resolver = _CountingResolver((_) => pending.future);
        final key = GlobalKey<_HarnessState>();
        await tester.pumpWidget(
          _Harness(key: key, inline: inline, resolver: resolver),
        );
        await precacheReaderImage(tester, bytes);
        for (var i = 0; i < 3; i++) {
          key.currentState!.update(() {
            key.currentState!.active = i.isEven;
          });
          await tester.pump(const Duration(milliseconds: 16));
          expect(resolver.requests, 1);
          expect(find.byIcon(Icons.image_outlined), findsOneWidget);
        }
        pending.complete(bytes);
        await tester.pumpAndSettle();
        expectDecodedReaderImage(tester, bytes);
        final element = tester.element(find.byType(Image));
        final size = tester.getSize(find.byType(Image));
        for (var i = 0; i < 12; i++) {
          key.currentState!.update(() {
            key.currentState!.active = i.isEven;
          });
          await tester.pump(const Duration(milliseconds: 16));
          expectDecodedReaderImage(tester, bytes);
          expect(tester.element(find.byType(Image)), same(element));
          expect(tester.getSize(find.byType(Image)), size);
          expect(resolver.requests, 1);
        }
        key.currentState!.update(() {
          key.currentState!.width = 280;
        });
        await tester.pump();
        expectDecodedReaderImage(tester, bytes);
        expect(resolver.requests, 1);

        key.currentState!.update(() {
          key.currentState!.visible = false;
        });
        await tester.pump();
        key.currentState!.update(() {
          key.currentState!.visible = true;
        });
        await tester.pump();
        expectDecodedReaderImage(tester, bytes);
      },
    );

    testWidgets(
      '$label resets on resource and book changes without stale images',
      (tester) async {
        final a = readerImageBytes();
        final b = readerImageBytes();
        final c = readerImageBytes();
        final pendingB = Completer<Uint8List?>();
        final resolver = _CountingResolver(
          (href) => href == 'a.png' ? Future.value(a) : pendingB.future,
        );
        final key = GlobalKey<_HarnessState>();
        await tester.pumpWidget(
          _Harness(key: key, inline: inline, resolver: resolver),
        );
        for (final bytes in [a, b, c]) {
          await precacheReaderImage(tester, bytes);
        }
        await tester.pumpAndSettle();
        expectDecodedReaderImage(tester, a);

        key.currentState!.update(() {
          key.currentState!.href = 'b.png';
        });
        await tester.pump();
        expect(find.byType(Image), findsNothing);
        pendingB.complete(b);
        await tester.pumpAndSettle();
        expectDecodedReaderImage(tester, b);

        final pendingBook = Completer<Uint8List?>();
        final newBook = _CountingResolver((_) => pendingBook.future);
        key.currentState!.update(() {
          key.currentState!.resolver = newBook;
        });
        await tester.pump();
        expect(find.byType(Image), findsNothing);
        pendingBook.complete(c);
        await tester.pumpAndSettle();
        expectDecodedReaderImage(tester, c);
        expect(newBook.requests, 1);
      },
    );

    testWidgets('$label ignores late completion for an old resource', (
      tester,
    ) async {
      final pendingA = Completer<Uint8List?>();
      final pendingB = Completer<Uint8List?>();
      final bytes = readerImageBytes();
      final key = GlobalKey<_HarnessState>();
      await tester.pumpWidget(
        _Harness(
          key: key,
          inline: inline,
          resolver: _CountingResolver(
            (href) => href == 'a.png' ? pendingA.future : pendingB.future,
          ),
        ),
      );
      await precacheReaderImage(tester, bytes);
      key.currentState!.update(() {
        key.currentState!.href = 'b.png';
      });
      await tester.pump();
      pendingA.complete(readerImageBytes());
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      pendingB.complete(bytes);
      await tester.pumpAndSettle();
      expectDecodedReaderImage(tester, bytes);
    });

    testWidgets('$label keeps load errors stable across unrelated rebuilds', (
      tester,
    ) async {
      final resolver = _CountingResolver(
        (_) => Future.error(StateError('failed')),
      );
      final key = GlobalKey<_HarnessState>();
      await tester.pumpWidget(
        _Harness(key: key, inline: inline, resolver: resolver),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        key.currentState!.update(() {
          key.currentState!.active = i.isEven;
        });
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byType(Image), findsNothing);
        expect(resolver.requests, 1);
        expect(tester.takeException(), isNull);
      }
    });
  }
}

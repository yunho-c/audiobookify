import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:audiobookify/models/player_theme_settings.dart';
import 'package:audiobookify/reader/epub_resource_resolver.dart';
import 'package:audiobookify/reader/reader_ir.dart';
import 'package:audiobookify/reader/reader_renderer.dart';
import 'package:audiobookify/reader/reader_segmentation.dart';

void main() {
  testWidgets('renders text blocks with sentence spans', (tester) async {
    final renderBlock = ReaderRenderBlock(
      block: ParagraphBlock([const TextInline('Hello world.')]),
      style: const RenderBlockStyle(),
      ttsIndex: 0,
    );
    final ttsData = ReaderTtsParagraph(
      plainText: 'Hello world.',
      sentences: const ['Hello world.'],
      sentenceRuns: const [
        [TextRun('Hello world.', TextRunStyle())],
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBlockRenderer.buildBlock(
            renderBlock: renderBlock,
            theme: _theme(),
            resolver: EpubResourceResolver.fromMemory(const {}),
            isActiveParagraph: true,
            activeSentenceIndex: 0,
            previousSentenceIndex: -1,
            transitionValue: 1.0,
            sentenceRecognizer: null,
            linkRecognizer: null,
            onTapParagraph: null,
            ttsData: ttsData,
          ),
        ),
      ),
    );

    expect(
      find.textContaining('Hello world', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('renders centered paragraphs with centered RichText', (
    tester,
  ) async {
    final renderBlock = ReaderRenderBlock(
      block: ParagraphBlock([
        const TextInline('Centered text.'),
      ], alignment: ReaderBlockAlignment.center),
      style: const RenderBlockStyle(),
      ttsIndex: 0,
    );
    final ttsData = ReaderTtsParagraph(
      plainText: 'Centered text.',
      sentences: const ['Centered text.'],
      sentenceRuns: const [
        [TextRun('Centered text.', TextRunStyle())],
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBlockRenderer.buildBlock(
            renderBlock: renderBlock,
            theme: _theme(),
            resolver: EpubResourceResolver.fromMemory(const {}),
            isActiveParagraph: false,
            activeSentenceIndex: -1,
            previousSentenceIndex: -1,
            transitionValue: 0.0,
            sentenceRecognizer: null,
            linkRecognizer: null,
            onTapParagraph: null,
            ttsData: ttsData,
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText).first);
    expect(richText.textAlign, TextAlign.center);
  });

  testWidgets('fades previous sentence text brightness during transition', (
    tester,
  ) async {
    final renderBlock = ReaderRenderBlock(
      block: ParagraphBlock([
        const TextInline('First sentence. Second sentence.'),
      ]),
      style: const RenderBlockStyle(),
      ttsIndex: 0,
    );
    final ttsData = ReaderTtsParagraph(
      plainText: 'First sentence. Second sentence.',
      sentences: const ['First sentence.', 'Second sentence.'],
      sentenceRuns: const [
        [TextRun('First sentence.', TextRunStyle())],
        [TextRun('Second sentence.', TextRunStyle())],
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBlockRenderer.buildBlock(
            renderBlock: renderBlock,
            theme: _theme(
              readerTheme: const PlayerThemeSettings(
                textColorMode: PlayerThemeTextColorMode.fixed,
                textColor: Colors.white,
              ),
            ),
            resolver: EpubResourceResolver.fromMemory(const {}),
            isActiveParagraph: true,
            activeSentenceIndex: 1,
            previousSentenceIndex: 0,
            transitionValue: 0.5,
            sentenceRecognizer: null,
            linkRecognizer: null,
            onTapParagraph: null,
            ttsData: ttsData,
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText).first);
    final rootSpan = richText.text as TextSpan;
    final previousSentenceSpan = _findTextSpan(rootSpan, 'First sentence.');
    final currentSentenceSpan = _findTextSpan(rootSpan, 'Second sentence.');

    expect(previousSentenceSpan.style?.color?.a, closeTo(0.89, 0.01));
    expect(previousSentenceSpan.style?.color, isNot(Colors.white));
    expect(currentSentenceSpan.style?.color, Colors.white);
  });

  testWidgets('keeps list marker layout while right-aligning list content', (
    tester,
  ) async {
    final renderBlock = ReaderRenderBlock(
      block: const ParagraphBlock([
        TextInline('List item'),
      ], alignment: ReaderBlockAlignment.right),
      style: const RenderBlockStyle(listMarker: '1.'),
      ttsIndex: 0,
    );
    final ttsData = ReaderTtsParagraph(
      plainText: 'List item',
      sentences: const ['List item'],
      sentenceRuns: const [
        [TextRun('List item', TextRunStyle())],
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBlockRenderer.buildBlock(
            renderBlock: renderBlock,
            theme: _theme(),
            resolver: EpubResourceResolver.fromMemory(const {}),
            isActiveParagraph: false,
            activeSentenceIndex: -1,
            previousSentenceIndex: -1,
            transitionValue: 0.0,
            sentenceRecognizer: null,
            linkRecognizer: null,
            onTapParagraph: null,
            ttsData: ttsData,
          ),
        ),
      ),
    );

    expect(find.text('1.'), findsOneWidget);
    final richText = tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('List item'),
      ),
    );
    expect(richText.textAlign, TextAlign.right);
  });

  testWidgets('renders image blocks from resolver', (tester) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMBAp4XfQAAAABJRU5ErkJggg==',
    );
    final resolver = EpubResourceResolver.fromMemory({
      'images/pic.png': Uint8List.fromList(bytes),
    });

    final renderBlock = ReaderRenderBlock(
      block: const ImageBlock(
        resource: ReaderResourceRef(
          href: 'images/pic.png',
          mediaType: 'image/png',
          kind: ReaderResourceKind.image,
        ),
        caption: 'Caption',
      ),
      style: const RenderBlockStyle(),
      ttsIndex: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: ReaderBlockRenderer.buildBlock(
                renderBlock: renderBlock,
                theme: _theme(),
                resolver: resolver,
                isActiveParagraph: false,
                activeSentenceIndex: -1,
                previousSentenceIndex: -1,
                transitionValue: 0.0,
                sentenceRecognizer: null,
                linkRecognizer: null,
                onTapParagraph: null,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, double.infinity);
    expect(image.height, isNull);
    expect(find.text('Caption'), findsOneWidget);
  });

  testWidgets('respects block image width and max-width presentation', (
    tester,
  ) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMBAp4XfQAAAABJRU5ErkJggg==',
    );
    final resolver = EpubResourceResolver.fromMemory({
      'images/pic.png': Uint8List.fromList(bytes),
    });

    final renderBlock = ReaderRenderBlock(
      block: const ImageBlock(
        resource: ReaderResourceRef(
          href: 'images/pic.png',
          mediaType: 'image/png',
          kind: ReaderResourceKind.image,
        ),
        presentation: ReaderImagePresentation(
          width: ReaderImageLength(
            valueMilli: 100000,
            unit: ReaderImageLengthUnit.percent,
          ),
          maxWidth: ReaderImageLength(
            valueMilli: 40000,
            unit: ReaderImageLengthUnit.percent,
          ),
        ),
      ),
      style: const RenderBlockStyle(),
      ttsIndex: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: ReaderBlockRenderer.buildBlock(
                renderBlock: renderBlock,
                theme: _theme(),
                resolver: resolver,
                isActiveParagraph: false,
                activeSentenceIndex: -1,
                previousSentenceIndex: -1,
                transitionValue: 0.0,
                sentenceRecognizer: null,
                linkRecognizer: null,
                onTapParagraph: null,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final constrainedBox = tester.widget<ConstrainedBox>(
      find.descendant(
        of: find.byType(ClipRRect),
        matching: find.byType(ConstrainedBox),
      ),
    );
    expect(constrainedBox.constraints.maxWidth, closeTo(96, 0.1));
  });

  testWidgets('renders logo-like block images from height metadata', (
    tester,
  ) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMBAp4XfQAAAABJRU5ErkJggg==',
    );
    final resolver = EpubResourceResolver.fromMemory({
      'images/logo.png': Uint8List.fromList(bytes),
    });

    final renderBlock = ReaderRenderBlock(
      block: const ImageBlock(
        resource: ReaderResourceRef(
          href: 'images/logo.png',
          mediaType: 'image/png',
          kind: ReaderResourceKind.image,
        ),
        presentation: ReaderImagePresentation(
          height: ReaderImageLength(
            valueMilli: 1000,
            unit: ReaderImageLengthUnit.em,
          ),
        ),
      ),
      style: const RenderBlockStyle(),
      ttsIndex: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: ReaderBlockRenderer.buildBlock(
                renderBlock: renderBlock,
                theme: _theme(),
                resolver: resolver,
                isActiveParagraph: false,
                activeSentenceIndex: -1,
                previousSentenceIndex: -1,
                transitionValue: 0.0,
                sentenceRecognizer: null,
                linkRecognizer: null,
                onTapParagraph: null,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, isNull);
    expect(image.height, closeTo(18, 0.1));
  });

  testWidgets('renders inline images and interactive links', (tester) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMBAp4XfQAAAABJRU5ErkJggg==',
    );
    final resolver = EpubResourceResolver.fromMemory({
      'images/pic.png': Uint8List.fromList(bytes),
    });
    final recognizers = <TapGestureRecognizer>[];

    final renderBlock = ReaderRenderBlock(
      block: ParagraphBlock([
        const LinkInline(
          target: ReaderLinkTarget(
            kind: ReaderLinkTargetKind.internal,
            href: 'chapter2.xhtml#frag',
            sectionId: 'section-2',
            sectionIndex: 1,
            fragment: 'frag',
          ),
          children: [TextInline('Next')],
        ),
        const TextInline(' '),
        const InlineImage(
          resource: ReaderResourceRef(
            href: 'images/pic.png',
            mediaType: 'image/png',
            kind: ReaderResourceKind.image,
          ),
          alt: 'Inline pic',
          presentation: ReaderImagePresentation(
            height: ReaderImageLength(
              valueMilli: 2000,
              unit: ReaderImageLengthUnit.em,
            ),
          ),
        ),
      ]),
      style: const RenderBlockStyle(),
      ttsIndex: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBlockRenderer.buildBlock(
            renderBlock: renderBlock,
            theme: _theme(),
            resolver: resolver,
            isActiveParagraph: false,
            activeSentenceIndex: -1,
            previousSentenceIndex: -1,
            transitionValue: 0.0,
            sentenceRecognizer: null,
            linkRecognizer: (target) {
              expect(target.href, 'chapter2.xhtml#frag');
              final recognizer = TapGestureRecognizer();
              recognizers.add(recognizer);
              return recognizer;
            },
            onTapParagraph: null,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final linkFinder = find.textContaining('Next', findRichText: true);
    expect(linkFinder, findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.height, closeTo(36, 0.1));
    expect(recognizers, isNotEmpty);

    for (final recognizer in recognizers) {
      recognizer.dispose();
    }
  });
}

ReaderRenderTheme _theme({
  PlayerThemeSettings readerTheme = const PlayerThemeSettings(),
}) {
  return ReaderRenderTheme(
    readerTheme: readerTheme,
    textTheme: const TextTheme(),
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    shadowColor: Colors.black45,
    paragraphSpacing: 4,
    paragraphIndent: 0,
    activeParagraphStyle: PlayerThemeActiveParagraphStyle.highlightBar,
    activeParagraphOpacity: 0.12,
    sentenceHighlightStyle: PlayerThemeSentenceHighlightStyle.background,
    sentenceHighlightOpacity: 0.2,
  );
}

TextSpan _findTextSpan(TextSpan span, String text) {
  if (span.text == text) return span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child is! TextSpan) continue;
    final match = _findTextSpanOrNull(child, text);
    if (match != null) return match;
  }
  throw StateError('No TextSpan found for "$text".');
}

TextSpan? _findTextSpanOrNull(TextSpan span, String text) {
  if (span.text == text) return span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child is! TextSpan) continue;
    final match = _findTextSpanOrNull(child, text);
    if (match != null) return match;
  }
  return null;
}

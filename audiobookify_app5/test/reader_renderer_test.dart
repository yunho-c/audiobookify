import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:audiobookify/reader/epub_resource_resolver.dart';
import 'package:audiobookify/reader/reader_ir.dart';
import 'package:audiobookify/reader/reader_renderer.dart';
import 'package:audiobookify/reader/reader_segmentation.dart';
import 'package:audiobookify/models/player_theme_settings.dart';

void main() {
  testWidgets('renders text blocks with sentence spans', (tester) async {
    final renderBlock = ReaderRenderBlock(
      block: ParagraphBlock([
        const TextInline('Hello world.'),
      ]),
      style: const RenderBlockStyle(),
      ttsIndex: 0,
    );
    final ttsData = ReaderTtsParagraph(
      plainText: 'Hello world.',
      sentences: const ['Hello world.'],
      sentenceRuns: const [
        [TextRun('Hello world.', TextRunStyle())]
      ],
    );

    final theme = ReaderRenderTheme(
      readerTheme: const PlayerThemeSettings(),
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBlockRenderer.buildBlock(
            renderBlock: renderBlock,
            theme: theme,
            resolver: EpubResourceResolver.fromMemory(const {}),
            isActiveParagraph: true,
            activeSentenceIndex: 0,
            previousSentenceIndex: -1,
            transitionValue: 1.0,
            sentenceRecognizer: null,
            onTapParagraph: null,
            ttsData: ttsData,
          ),
        ),
      ),
    );

    expect(find.textContaining('Hello world', findRichText: true), findsOneWidget);
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
        src: 'images/pic.png',
        caption: 'Caption',
      ),
      style: const RenderBlockStyle(),
      ttsIndex: null,
    );

    final theme = ReaderRenderTheme(
      readerTheme: const PlayerThemeSettings(),
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBlockRenderer.buildBlock(
            renderBlock: renderBlock,
            theme: theme,
            resolver: resolver,
            isActiveParagraph: false,
            activeSentenceIndex: -1,
            previousSentenceIndex: -1,
            transitionValue: 0.0,
            sentenceRecognizer: null,
            onTapParagraph: null,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Caption'), findsOneWidget);
  });
}

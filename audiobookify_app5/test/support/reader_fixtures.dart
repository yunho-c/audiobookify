import 'dart:convert';
import 'dart:typed_data';

import 'package:audiobookify/models/player_theme_settings.dart';
import 'package:audiobookify/reader/reader_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Valid 2x2 PNG. Assertions also check decoded pixels, not only Image widgets.
Uint8List readerImageBytes() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4b6DwH4QZYAwAUyoJOS9hkwsAAAAASUVORK5CYII=',
);

ReaderRenderTheme readerTestTheme({
  PlayerThemeActiveParagraphStyle paragraphStyle =
      PlayerThemeActiveParagraphStyle.highlightBar,
}) => ReaderRenderTheme(
  readerTheme: const PlayerThemeSettings(
    fontFamily: null,
    textColorMode: PlayerThemeTextColorMode.fixed,
    textColor: Colors.white,
  ),
  textTheme: const TextTheme(),
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  shadowColor: Colors.black45,
  paragraphSpacing: 4,
  paragraphIndent: 0,
  activeParagraphStyle: paragraphStyle,
  activeParagraphOpacity: 0.12,
  sentenceHighlightStyle: PlayerThemeSentenceHighlightStyle.background,
  sentenceHighlightOpacity: 0.2,
);

Future<void> precacheReaderImage(WidgetTester tester, Uint8List bytes) async {
  await tester.runAsync(
    () => precacheImage(
      MemoryImage(bytes),
      tester.element(find.byType(Scaffold)),
    ),
  );
}

void expectDecodedReaderImage(WidgetTester tester, Uint8List bytes) {
  expect(find.byType(Image), findsOneWidget);
  final image = tester.widget<Image>(find.byType(Image));
  expect((image.image as MemoryImage).bytes, same(bytes));
  expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
  expect(find.byIcon(Icons.image_outlined), findsNothing);
  expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
}

// Simple integration test for EPUB loading API
// This test loads a sample EPUB and verifies basic functionality

import 'dart:io';
import 'package:audiobookify/src/rust/api/epub.dart';
import 'package:audiobookify/src/rust/frb_generated.dart';

Future<void> main() async {
  // Initialize flutter_rust_bridge
  await RustLib.init();

  print('=== EPUB Integration Test ===\n');

  // Path to test EPUB file
  final epubPath = '${Directory.current.path}/test/assets/test_ebook.epub';

  if (!File(epubPath).existsSync()) {
    print('ERROR: Test EPUB file not found at $epubPath');
    exit(1);
  }

  print('Loading EPUB from: $epubPath\n');

  try {
    // Open EPUB
    final book = await openEpub(path: epubPath);
    print('✓ EPUB loaded successfully!\n');

    // Print metadata
    print('--- Metadata ---');
    print('Title: ${book.metadata.title ?? "N/A"}');
    print('Creator: ${book.metadata.creator ?? "N/A"}');
    print('Language: ${book.metadata.language ?? "N/A"}');
    print('Publisher: ${book.metadata.publisher ?? "N/A"}');
    print('');

    // Print section count
    print('--- Sections ---');
    print('Total sections: ${book.sections.length}');
    print('');

    // Check cover image
    final cover = book.coverImage;
    if (cover != null) {
      print('--- Cover Image ---');
      print('Cover image size: ${cover.length} bytes');
    } else {
      print('--- Cover Image ---');
      print('No cover image found');
    }
    print('');

    // Read first section content (just a preview)
    if (book.sections.isNotEmpty) {
      print('--- First Section Preview ---');
      final section = book.sections.first;
      final text = section.document.blocks
          .expand((block) => block.inlines)
          .map((inline) => inline.text ?? '')
          .join(' ')
          .trim();
      final preview =
          text.length > 200 ? '${text.substring(0, 200)}...' : text;
      print(preview);
    }
    print('\n=== All tests passed! ===');
  } on EpubError catch (e) {
    print('ERROR: ${e.message}');
    exit(1);
  } catch (e) {
    print('ERROR: $e');
    exit(1);
  }
}

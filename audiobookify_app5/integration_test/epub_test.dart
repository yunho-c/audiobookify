// Simple integration test for EPUB loading API
// This test loads a sample EPUB and verifies basic functionality

import 'dart:io';
import 'package:audiobookify_app5/src/rust/api/epub.dart';
import 'package:audiobookify_app5/src/rust/frb_generated.dart';

Future<void> main() async {
  // Initialize flutter_rust_bridge
  await RustLib.init();

  print('=== EPUB Integration Test ===\n');

  // Path to test EPUB file (use absolute path for macOS sandbox compatibility)
  final epubPath =
      '/Users/yunhocho/GitHub/audiobookify/audiobookify_app5/test_ebook.epub';

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

    // Print chapter count
    final chapterCount = getChapterCount(book: book);
    print('--- Chapters ---');
    print('Total chapters: $chapterCount');
    print('');

    // Print first few TOC entries
    final toc = getToc(book: book);
    print('--- Table of Contents (first 5 entries) ---');
    for (var i = 0; i < toc.length && i < 5; i++) {
      print('  ${i + 1}. ${toc[i].title}');
    }
    print('');

    // Check cover image
    final cover = getCover(book: book);
    if (cover != null) {
      print('--- Cover Image ---');
      print('Cover image size: ${cover.length} bytes');
    } else {
      print('--- Cover Image ---');
      print('No cover image found');
    }
    print('');

    // Read first chapter content (just a preview)
    if (book.chapterContents.isNotEmpty) {
      print('--- First Chapter Preview ---');
      final content = book.chapterContents[0];
      final preview = content.length > 200
          ? '${content.substring(0, 200)}...'
          : content;
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

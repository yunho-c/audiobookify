import 'package:flutter_test/flutter_test.dart';

import 'package:audiobookify/reader/reader_ir.dart';
import 'package:audiobookify/reader/reader_segmentation.dart';

void main() {
  test('segments sentences while preserving inline styles', () {
    final doc = ReaderDocument(
      chapterHref: 'ch.xhtml',
      blocks: [
        ParagraphBlock([
          const TextInline('Hello '),
          const StrongInline([TextInline('world')]),
          const TextInline('. Second sentence.'),
        ]),
      ],
    );

    final segmented = segmentReaderDocument(doc);
    expect(segmented.ttsParagraphs.length, 1);
    final paragraph = segmented.ttsParagraphs.first;
    expect(paragraph.sentences.length, 2);
    expect(paragraph.sentences.first, 'Hello world.');

    final firstSentenceRuns = paragraph.sentenceRuns.first;
    final boldRun = firstSentenceRuns.firstWhere(
      (run) => run.style.bold,
      orElse: () => const TextRun('', TextRunStyle()),
    );
    expect(boldRun.text, 'world');
  });

  test('segments sup and sub runs', () {
    final doc = ReaderDocument(
      chapterHref: 'ch.xhtml',
      blocks: [
        ParagraphBlock([
          const TextInline('H'),
          const SubInline([TextInline('2')]),
          const TextInline('O is water.'),
        ]),
      ],
    );

    final segmented = segmentReaderDocument(doc);
    final paragraph = segmented.ttsParagraphs.first;
    final runs = paragraph.sentenceRuns.first;
    expect(runs.any((run) => run.style.sub), isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:audiobookify/reader/reader_dto_adapter.dart';
import 'package:audiobookify/reader/reader_ir.dart';
import 'package:audiobookify/src/rust/api/epub.dart' as rust_epub;

void main() {
  test('adaptReaderDocument converts semantic blocks', () {
    final document = rust_epub.ReaderDocument(
      chapterHref: 'OEBPS/Text/ch1.xhtml',
      blocks: [
        rust_epub.ReaderBlock(
          kind: rust_epub.ReaderBlockKind.heading,
          level: 1,
          ordered: false,
          inlines: const [
            rust_epub.ReaderInline(
              kind: rust_epub.ReaderInlineKind.text,
              text: 'Chapter One',
              styleHints: [],
              children: [],
            ),
          ],
          blocks: const [],
          items: const [],
          rows: const [],
        ),
        rust_epub.ReaderBlock(
          kind: rust_epub.ReaderBlockKind.paragraph,
          level: 0,
          ordered: false,
          inlines: const [
            rust_epub.ReaderInline(
              kind: rust_epub.ReaderInlineKind.text,
              text: 'This is ',
              styleHints: [],
              children: [],
            ),
            rust_epub.ReaderInline(
              kind: rust_epub.ReaderInlineKind.emphasis,
              styleHints: [],
              children: [
                rust_epub.ReaderInline(
                  kind: rust_epub.ReaderInlineKind.text,
                  text: 'italic',
                  styleHints: [],
                  children: [],
                ),
              ],
            ),
          ],
          blocks: const [],
          items: const [],
          rows: const [],
        ),
        rust_epub.ReaderBlock(
          kind: rust_epub.ReaderBlockKind.image,
          level: 0,
          ordered: false,
          inlines: const [],
          blocks: const [],
          items: const [],
          src: 'OEBPS/images/pic.png',
          alt: 'Pic',
          caption: 'Figure caption',
          rows: const [],
        ),
        rust_epub.ReaderBlock(
          kind: rust_epub.ReaderBlockKind.list,
          level: 0,
          ordered: false,
          inlines: const [],
          blocks: const [],
          items: const [
            rust_epub.ListItem(
              blocks: [
                rust_epub.ReaderBlock(
                  kind: rust_epub.ReaderBlockKind.paragraph,
                  level: 0,
                  ordered: false,
                  inlines: [
                    rust_epub.ReaderInline(
                      kind: rust_epub.ReaderInlineKind.text,
                      text: 'First item',
                      styleHints: [],
                      children: [],
                    ),
                  ],
                  blocks: [],
                  items: [],
                  rows: [],
                ),
              ],
            ),
          ],
          rows: const [],
        ),
        rust_epub.ReaderBlock(
          kind: rust_epub.ReaderBlockKind.table,
          level: 0,
          ordered: false,
          inlines: const [],
          blocks: const [],
          items: const [],
          rows: const [
            rust_epub.TableRow(
              cells: [
                rust_epub.TableCell(
                  isHeader: true,
                  inlines: [
                    rust_epub.ReaderInline(
                      kind: rust_epub.ReaderInlineKind.text,
                      text: 'Header',
                      styleHints: [],
                      children: [],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final adapted = adaptReaderDocument(document);

    expect(adapted.blocks.whereType<HeadingBlock>().length, 1);
    expect(adapted.blocks.whereType<ParagraphBlock>().length, 1);
    expect(adapted.blocks.whereType<ImageBlock>().length, 1);
    expect(adapted.blocks.whereType<ListBlock>().length, 1);
    expect(adapted.blocks.whereType<TableBlock>().length, 1);

    final image = adapted.blocks.whereType<ImageBlock>().first;
    expect(image.src, 'OEBPS/images/pic.png');
    expect(image.caption, 'Figure caption');
  });

  test('adaptReaderDocument maps span style hints', () {
    final document = rust_epub.ReaderDocument(
      chapterHref: 'ch.xhtml',
      blocks: const [
        rust_epub.ReaderBlock(
          kind: rust_epub.ReaderBlockKind.paragraph,
          level: 0,
          ordered: false,
          inlines: [
            rust_epub.ReaderInline(
              kind: rust_epub.ReaderInlineKind.span,
              styleHints: [
                rust_epub.SpanStyleHint.italic,
                rust_epub.SpanStyleHint.bold,
              ],
              children: [
                rust_epub.ReaderInline(
                  kind: rust_epub.ReaderInlineKind.text,
                  text: 'Text',
                  styleHints: [],
                  children: [],
                ),
              ],
            ),
          ],
          blocks: [],
          items: [],
          rows: [],
        ),
      ],
    );

    final adapted = adaptReaderDocument(document);
    final paragraph = adapted.blocks.whereType<ParagraphBlock>().first;
    final span = paragraph.inlines.whereType<SpanInline>().first;
    expect(span.styleHints.contains(SpanStyleHint.italic), isTrue);
    expect(span.styleHints.contains(SpanStyleHint.bold), isTrue);
  });
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:audiobookify/reader/reader_dto_adapter.dart';
import 'package:audiobookify/reader/reader_ir.dart';
import 'package:audiobookify/src/rust/api/epub.dart' as rust_epub;

void main() {
  test('adaptReaderDocument converts semantic blocks and resources', () {
    final document = rust_epub.ReaderDocument(
      chapterHref: 'OEBPS/Text/ch1.xhtml',
      blocks: [
        _headingBlock(
          inlines: [
            _textInline(
              'Chapter One',
              href: 'OEBPS/Text/ch1.xhtml',
              fragment: 'heading-1',
            ),
          ],
          fragment: 'heading-1',
        ),
        _paragraphBlock(
          inlines: [
            _textInline('This is '),
            rust_epub.ReaderInline(
              kind: rust_epub.ReaderInlineKind.span,
              styleHints: const [rust_epub.SpanStyleHint.italic],
              children: [_textInline('italic')],
              source: _source(),
            ),
          ],
        ),
        rust_epub.ReaderBlock(
          kind: rust_epub.ReaderBlockKind.image,
          level: 0,
          ordered: false,
          inlines: const [],
          blocks: const [],
          items: const [],
          resource: const rust_epub.ResourceRef(
            href: 'OEBPS/images/pic.png',
            mediaType: 'image/png',
            kind: rust_epub.ResourceKind.image,
          ),
          alt: 'Pic',
          caption: 'Figure caption',
          rows: const [],
          source: _source(href: 'OEBPS/Text/ch1.xhtml', fragment: 'fig-1'),
        ),
        rust_epub.ReaderBlock(
          kind: rust_epub.ReaderBlockKind.list,
          level: 0,
          ordered: false,
          inlines: const [],
          blocks: const [],
          items: [
            rust_epub.ListItem(
              blocks: [
                _paragraphBlock(
                  inlines: [_textInline('First item')],
                ),
              ],
              source: _source(fragment: 'list-item-1'),
            ),
          ],
          rows: const [],
          source: _source(fragment: 'list-1'),
        ),
        rust_epub.ReaderBlock(
          kind: rust_epub.ReaderBlockKind.table,
          level: 0,
          ordered: false,
          inlines: const [],
          blocks: const [],
          items: const [],
          rows: [
            rust_epub.TableRow(
              cells: [
                rust_epub.TableCell(
                  isHeader: true,
                  inlines: [_textInline('Header')],
                  source: _source(fragment: 'cell-1'),
                ),
              ],
              source: _source(fragment: 'row-1'),
            ),
          ],
          source: _source(fragment: 'table-1'),
        ),
      ],
    );

    final adapted = adaptReaderDocument(document);

    expect(adapted.blocks.whereType<HeadingBlock>().length, 1);
    expect(adapted.blocks.whereType<ParagraphBlock>().length, 1);
    expect(adapted.blocks.whereType<ImageBlock>().length, 1);
    expect(adapted.blocks.whereType<ListBlock>().length, 1);
    expect(adapted.blocks.whereType<TableBlock>().length, 1);

    final heading = adapted.blocks.whereType<HeadingBlock>().first;
    expect(heading.source?.fragment, 'heading-1');

    final image = adapted.blocks.whereType<ImageBlock>().first;
    expect(image.resource.href, 'OEBPS/images/pic.png');
    expect(image.resource.kind, ReaderResourceKind.image);
    expect(image.caption, 'Figure caption');
    expect(image.source?.fragment, 'fig-1');
  });

  test('adaptReaderDocument maps span hints, link targets, and source maps', () {
    final document = rust_epub.ReaderDocument(
      chapterHref: 'ch.xhtml',
      blocks: [
        _paragraphBlock(
          inlines: [
            rust_epub.ReaderInline(
              kind: rust_epub.ReaderInlineKind.span,
              styleHints: const [
                rust_epub.SpanStyleHint.italic,
                rust_epub.SpanStyleHint.bold,
                rust_epub.SpanStyleHint.code,
              ],
              children: [
                rust_epub.ReaderInline(
                  kind: rust_epub.ReaderInlineKind.link,
                  target: const rust_epub.LinkTarget(
                    kind: rust_epub.LinkTargetKind.internal,
                    href: 'ch2.xhtml#next',
                    sectionId: 'section-2',
                    sectionIndex: 1,
                    fragment: 'next',
                  ),
                  styleHints: const [],
                  children: [_textInline('Next chapter', fragment: 'next')],
                  source: _source(fragment: 'link-1'),
                ),
              ],
              source: _source(fragment: 'span-1'),
            ),
          ],
          fragment: 'para-1',
        ),
      ],
    );

    final adapted = adaptReaderDocument(document);
    final paragraph = adapted.blocks.whereType<ParagraphBlock>().first;
    final span = paragraph.inlines.whereType<SpanInline>().first;
    final link = span.children.whereType<LinkInline>().first;

    expect(span.styleHints, containsAll(<SpanStyleHint>[
      SpanStyleHint.italic,
      SpanStyleHint.bold,
      SpanStyleHint.code,
    ]));
    expect(span.source?.fragment, 'span-1');

    expect(link.target.kind, ReaderLinkTargetKind.internal);
    expect(link.target.href, 'ch2.xhtml#next');
    expect(link.target.sectionId, 'section-2');
    expect(link.target.sectionIndex, 1);
    expect(link.target.fragment, 'next');
    expect(link.source?.fragment, 'link-1');
  });
}

rust_epub.ReaderBlock _headingBlock({
  required List<rust_epub.ReaderInline> inlines,
  String? fragment,
}) {
  return rust_epub.ReaderBlock(
    kind: rust_epub.ReaderBlockKind.heading,
    level: 1,
    ordered: false,
    inlines: inlines,
    blocks: const [],
    items: const [],
    rows: const [],
    source: _source(fragment: fragment),
  );
}

rust_epub.ReaderBlock _paragraphBlock({
  required List<rust_epub.ReaderInline> inlines,
  String? fragment,
}) {
  return rust_epub.ReaderBlock(
    kind: rust_epub.ReaderBlockKind.paragraph,
    level: 0,
    ordered: false,
    inlines: inlines,
    blocks: const [],
    items: const [],
    rows: const [],
    source: _source(fragment: fragment),
  );
}

rust_epub.ReaderInline _textInline(
  String text, {
  String href = 'OEBPS/Text/ch1.xhtml',
  String? fragment,
}) {
  return rust_epub.ReaderInline(
    kind: rust_epub.ReaderInlineKind.text,
    text: text,
    styleHints: const [],
    children: const [],
    source: _source(href: href, fragment: fragment),
  );
}

rust_epub.SourceMap _source({
  int spineIndex = 0,
  String href = 'OEBPS/Text/ch1.xhtml',
  String? fragment,
  List<int> nodePath = const [],
}) {
  return rust_epub.SourceMap(
    spineIndex: spineIndex,
    href: href,
    fragment: fragment,
    nodePath: Int32List.fromList(nodePath),
  );
}

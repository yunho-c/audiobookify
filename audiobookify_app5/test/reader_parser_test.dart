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
          alignment: rust_epub.BlockAlignment.right,
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
          presentation: const rust_epub.ImagePresentation(
            height: rust_epub.ImageLength(
              valueMilli: 1000,
              unit: rust_epub.ImageLengthUnit.em,
            ),
            maxWidth: rust_epub.ImageLength(
              valueMilli: 40000,
              unit: rust_epub.ImageLengthUnit.percent,
            ),
          ),
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
                _paragraphBlock(inlines: [_textInline('First item')]),
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
    expect(heading.alignment, ReaderBlockAlignment.right);

    final image = adapted.blocks.whereType<ImageBlock>().first;
    expect(image.resource.href, 'OEBPS/images/pic.png');
    expect(image.resource.kind, ReaderResourceKind.image);
    expect(image.caption, 'Figure caption');
    expect(image.presentation?.height?.valueMilli, 1000);
    expect(image.presentation?.height?.unit, ReaderImageLengthUnit.em);
    expect(image.presentation?.maxWidth?.valueMilli, 40000);
    expect(image.presentation?.maxWidth?.unit, ReaderImageLengthUnit.percent);
    expect(image.source?.fragment, 'fig-1');
  });

  test(
    'adaptReaderDocument maps span hints, link targets, and source maps',
    () {
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

      expect(
        span.styleHints,
        containsAll(<SpanStyleHint>[
          SpanStyleHint.italic,
          SpanStyleHint.bold,
          SpanStyleHint.code,
        ]),
      );
      expect(span.source?.fragment, 'span-1');

      expect(link.target.kind, ReaderLinkTargetKind.internal);
      expect(link.target.href, 'ch2.xhtml#next');
      expect(link.target.sectionId, 'section-2');
      expect(link.target.sectionIndex, 1);
      expect(link.target.fragment, 'next');
      expect(link.source?.fragment, 'link-1');
    },
  );

  test(
    'adaptReaderDocument maps inline image presentation and drops empty data',
    () {
      final document = rust_epub.ReaderDocument(
        chapterHref: 'ch.xhtml',
        blocks: [
          _paragraphBlock(
            inlines: [
              rust_epub.ReaderInline(
                kind: rust_epub.ReaderInlineKind.image,
                resource: const rust_epub.ResourceRef(
                  href: 'images/logo.png',
                  mediaType: 'image/png',
                  kind: rust_epub.ResourceKind.image,
                ),
                alt: 'Logo',
                presentation: const rust_epub.ImagePresentation(
                  width: rust_epub.ImageLength(
                    valueMilli: 24000,
                    unit: rust_epub.ImageLengthUnit.px,
                  ),
                ),
                styleHints: const [],
                children: const [],
                source: _source(fragment: 'inline-logo'),
              ),
              rust_epub.ReaderInline(
                kind: rust_epub.ReaderInlineKind.image,
                resource: const rust_epub.ResourceRef(
                  href: 'images/plain.png',
                  mediaType: 'image/png',
                  kind: rust_epub.ResourceKind.image,
                ),
                alt: 'Plain',
                presentation: const rust_epub.ImagePresentation(),
                styleHints: const [],
                children: const [],
                source: _source(fragment: 'inline-plain'),
              ),
            ],
          ),
        ],
      );

      final adapted = adaptReaderDocument(document);
      final paragraph = adapted.blocks.whereType<ParagraphBlock>().first;
      final logo = paragraph.inlines.first as InlineImage;
      final plain = paragraph.inlines.last as InlineImage;

      expect(logo.presentation?.width?.valueMilli, 24000);
      expect(logo.presentation?.width?.unit, ReaderImageLengthUnit.px);
      expect(logo.source?.fragment, 'inline-logo');

      expect(plain.presentation, isNull);
      expect(plain.source?.fragment, 'inline-plain');
    },
  );

  test(
    'adaptReaderDocument maps block alignment for paragraph and heading',
    () {
      final document = rust_epub.ReaderDocument(
        chapterHref: 'ch.xhtml',
        blocks: [
          _headingBlock(
            inlines: [_textInline('Heading')],
            alignment: rust_epub.BlockAlignment.right,
          ),
          _paragraphBlock(
            inlines: [_textInline('Centered body')],
            alignment: rust_epub.BlockAlignment.center,
          ),
        ],
      );

      final adapted = adaptReaderDocument(document);
      final heading = adapted.blocks.whereType<HeadingBlock>().first;
      final paragraph = adapted.blocks.whereType<ParagraphBlock>().first;

      expect(heading.alignment, ReaderBlockAlignment.right);
      expect(paragraph.alignment, ReaderBlockAlignment.center);
    },
  );

  test('adaptReaderDocument preserves recovered heading blocks', () {
    final document = rust_epub.ReaderDocument(
      chapterHref: 'ch.xhtml',
      blocks: [
        _headingBlock(
          level: 1,
          inlines: [
            _textInline('Recovered Chapter Title', fragment: 'recovered-h1'),
          ],
          fragment: 'recovered-h1',
        ),
        _paragraphBlock(inlines: [_textInline('Body paragraph.')]),
      ],
    );

    final adapted = adaptReaderDocument(document);
    final heading = adapted.blocks.whereType<HeadingBlock>().single;

    expect(heading.level, 1);
    expect(
      heading.inlines.whereType<TextInline>().single.text,
      'Recovered Chapter Title',
    );
    expect(heading.source?.fragment, 'recovered-h1');
  });

  test(
    'adaptReaderDocument preserves recovered level-three heading blocks',
    () {
      final document = rust_epub.ReaderDocument(
        chapterHref: 'ch.xhtml',
        blocks: [
          _headingBlock(
            level: 3,
            inlines: [
              _textInline('The Deeper Problem', fragment: 'recovered-h3'),
            ],
            fragment: 'recovered-h3',
          ),
          _paragraphBlock(inlines: [_textInline('Body paragraph.')]),
        ],
      );

      final adapted = adaptReaderDocument(document);
      final heading = adapted.blocks.whereType<HeadingBlock>().single;

      expect(heading.level, 3);
      expect(
        heading.inlines.whereType<TextInline>().single.text,
        'The Deeper Problem',
      );
      expect(heading.source?.fragment, 'recovered-h3');
    },
  );
}

rust_epub.ReaderBlock _headingBlock({
  required List<rust_epub.ReaderInline> inlines,
  int level = 1,
  String? fragment,
  rust_epub.BlockAlignment? alignment,
}) {
  return rust_epub.ReaderBlock(
    kind: rust_epub.ReaderBlockKind.heading,
    level: level,
    alignment: alignment,
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
  rust_epub.BlockAlignment? alignment,
}) {
  return rust_epub.ReaderBlock(
    kind: rust_epub.ReaderBlockKind.paragraph,
    level: 0,
    alignment: alignment,
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

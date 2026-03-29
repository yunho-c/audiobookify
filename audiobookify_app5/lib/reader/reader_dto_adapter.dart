import '../src/rust/api/epub.dart' as rust_epub;
import 'reader_ir.dart';

ReaderDocument adaptReaderDocument(rust_epub.ReaderDocument document) {
  return ReaderDocument(
    chapterHref: document.chapterHref,
    blocks: document.blocks.map(adaptReaderBlock).toList(),
  );
}

ReaderBlock adaptReaderBlock(rust_epub.ReaderBlock block) {
  switch (block.kind) {
    case rust_epub.ReaderBlockKind.paragraph:
      return ParagraphBlock(block.inlines.map(adaptReaderInline).toList());
    case rust_epub.ReaderBlockKind.heading:
      return HeadingBlock(
        level: block.level.clamp(1, 6),
        inlines: block.inlines.map(adaptReaderInline).toList(),
      );
    case rust_epub.ReaderBlockKind.blockQuote:
      return BlockQuoteBlock(block.blocks.map(adaptReaderBlock).toList());
    case rust_epub.ReaderBlockKind.list:
      return ListBlock(
        ordered: block.ordered,
        items:
            block.items
                .map((item) => ListItemBlock(item.blocks.map(adaptReaderBlock).toList()))
                .toList(),
      );
    case rust_epub.ReaderBlockKind.listItem:
      return ListItemBlock(block.blocks.map(adaptReaderBlock).toList());
    case rust_epub.ReaderBlockKind.image:
      return ImageBlock(
        src: block.src ?? '',
        alt: block.alt,
        caption: block.caption,
      );
    case rust_epub.ReaderBlockKind.table:
      return TableBlock(
        rows:
            block.rows
                .map(
                  (row) => TableRowBlock(
                    cells:
                        row.cells
                            .map(
                              (cell) => TableCellBlock(
                                isHeader: cell.isHeader,
                                inlines:
                                    cell.inlines.map(adaptReaderInline).toList(),
                              ),
                            )
                            .toList(),
                  ),
                )
                .toList(),
      );
    case rust_epub.ReaderBlockKind.horizontalRule:
      return const HorizontalRuleBlock();
  }
}

ReaderInline adaptReaderInline(rust_epub.ReaderInline inline) {
  switch (inline.kind) {
    case rust_epub.ReaderInlineKind.text:
      return TextInline(inline.text ?? '');
    case rust_epub.ReaderInlineKind.emphasis:
      return EmphasisInline(inline.children.map(adaptReaderInline).toList());
    case rust_epub.ReaderInlineKind.strong:
      return StrongInline(inline.children.map(adaptReaderInline).toList());
    case rust_epub.ReaderInlineKind.sup:
      return SupInline(inline.children.map(adaptReaderInline).toList());
    case rust_epub.ReaderInlineKind.sub:
      return SubInline(inline.children.map(adaptReaderInline).toList());
    case rust_epub.ReaderInlineKind.link:
      return LinkInline(
        href: inline.href ?? '',
        children: inline.children.map(adaptReaderInline).toList(),
      );
    case rust_epub.ReaderInlineKind.lineBreak:
      return const LineBreakInline();
    case rust_epub.ReaderInlineKind.span:
      return SpanInline(
        styleHints: inline.styleHints.map(adaptSpanStyleHint).toSet(),
        children: inline.children.map(adaptReaderInline).toList(),
      );
  }
}

SpanStyleHint adaptSpanStyleHint(rust_epub.SpanStyleHint hint) {
  switch (hint) {
    case rust_epub.SpanStyleHint.italic:
      return SpanStyleHint.italic;
    case rust_epub.SpanStyleHint.bold:
      return SpanStyleHint.bold;
    case rust_epub.SpanStyleHint.underline:
      return SpanStyleHint.underline;
  }
}

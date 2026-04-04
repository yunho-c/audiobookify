import '../src/rust/api/epub.dart' as rust_epub;
import 'reader_ir.dart';

ReaderDocument adaptReaderDocument(rust_epub.ReaderDocument document) {
  return ReaderDocument(
    chapterHref: document.chapterHref,
    blocks: document.blocks.map(adaptReaderBlock).toList(),
  );
}

ReaderBlock adaptReaderBlock(rust_epub.ReaderBlock block) {
  final source = adaptSourceMap(block.source);
  switch (block.kind) {
    case rust_epub.ReaderBlockKind.paragraph:
      return ParagraphBlock(
        block.inlines.map(adaptReaderInline).toList(),
        source: source,
      );
    case rust_epub.ReaderBlockKind.heading:
      return HeadingBlock(
        level: block.level.clamp(1, 6),
        inlines: block.inlines.map(adaptReaderInline).toList(),
        source: source,
      );
    case rust_epub.ReaderBlockKind.blockQuote:
      return BlockQuoteBlock(
        block.blocks.map(adaptReaderBlock).toList(),
        source: source,
      );
    case rust_epub.ReaderBlockKind.list:
      return ListBlock(
        ordered: block.ordered,
        items: block.items.map(adaptListItem).toList(),
        source: source,
      );
    case rust_epub.ReaderBlockKind.listItem:
      return ListItemBlock(
        block.blocks.map(adaptReaderBlock).toList(),
        source: source,
      );
    case rust_epub.ReaderBlockKind.image:
      return ImageBlock(
        resource: adaptResourceRef(block.resource!),
        alt: block.alt,
        caption: block.caption,
        presentation: adaptImagePresentation(block.presentation),
        source: source,
      );
    case rust_epub.ReaderBlockKind.table:
      return TableBlock(
        rows: block.rows.map(adaptTableRow).toList(),
        source: source,
      );
    case rust_epub.ReaderBlockKind.horizontalRule:
      return HorizontalRuleBlock(source: source);
    case rust_epub.ReaderBlockKind.code:
      return CodeBlock(text: block.codeText ?? '', source: source);
  }
}

ListItemBlock adaptListItem(rust_epub.ListItem item) {
  return ListItemBlock(
    item.blocks.map(adaptReaderBlock).toList(),
    source: adaptSourceMap(item.source),
  );
}

TableRowBlock adaptTableRow(rust_epub.TableRow row) {
  return TableRowBlock(
    cells: row.cells.map(adaptTableCell).toList(),
    source: adaptSourceMap(row.source),
  );
}

TableCellBlock adaptTableCell(rust_epub.TableCell cell) {
  return TableCellBlock(
    isHeader: cell.isHeader,
    inlines: cell.inlines.map(adaptReaderInline).toList(),
    source: adaptSourceMap(cell.source),
  );
}

ReaderInline adaptReaderInline(rust_epub.ReaderInline inline) {
  final source = adaptSourceMap(inline.source);
  switch (inline.kind) {
    case rust_epub.ReaderInlineKind.text:
      return TextInline(inline.text ?? '', source: source);
    case rust_epub.ReaderInlineKind.span:
      return SpanInline(
        styleHints: inline.styleHints.map(adaptSpanStyleHint).toSet(),
        children: inline.children.map(adaptReaderInline).toList(),
        source: source,
      );
    case rust_epub.ReaderInlineKind.link:
      return LinkInline(
        target: adaptLinkTarget(inline.target!),
        children: inline.children.map(adaptReaderInline).toList(),
        source: source,
      );
    case rust_epub.ReaderInlineKind.image:
      return InlineImage(
        resource: adaptResourceRef(inline.resource!),
        alt: inline.alt,
        presentation: adaptImagePresentation(inline.presentation),
        source: source,
      );
    case rust_epub.ReaderInlineKind.lineBreak:
      return LineBreakInline(source: source);
  }
}

ReaderLinkTarget adaptLinkTarget(rust_epub.LinkTarget target) {
  return ReaderLinkTarget(
    kind: adaptLinkTargetKind(target.kind),
    href: target.href,
    sectionId: target.sectionId,
    sectionIndex: target.sectionIndex,
    fragment: target.fragment,
  );
}

ReaderLinkTargetKind adaptLinkTargetKind(rust_epub.LinkTargetKind kind) {
  switch (kind) {
    case rust_epub.LinkTargetKind.internal:
      return ReaderLinkTargetKind.internal;
    case rust_epub.LinkTargetKind.external_:
      return ReaderLinkTargetKind.external;
    case rust_epub.LinkTargetKind.unresolved:
      return ReaderLinkTargetKind.unresolved;
  }
}

ReaderResourceRef adaptResourceRef(rust_epub.ResourceRef resource) {
  return ReaderResourceRef(
    href: resource.href,
    mediaType: resource.mediaType,
    kind: adaptResourceKind(resource.kind),
  );
}

ReaderResourceKind adaptResourceKind(rust_epub.ResourceKind kind) {
  switch (kind) {
    case rust_epub.ResourceKind.image:
      return ReaderResourceKind.image;
    case rust_epub.ResourceKind.stylesheet:
      return ReaderResourceKind.stylesheet;
    case rust_epub.ResourceKind.cover:
      return ReaderResourceKind.cover;
    case rust_epub.ResourceKind.other:
      return ReaderResourceKind.other;
  }
}

ReaderSourceMap adaptSourceMap(rust_epub.SourceMap source) {
  return ReaderSourceMap(
    spineIndex: source.spineIndex,
    href: source.href,
    fragment: source.fragment,
    nodePath: source.nodePath,
  );
}

ReaderImagePresentation? adaptImagePresentation(
  rust_epub.ImagePresentation? presentation,
) {
  if (presentation == null) {
    return null;
  }
  final adapted = ReaderImagePresentation(
    width: adaptImageLength(presentation.width),
    height: adaptImageLength(presentation.height),
    maxWidth: adaptImageLength(presentation.maxWidth),
    maxHeight: adaptImageLength(presentation.maxHeight),
  );
  return adapted.isEmpty ? null : adapted;
}

ReaderImageLength? adaptImageLength(rust_epub.ImageLength? length) {
  if (length == null) {
    return null;
  }
  return ReaderImageLength(
    valueMilli: length.valueMilli,
    unit: adaptImageLengthUnit(length.unit),
  );
}

ReaderImageLengthUnit adaptImageLengthUnit(rust_epub.ImageLengthUnit unit) {
  switch (unit) {
    case rust_epub.ImageLengthUnit.percent:
      return ReaderImageLengthUnit.percent;
    case rust_epub.ImageLengthUnit.px:
      return ReaderImageLengthUnit.px;
    case rust_epub.ImageLengthUnit.em:
      return ReaderImageLengthUnit.em;
    case rust_epub.ImageLengthUnit.rem:
      return ReaderImageLengthUnit.rem;
    case rust_epub.ImageLengthUnit.auto:
      return ReaderImageLengthUnit.auto;
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
    case rust_epub.SpanStyleHint.superscript:
      return SpanStyleHint.superscript;
    case rust_epub.SpanStyleHint.subscript:
      return SpanStyleHint.subscript;
    case rust_epub.SpanStyleHint.code:
      return SpanStyleHint.code;
  }
}

import 'package:flutter/foundation.dart';

@immutable
abstract class ReaderBlock {
  const ReaderBlock();
}

@immutable
class ReaderDocument {
  final List<ReaderBlock> blocks;
  final String chapterHref;

  const ReaderDocument({
    required this.blocks,
    required this.chapterHref,
  });
}

@immutable
class ParagraphBlock extends ReaderBlock {
  final List<ReaderInline> inlines;

  const ParagraphBlock(this.inlines);
}

@immutable
class HeadingBlock extends ReaderBlock {
  final int level;
  final List<ReaderInline> inlines;

  const HeadingBlock({
    required this.level,
    required this.inlines,
  });
}

@immutable
class BlockQuoteBlock extends ReaderBlock {
  final List<ReaderBlock> blocks;

  const BlockQuoteBlock(this.blocks);
}

@immutable
class ListBlock extends ReaderBlock {
  final bool ordered;
  final List<ListItemBlock> items;

  const ListBlock({
    required this.ordered,
    required this.items,
  });
}

@immutable
class ListItemBlock extends ReaderBlock {
  final List<ReaderBlock> blocks;

  const ListItemBlock(this.blocks);
}

@immutable
class ImageBlock extends ReaderBlock {
  final String src;
  final String? alt;
  final String? caption;

  const ImageBlock({
    required this.src,
    this.alt,
    this.caption,
  });
}

@immutable
class TableBlock extends ReaderBlock {
  final List<TableRowBlock> rows;

  const TableBlock({required this.rows});
}

@immutable
class TableRowBlock {
  final List<TableCellBlock> cells;

  const TableRowBlock({required this.cells});
}

@immutable
class TableCellBlock {
  final bool isHeader;
  final List<ReaderInline> inlines;

  const TableCellBlock({
    required this.isHeader,
    required this.inlines,
  });
}

@immutable
class HorizontalRuleBlock extends ReaderBlock {
  const HorizontalRuleBlock();
}

@immutable
abstract class ReaderInline {
  const ReaderInline();
}

@immutable
class TextInline extends ReaderInline {
  final String text;

  const TextInline(this.text);
}

@immutable
class EmphasisInline extends ReaderInline {
  final List<ReaderInline> children;

  const EmphasisInline(this.children);
}

@immutable
class StrongInline extends ReaderInline {
  final List<ReaderInline> children;

  const StrongInline(this.children);
}

@immutable
class SupInline extends ReaderInline {
  final List<ReaderInline> children;

  const SupInline(this.children);
}

@immutable
class SubInline extends ReaderInline {
  final List<ReaderInline> children;

  const SubInline(this.children);
}

@immutable
class LinkInline extends ReaderInline {
  final String href;
  final List<ReaderInline> children;

  const LinkInline({required this.href, required this.children});
}

@immutable
class LineBreakInline extends ReaderInline {
  const LineBreakInline();
}

enum SpanStyleHint { italic, bold, underline }

@immutable
class SpanInline extends ReaderInline {
  final Set<SpanStyleHint> styleHints;
  final List<ReaderInline> children;

  const SpanInline({
    required this.styleHints,
    required this.children,
  });
}

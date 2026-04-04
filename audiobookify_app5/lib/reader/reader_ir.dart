import 'package:flutter/foundation.dart';

enum ReaderResourceKind { image, stylesheet, cover, other }

@immutable
class ReaderResourceRef {
  final String href;
  final String? mediaType;
  final ReaderResourceKind kind;

  const ReaderResourceRef({
    required this.href,
    this.mediaType,
    required this.kind,
  });
}

enum ReaderLinkTargetKind { internal, external, unresolved }

@immutable
class ReaderLinkTarget {
  final ReaderLinkTargetKind kind;
  final String href;
  final String? sectionId;
  final int? sectionIndex;
  final String? fragment;

  const ReaderLinkTarget({
    required this.kind,
    required this.href,
    this.sectionId,
    this.sectionIndex,
    this.fragment,
  });

  bool get isInternal => kind == ReaderLinkTargetKind.internal;
  bool get isExternal => kind == ReaderLinkTargetKind.external;
  bool get isUnresolved => kind == ReaderLinkTargetKind.unresolved;
}

@immutable
class ReaderSourceMap {
  final int spineIndex;
  final String href;
  final String? fragment;
  final List<int> nodePath;

  const ReaderSourceMap({
    required this.spineIndex,
    required this.href,
    this.fragment,
    this.nodePath = const [],
  });
}

@immutable
abstract class ReaderBlock {
  final ReaderSourceMap? source;

  const ReaderBlock({this.source});
}

enum ReaderImageLengthUnit { percent, px, em, rem, auto }

@immutable
class ReaderImageLength {
  final int valueMilli;
  final ReaderImageLengthUnit unit;

  const ReaderImageLength({required this.valueMilli, required this.unit});

  double get value => valueMilli / 1000.0;
}

@immutable
class ReaderImagePresentation {
  final ReaderImageLength? width;
  final ReaderImageLength? height;
  final ReaderImageLength? maxWidth;
  final ReaderImageLength? maxHeight;

  const ReaderImagePresentation({
    this.width,
    this.height,
    this.maxWidth,
    this.maxHeight,
  });

  bool get isEmpty =>
      width == null && height == null && maxWidth == null && maxHeight == null;
}

@immutable
class ReaderDocument {
  final List<ReaderBlock> blocks;
  final String chapterHref;

  const ReaderDocument({required this.blocks, required this.chapterHref});
}

@immutable
class ParagraphBlock extends ReaderBlock {
  final List<ReaderInline> inlines;

  const ParagraphBlock(this.inlines, {super.source});
}

@immutable
class HeadingBlock extends ReaderBlock {
  final int level;
  final List<ReaderInline> inlines;

  const HeadingBlock({
    required this.level,
    required this.inlines,
    super.source,
  });
}

@immutable
class BlockQuoteBlock extends ReaderBlock {
  final List<ReaderBlock> blocks;

  const BlockQuoteBlock(this.blocks, {super.source});
}

@immutable
class ListBlock extends ReaderBlock {
  final bool ordered;
  final List<ListItemBlock> items;

  const ListBlock({required this.ordered, required this.items, super.source});
}

@immutable
class ListItemBlock extends ReaderBlock {
  final List<ReaderBlock> blocks;

  const ListItemBlock(this.blocks, {super.source});
}

@immutable
class ImageBlock extends ReaderBlock {
  final ReaderResourceRef resource;
  final String? alt;
  final String? caption;
  final ReaderImagePresentation? presentation;

  const ImageBlock({
    required this.resource,
    this.alt,
    this.caption,
    this.presentation,
    super.source,
  });

  String get src => resource.href;
}

@immutable
class TableBlock extends ReaderBlock {
  final List<TableRowBlock> rows;

  const TableBlock({required this.rows, super.source});
}

@immutable
class TableRowBlock {
  final List<TableCellBlock> cells;
  final ReaderSourceMap? source;

  const TableRowBlock({required this.cells, this.source});
}

@immutable
class TableCellBlock {
  final bool isHeader;
  final List<ReaderInline> inlines;
  final ReaderSourceMap? source;

  const TableCellBlock({
    required this.isHeader,
    required this.inlines,
    this.source,
  });
}

@immutable
class HorizontalRuleBlock extends ReaderBlock {
  const HorizontalRuleBlock({super.source});
}

@immutable
class CodeBlock extends ReaderBlock {
  final String text;

  const CodeBlock({required this.text, super.source});
}

@immutable
abstract class ReaderInline {
  final ReaderSourceMap? source;

  const ReaderInline({this.source});
}

@immutable
class TextInline extends ReaderInline {
  final String text;

  const TextInline(this.text, {super.source});
}

enum SpanStyleHint { italic, bold, underline, superscript, subscript, code }

@immutable
class SpanInline extends ReaderInline {
  final Set<SpanStyleHint> styleHints;
  final List<ReaderInline> children;

  const SpanInline({
    required this.styleHints,
    required this.children,
    super.source,
  });
}

@immutable
class LinkInline extends ReaderInline {
  final ReaderLinkTarget target;
  final List<ReaderInline> children;

  const LinkInline({
    required this.target,
    required this.children,
    super.source,
  });

  String get href => target.href;
}

@immutable
class InlineImage extends ReaderInline {
  final ReaderResourceRef resource;
  final String? alt;
  final ReaderImagePresentation? presentation;

  const InlineImage({
    required this.resource,
    this.alt,
    this.presentation,
    super.source,
  });
}

@immutable
class LineBreakInline extends ReaderInline {
  const LineBreakInline({super.source});
}

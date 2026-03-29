import 'reader_ir.dart';

class TextRunStyle {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool sup;
  final bool sub;
  final String? linkHref;

  const TextRunStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.sup = false,
    this.sub = false,
    this.linkHref,
  });

  TextRunStyle copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? sup,
    bool? sub,
    String? linkHref,
  }) {
    return TextRunStyle(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      sup: sup ?? this.sup,
      sub: sub ?? this.sub,
      linkHref: linkHref ?? this.linkHref,
    );
  }
}

class TextRun {
  final String text;
  final TextRunStyle style;

  const TextRun(this.text, this.style);
}

class ReaderTtsParagraph {
  final String plainText;
  final List<String> sentences;
  final List<List<TextRun>> sentenceRuns;

  const ReaderTtsParagraph({
    required this.plainText,
    required this.sentences,
    required this.sentenceRuns,
  });
}

class RenderBlockStyle {
  final int blockQuoteDepth;
  final int listDepth;
  final String? listMarker;

  const RenderBlockStyle({
    this.blockQuoteDepth = 0,
    this.listDepth = 0,
    this.listMarker,
  });

  RenderBlockStyle copyWith({
    int? blockQuoteDepth,
    int? listDepth,
    String? listMarker,
    bool clearListMarker = false,
  }) {
    return RenderBlockStyle(
      blockQuoteDepth: blockQuoteDepth ?? this.blockQuoteDepth,
      listDepth: listDepth ?? this.listDepth,
      listMarker:
          clearListMarker ? null : (listMarker ?? this.listMarker),
    );
  }
}

class ReaderRenderBlock {
  final ReaderBlock block;
  final RenderBlockStyle style;
  final int? ttsIndex;

  const ReaderRenderBlock({
    required this.block,
    required this.style,
    required this.ttsIndex,
  });
}

class ReaderSegmentedDocument {
  final List<ReaderRenderBlock> renderBlocks;
  final List<ReaderTtsParagraph> ttsParagraphs;
  final List<int> ttsIndexToBlockIndex;

  const ReaderSegmentedDocument({
    required this.renderBlocks,
    required this.ttsParagraphs,
    required this.ttsIndexToBlockIndex,
  });
}

ReaderSegmentedDocument segmentReaderDocument(ReaderDocument document) {
  final renderBlocks = <ReaderRenderBlock>[];
  final ttsParagraphs = <ReaderTtsParagraph>[];
  final ttsIndexToBlockIndex = <int>[];
  late void Function(ReaderBlock block, RenderBlockStyle style) visitBlock;

  void addReadableBlock(ReaderBlock block, RenderBlockStyle style) {
    final runs = flattenInlines(_extractInlines(block));
    final segments = _segmentRuns(runs);
    if (segments.isEmpty) {
      renderBlocks.add(
        ReaderRenderBlock(block: block, style: style, ttsIndex: null),
      );
      return;
    }

    final sentences = segments.map((segment) => segment.text).toList();
    final plainText = sentences.join(' ').trim();
    final paragraph = ReaderTtsParagraph(
      plainText: plainText,
      sentences: sentences,
      sentenceRuns: segments.map((segment) => segment.runs).toList(),
    );
    final ttsIndex = ttsParagraphs.length;
    ttsParagraphs.add(paragraph);
    ttsIndexToBlockIndex.add(renderBlocks.length);
    renderBlocks.add(
      ReaderRenderBlock(block: block, style: style, ttsIndex: ttsIndex),
    );
  }

  void _visitListItem(
    ListItemBlock item,
    RenderBlockStyle style,
    String marker,
  ) {
    final itemStyle = style.copyWith(listDepth: style.listDepth + 1);
    var markerApplied = false;
    for (final child in item.blocks) {
      if (child is ParagraphBlock || child is HeadingBlock) {
        final childStyle = markerApplied
            ? itemStyle.copyWith(clearListMarker: true)
            : itemStyle.copyWith(listMarker: marker);
        markerApplied = true;
        addReadableBlock(child, childStyle);
      } else if (child is BlockQuoteBlock) {
        visitBlock(child, itemStyle);
      } else if (child is ListBlock) {
        visitBlock(child, itemStyle);
      } else {
        final childStyle = markerApplied
            ? itemStyle.copyWith(clearListMarker: true)
            : itemStyle.copyWith(listMarker: marker);
        markerApplied = true;
        renderBlocks.add(
          ReaderRenderBlock(block: child, style: childStyle, ttsIndex: null),
        );
      }
    }
  }

  visitBlock = (ReaderBlock block, RenderBlockStyle style) {
    switch (block) {
      case ParagraphBlock():
      case HeadingBlock():
        addReadableBlock(block, style);
        break;
      case ImageBlock():
      case TableBlock():
      case HorizontalRuleBlock():
        renderBlocks.add(
          ReaderRenderBlock(block: block, style: style, ttsIndex: null),
        );
        break;
      case BlockQuoteBlock():
        final nextStyle = style.copyWith(
          blockQuoteDepth: style.blockQuoteDepth + 1,
        );
        for (final child in block.blocks) {
          visitBlock(child, nextStyle);
        }
        break;
      case ListBlock():
        for (var i = 0; i < block.items.length; i++) {
          final item = block.items[i];
          final marker = block.ordered ? '${i + 1}.' : '\u2022';
          _visitListItem(item, style, marker);
        }
        break;
      case ListItemBlock():
        _visitListItem(block, style, '\u2022');
        break;
      default:
        renderBlocks.add(
          ReaderRenderBlock(block: block, style: style, ttsIndex: null),
        );
        break;
    }
  };

  for (final block in document.blocks) {
    visitBlock(block, const RenderBlockStyle());
  }

  return ReaderSegmentedDocument(
    renderBlocks: renderBlocks,
    ttsParagraphs: ttsParagraphs,
    ttsIndexToBlockIndex: ttsIndexToBlockIndex,
  );
}

List<TextRun> flattenInlines(
  List<ReaderInline> inlines, {
  TextRunStyle style = const TextRunStyle(),
}) {
  final runs = <TextRun>[];
  for (final inline in inlines) {
    if (inline is TextInline) {
      if (inline.text.isNotEmpty) {
        runs.add(TextRun(inline.text, style));
      }
      continue;
    }
    if (inline is LineBreakInline) {
      runs.add(TextRun('\n', style));
      continue;
    }
    if (inline is EmphasisInline) {
      runs.addAll(
        flattenInlines(
          inline.children,
          style: style.copyWith(italic: true),
        ),
      );
      continue;
    }
    if (inline is StrongInline) {
      runs.addAll(
        flattenInlines(
          inline.children,
          style: style.copyWith(bold: true),
        ),
      );
      continue;
    }
    if (inline is SupInline) {
      runs.addAll(
        flattenInlines(
          inline.children,
          style: style.copyWith(sup: true, sub: false),
        ),
      );
      continue;
    }
    if (inline is SubInline) {
      runs.addAll(
        flattenInlines(
          inline.children,
          style: style.copyWith(sub: true, sup: false),
        ),
      );
      continue;
    }
    if (inline is LinkInline) {
      runs.addAll(
        flattenInlines(
          inline.children,
          style: style.copyWith(
            underline: true,
            linkHref: inline.href,
          ),
        ),
      );
      continue;
    }
    if (inline is SpanInline) {
      var nextStyle = style;
      if (inline.styleHints.contains(SpanStyleHint.italic)) {
        nextStyle = nextStyle.copyWith(italic: true);
      }
      if (inline.styleHints.contains(SpanStyleHint.bold)) {
        nextStyle = nextStyle.copyWith(bold: true);
      }
      if (inline.styleHints.contains(SpanStyleHint.underline)) {
        nextStyle = nextStyle.copyWith(underline: true);
      }
      runs.addAll(flattenInlines(inline.children, style: nextStyle));
      continue;
    }
  }
  return _mergeAdjacentRuns(runs);
}

List<TextRun> _mergeAdjacentRuns(List<TextRun> runs) {
  if (runs.length < 2) return runs;
  final merged = <TextRun>[];
  for (final run in runs) {
    if (merged.isEmpty) {
      merged.add(run);
      continue;
    }
    final last = merged.last;
    final sameStyle = _styleEquals(last.style, run.style);
    if (sameStyle) {
      merged[merged.length - 1] =
          TextRun('${last.text}${run.text}', last.style);
    } else {
      merged.add(run);
    }
  }
  return merged;
}

bool _styleEquals(TextRunStyle a, TextRunStyle b) {
  return a.bold == b.bold &&
      a.italic == b.italic &&
      a.underline == b.underline &&
      a.sup == b.sup &&
      a.sub == b.sub &&
      a.linkHref == b.linkHref;
}

class _Segment {
  final String text;
  final List<TextRun> runs;

  const _Segment({required this.text, required this.runs});
}

final RegExp _sentencePattern = RegExp(
  r'(?<!\b(?:Mr|Mrs|Ms|Dr|Prof|Sr|Jr|vs|etc|e\.g|i\.e))\s*[.!?]+\s+',
  caseSensitive: false,
);

List<_Segment> _segmentRuns(List<TextRun> runs) {
  if (runs.isEmpty) return const [];
  final fullText = runs.map((run) => run.text).join();
  if (fullText.trim().isEmpty) return const [];

  final segments = <_Segment>[];
  var cursor = 0;
  final matches = _sentencePattern.allMatches(fullText).toList();
  for (final match in matches) {
    final raw = fullText.substring(cursor, match.end);
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty) {
      final leading = raw.indexOf(trimmed);
      final start = cursor + leading;
      final end = start + trimmed.length;
      final sliced = _sliceRuns(runs, start, end);
      segments.add(_Segment(text: trimmed, runs: sliced));
    }
    cursor = match.end;
  }

  if (cursor < fullText.length) {
    final raw = fullText.substring(cursor);
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty) {
      final leading = raw.indexOf(trimmed);
      final start = cursor + leading;
      final end = start + trimmed.length;
      final sliced = _sliceRuns(runs, start, end);
      segments.add(_Segment(text: trimmed, runs: sliced));
    }
  }

  if (segments.isEmpty && fullText.trim().isNotEmpty) {
    segments.add(
      _Segment(
        text: fullText.trim(),
        runs: _sliceRuns(runs, 0, fullText.length),
      ),
    );
  }

  return segments;
}

List<TextRun> _sliceRuns(List<TextRun> runs, int start, int end) {
  if (start >= end) return const [];
  final sliced = <TextRun>[];
  var offset = 0;
  for (final run in runs) {
    final runStart = offset;
    final runEnd = offset + run.text.length;
    offset = runEnd;
    if (runEnd <= start) continue;
    if (runStart >= end) break;
    final sliceStart = start.clamp(runStart, runEnd) - runStart;
    final sliceEnd = end.clamp(runStart, runEnd) - runStart;
    final text = run.text.substring(sliceStart, sliceEnd);
    if (text.isNotEmpty) {
      sliced.add(TextRun(text, run.style));
    }
  }
  return _mergeAdjacentRuns(sliced);
}

List<ReaderInline> _extractInlines(ReaderBlock block) {
  if (block is ParagraphBlock) return block.inlines;
  if (block is HeadingBlock) return block.inlines;
  return const [];
}

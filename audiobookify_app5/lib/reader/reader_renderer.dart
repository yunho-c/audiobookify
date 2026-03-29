import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/player_theme_settings.dart';
import 'epub_resource_resolver.dart';
import 'reader_ir.dart';
import 'reader_segmentation.dart';

class ReaderRenderTheme {
  final PlayerThemeSettings readerTheme;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final Color shadowColor;
  final double paragraphSpacing;
  final double paragraphIndent;
  final PlayerThemeActiveParagraphStyle activeParagraphStyle;
  final double activeParagraphOpacity;
  final PlayerThemeSentenceHighlightStyle sentenceHighlightStyle;
  final double sentenceHighlightOpacity;

  const ReaderRenderTheme({
    required this.readerTheme,
    required this.textTheme,
    required this.colorScheme,
    required this.shadowColor,
    required this.paragraphSpacing,
    required this.paragraphIndent,
    required this.activeParagraphStyle,
    required this.activeParagraphOpacity,
    required this.sentenceHighlightStyle,
    required this.sentenceHighlightOpacity,
  });
}

class ReaderBlockRenderer {
  static Widget buildBlock({
    required ReaderRenderBlock renderBlock,
    required ReaderRenderTheme theme,
    required EpubResourceResolver resolver,
    required bool isActiveParagraph,
    required int activeSentenceIndex,
    required int previousSentenceIndex,
    required double transitionValue,
    required TapGestureRecognizer? Function(int sentenceIndex)?
        sentenceRecognizer,
    required VoidCallback? onTapParagraph,
    ReaderTtsParagraph? ttsData,
  }) {
    final block = renderBlock.block;
    if (block is ImageBlock) {
      return _buildImageBlock(block, theme, resolver, renderBlock.style);
    }
    if (block is TableBlock) {
      return _buildTableBlock(block, theme, renderBlock.style);
    }
    if (block is HorizontalRuleBlock) {
      return _buildDivider(theme, renderBlock.style);
    }
    if (block is ParagraphBlock) {
      return _buildTextBlock(
        inlines: block.inlines,
        headingLevel: null,
        renderBlock: renderBlock,
        theme: theme,
        isActiveParagraph: isActiveParagraph,
        activeSentenceIndex: activeSentenceIndex,
        previousSentenceIndex: previousSentenceIndex,
        transitionValue: transitionValue,
        sentenceRecognizer: sentenceRecognizer,
        onTapParagraph: onTapParagraph,
        ttsData: ttsData,
      );
    }
    if (block is HeadingBlock) {
      return _buildTextBlock(
        inlines: block.inlines,
        headingLevel: block.level,
        renderBlock: renderBlock,
        theme: theme,
        isActiveParagraph: isActiveParagraph,
        activeSentenceIndex: activeSentenceIndex,
        previousSentenceIndex: previousSentenceIndex,
        transitionValue: transitionValue,
        sentenceRecognizer: sentenceRecognizer,
        onTapParagraph: onTapParagraph,
        ttsData: ttsData,
      );
    }

    return const SizedBox.shrink();
  }

  static Widget _buildDivider(
    ReaderRenderTheme theme,
    RenderBlockStyle style,
  ) {
    final indent = _indentForStyle(theme, style);
    return Padding(
      padding: EdgeInsets.fromLTRB(indent, 12, 0, 12),
      child: Divider(color: theme.colorScheme.outlineVariant),
    );
  }

  static Widget _buildImageBlock(
    ImageBlock block,
    ReaderRenderTheme theme,
    EpubResourceResolver resolver,
    RenderBlockStyle style,
  ) {
    final indent = _indentForStyle(theme, style);
    return Padding(
      padding: EdgeInsets.fromLTRB(indent, 12, 0, 12),
      child: FutureBuilder<Uint8List?>(
        future: resolver.loadImage(block.src),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _imagePlaceholder(theme, block.caption);
          }
          final data = snapshot.data;
          if (data == null) {
            return _imagePlaceholder(theme, block.caption ?? block.alt);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  data,
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              ),
              if ((block.caption ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    block.caption!.trim(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static Widget _imagePlaceholder(
    ReaderRenderTheme theme,
    String? caption,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.image_outlined, color: theme.colorScheme.onSurfaceVariant),
          if (caption != null && caption.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              caption.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildTableBlock(
    TableBlock block,
    ReaderRenderTheme theme,
    RenderBlockStyle style,
  ) {
    final indent = _indentForStyle(theme, style);
    return Padding(
      padding: EdgeInsets.fromLTRB(indent, 12, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder.all(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
          children: block.rows
              .map(
                (row) => TableRow(
                  children: row.cells.map((cell) {
                    final runs = flattenInlines(cell.inlines);
                    final baseStyle = _buildReaderTextStyle(
                      baseStyle: theme.textTheme.bodyMedium,
                      theme: theme.readerTheme,
                      color: theme.colorScheme.onSurface,
                      overrideWeight:
                          cell.isHeader ? FontWeight.w600 : null,
                    );
                    final spans = _buildInlineSpans(
                      runs,
                      theme,
                      theme.colorScheme.onSurface,
                      baseStyle: baseStyle,
                    );
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: RichText(
                        text: TextSpan(children: spans),
                      ),
                    );
                  }).toList(),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  static Widget _buildTextBlock({
    required List<ReaderInline> inlines,
    required int? headingLevel,
    required ReaderRenderBlock renderBlock,
    required ReaderRenderTheme theme,
    required bool isActiveParagraph,
    required int activeSentenceIndex,
    required int previousSentenceIndex,
    required double transitionValue,
    required TapGestureRecognizer? Function(int sentenceIndex)?
        sentenceRecognizer,
    required VoidCallback? onTapParagraph,
    required ReaderTtsParagraph? ttsData,
  }) {
    final style = renderBlock.style;
    final showHighlight = isActiveParagraph &&
        (theme.activeParagraphStyle == PlayerThemeActiveParagraphStyle.highlight ||
            theme.activeParagraphStyle ==
                PlayerThemeActiveParagraphStyle.highlightBar);
    final showLeftBar = isActiveParagraph &&
        (theme.activeParagraphStyle == PlayerThemeActiveParagraphStyle.leftBar ||
            theme.activeParagraphStyle ==
                PlayerThemeActiveParagraphStyle.highlightBar);
    final showShadow = isActiveParagraph &&
        theme.activeParagraphStyle ==
            PlayerThemeActiveParagraphStyle.underline;

    final baseStyle = theme.textTheme.bodyLarge;
    final scale = headingLevel != null ? _headingScale(headingLevel) : 1.0;
    final textColor = _resolveReaderTextColor(
      theme.readerTheme,
      theme.colorScheme,
      isActive: isActiveParagraph,
    );
    final contentStyle = _buildReaderTextStyle(
      baseStyle: baseStyle,
      theme: theme.readerTheme,
      color: textColor,
      fontScale: scale,
      overrideWeight: headingLevel != null ? FontWeight.w700 : null,
    );

    final spans = ttsData == null
        ? _buildInlineSpans(
            flattenInlines(inlines),
            theme,
            textColor,
            baseStyle: contentStyle,
          )
        : _buildSentenceSpans(
            ttsData.sentenceRuns,
            theme,
            baseStyle: contentStyle,
            isActiveParagraph: isActiveParagraph,
            activeSentenceIndex: activeSentenceIndex,
            previousSentenceIndex: previousSentenceIndex,
            transitionValue: transitionValue,
            sentenceRecognizer: sentenceRecognizer,
          );

    final indent = _indentForStyle(theme, style);
    final listMarker = style.listMarker;

    Widget textContent = RichText(
      text: TextSpan(children: spans),
    );

    if (listMarker != null) {
      textContent = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              listMarker,
              style: contentStyle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: textContent),
        ],
      );
    }

    if (style.blockQuoteDepth > 0) {
      textContent = Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 2,
            ),
          ),
        ),
        child: textContent,
      );
    }

    final shadowOpacity =
        (theme.activeParagraphOpacity * 0.9).clamp(0.08, 0.3);

    final effectiveOnTap =
        sentenceRecognizer != null ? null : onTapParagraph;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        indent,
        theme.paragraphSpacing,
        0,
        theme.paragraphSpacing,
      ),
      child: GestureDetector(
        onTap: effectiveOnTap,
        child: _wrapShadow(
          showShadow: showShadow,
          shadowColor: theme.shadowColor.withOpacity(shadowOpacity),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: showHighlight
                  ? theme.colorScheme.primary
                      .withOpacity(theme.activeParagraphOpacity)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: showLeftBar ? 3 : 0,
                  margin: EdgeInsets.only(
                    right: showLeftBar ? 12 : 0,
                    top: 6,
                    bottom: 6,
                  ),
                  decoration: BoxDecoration(
                    color: showLeftBar
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: theme.paragraphIndent),
                    child: textContent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static double _headingScale(int level) {
    switch (level.clamp(1, 6)) {
      case 1:
        return 1.6;
      case 2:
        return 1.4;
      case 3:
        return 1.25;
      case 4:
        return 1.15;
      case 5:
        return 1.05;
      default:
        return 1.0;
    }
  }

  static double _indentForStyle(ReaderRenderTheme theme, RenderBlockStyle style) {
    return style.blockQuoteDepth * 12 + style.listDepth * 18;
  }

  static Widget _wrapShadow({
    required bool showShadow,
    required Color shadowColor,
    required Widget child,
  }) {
    if (!showShadow) return child;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 6),
            blurStyle: BlurStyle.outer,
          ),
        ],
      ),
      child: child,
    );
  }

  static List<TextSpan> _buildSentenceSpans(
    List<List<TextRun>> sentences,
    ReaderRenderTheme theme, {
    required TextStyle baseStyle,
    required bool isActiveParagraph,
    required int activeSentenceIndex,
    required int previousSentenceIndex,
    required double transitionValue,
    required TapGestureRecognizer? Function(int sentenceIndex)?
        sentenceRecognizer,
  }) {
    final spans = <TextSpan>[];
    for (var sentenceIdx = 0; sentenceIdx < sentences.length; sentenceIdx++) {
      final isCurrentSentence =
          isActiveParagraph && sentenceIdx == activeSentenceIndex;
      final isPreviousSentence =
          isActiveParagraph && sentenceIdx == previousSentenceIndex;
      final highlightIntensity = isCurrentSentence
          ? transitionValue
          : isPreviousSentence
              ? 1 - transitionValue
              : 0.0;
      final sentenceColor = _resolveReaderTextColor(
        theme.readerTheme,
        theme.colorScheme,
        isActive: isCurrentSentence || isPreviousSentence,
      );
      final highlightColor = theme.colorScheme.primary
          .withOpacity(theme.sentenceHighlightOpacity * highlightIntensity);

      final recognizer =
          sentenceRecognizer != null ? sentenceRecognizer(sentenceIdx) : null;
      final sentenceRuns = sentences[sentenceIdx];
      for (final run in sentenceRuns) {
        spans.add(
          _runToSpan(
            run,
            baseStyle,
            theme,
            sentenceColor,
            highlightColor: highlightColor,
            highlightStyle: theme.sentenceHighlightStyle,
            recognizer: recognizer,
          ),
        );
      }
      if (sentenceIdx < sentences.length - 1) {
        spans.add(TextSpan(text: ' ', style: baseStyle));
      }
    }
    return spans;
  }

  static List<TextSpan> _buildInlineSpans(
    List<TextRun> runs,
    ReaderRenderTheme theme,
    Color baseColor, {
    TextStyle? baseStyle,
  }) {
    final resolvedBase = baseStyle ??
        _buildReaderTextStyle(
          baseStyle: theme.textTheme.bodyLarge,
          theme: theme.readerTheme,
          color: baseColor,
        );
    return runs
        .map(
          (run) => _runToSpan(
            run,
            resolvedBase,
            theme,
            baseColor,
          ),
        )
        .toList();
  }

  static TextSpan _runToSpan(
    TextRun run,
    TextStyle baseStyle,
    ReaderRenderTheme theme,
    Color baseColor, {
    Color? highlightColor,
    PlayerThemeSentenceHighlightStyle highlightStyle =
        PlayerThemeSentenceHighlightStyle.background,
    GestureRecognizer? recognizer,
  }) {
    final style = _applyRunStyle(
      baseStyle,
      run.style,
      baseColor,
      highlightColor,
      highlightStyle,
    );
    if (run.style.sup || run.style.sub) {
      final fontSize = (style.fontSize ?? 16) * 0.75;
      final offset = run.style.sup ? -6.0 : 4.0;
      return TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Transform.translate(
              offset: Offset(0, offset),
              child: Text(
                run.text,
                style: style.copyWith(fontSize: fontSize, height: 1.0),
              ),
            ),
          ),
        ],
        recognizer: recognizer,
      );
    }
    return TextSpan(text: run.text, style: style, recognizer: recognizer);
  }

  static TextStyle _applyRunStyle(
    TextStyle baseStyle,
    TextRunStyle runStyle,
    Color baseColor,
    Color? highlightColor,
    PlayerThemeSentenceHighlightStyle highlightStyle,
  ) {
    var style = baseStyle.copyWith(color: baseColor);
    if (runStyle.bold) {
      style = style.copyWith(fontWeight: FontWeight.w700);
    }
    if (runStyle.italic) {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }
    if (runStyle.underline) {
      style = style.copyWith(decoration: TextDecoration.underline);
    }
    if (runStyle.linkHref != null && runStyle.linkHref!.isNotEmpty) {
      style = style.copyWith(color: baseStyle.color ?? baseColor);
    }
    if (highlightColor != null && highlightColor.opacity > 0) {
      if (highlightStyle == PlayerThemeSentenceHighlightStyle.underline) {
        final existing = style.decoration;
        final decoration = existing == null
            ? TextDecoration.underline
            : TextDecoration.combine([existing, TextDecoration.underline]);
        style = style.copyWith(
          decoration: decoration,
          decorationColor: highlightColor,
          decorationThickness: 1.6,
        );
      } else {
        style = style.copyWith(backgroundColor: highlightColor);
      }
    }
    return style;
  }

  static TextStyle _buildReaderTextStyle({
    required TextStyle? baseStyle,
    required PlayerThemeSettings theme,
    required Color color,
    double fontScale = 1.0,
    FontWeight? overrideWeight,
  }) {
    final style = (baseStyle ?? const TextStyle()).copyWith(
      fontSize: theme.fontSize * fontScale,
      fontWeight: overrideWeight ?? _resolveFontWeight(theme.fontWeight),
      height: theme.lineHeight,
      color: color,
    );
    final fontFamily = theme.fontFamily;
    if (fontFamily == null || fontFamily.trim().isEmpty) {
      return style;
    }
    try {
      return GoogleFonts.getFont(fontFamily, textStyle: style);
    } catch (_) {
      return style.copyWith(fontFamily: fontFamily);
    }
  }

  static FontWeight _resolveFontWeight(int weight) {
    final normalized = ((weight / 100).round() * 100).clamp(100, 900);
    switch (normalized) {
      case 100:
        return FontWeight.w100;
      case 200:
        return FontWeight.w200;
      case 300:
        return FontWeight.w300;
      case 400:
        return FontWeight.w400;
      case 500:
        return FontWeight.w500;
      case 600:
        return FontWeight.w600;
      case 700:
        return FontWeight.w700;
      case 800:
        return FontWeight.w800;
      case 900:
        return FontWeight.w900;
    }
    return FontWeight.w400;
  }

  static Color _resolveReaderTextColor(
    PlayerThemeSettings theme,
    ColorScheme colorScheme, {
    required bool isActive,
  }) {
    if (theme.textColorMode == PlayerThemeTextColorMode.fixed &&
        theme.textColor != null) {
      final base = theme.textColor!;
      return isActive ? base : base.withOpacity(0.78);
    }
    return isActive ? colorScheme.onSurface : colorScheme.onSurfaceVariant;
  }
}

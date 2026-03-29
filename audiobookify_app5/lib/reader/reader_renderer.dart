import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/player_theme_settings.dart';
import 'epub_resource_resolver.dart';
import 'reader_debug_logging.dart';
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
    required TapGestureRecognizer? Function(ReaderLinkTarget target)?
        linkRecognizer,
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
    if (block is CodeBlock) {
      return _buildCodeBlock(block, theme, renderBlock.style);
    }
    if (block is ParagraphBlock) {
      return _buildTextBlock(
        inlines: block.inlines,
        headingLevel: null,
        renderBlock: renderBlock,
        theme: theme,
        resolver: resolver,
        isActiveParagraph: isActiveParagraph,
        activeSentenceIndex: activeSentenceIndex,
        previousSentenceIndex: previousSentenceIndex,
        transitionValue: transitionValue,
        sentenceRecognizer: sentenceRecognizer,
        linkRecognizer: linkRecognizer,
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
        resolver: resolver,
        isActiveParagraph: isActiveParagraph,
        activeSentenceIndex: activeSentenceIndex,
        previousSentenceIndex: previousSentenceIndex,
        transitionValue: transitionValue,
        sentenceRecognizer: sentenceRecognizer,
        linkRecognizer: linkRecognizer,
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
        future: resolver.loadResource(block.resource),
        builder: (context, snapshot) {
          _logImageSnapshot(
            'block',
            href: block.resource.href,
            alt: block.alt,
            connectionState: snapshot.connectionState,
            bytes: snapshot.data?.length,
            error: snapshot.error,
          );
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _imagePlaceholder(theme, block.caption);
          }
          if (snapshot.hasError) {
            return _imagePlaceholder(theme, block.caption ?? block.alt);
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
                  errorBuilder: (context, error, stackTrace) {
                    _logImageDecodeError(
                      'block',
                      href: block.resource.href,
                      alt: block.alt,
                      error: error,
                    );
                    return _imagePlaceholder(theme, block.caption ?? block.alt);
                  },
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
                      linkRecognizer: null,
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
    required EpubResourceResolver resolver,
    required bool isActiveParagraph,
    required int activeSentenceIndex,
    required int previousSentenceIndex,
    required double transitionValue,
    required TapGestureRecognizer? Function(int sentenceIndex)?
        sentenceRecognizer,
    required TapGestureRecognizer? Function(ReaderLinkTarget target)?
        linkRecognizer,
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

    final containsInlineImages = _containsInlineImages(inlines);
    final containsInteractiveLinks = _containsInteractiveLinks(inlines);
    final spans = ttsData == null || containsInlineImages
        ? _buildInlineSpansFromInlines(
            inlines,
            theme,
            textColor,
            resolver: resolver,
            baseStyle: contentStyle,
            linkRecognizer: linkRecognizer,
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
            linkRecognizer: linkRecognizer,
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
        sentenceRecognizer != null || containsInteractiveLinks
            ? null
            : onTapParagraph;

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

  static List<InlineSpan> _buildSentenceSpans(
    List<List<TextRun>> sentences,
    ReaderRenderTheme theme, {
    required TextStyle baseStyle,
    required bool isActiveParagraph,
    required int activeSentenceIndex,
    required int previousSentenceIndex,
    required double transitionValue,
    required TapGestureRecognizer? Function(int sentenceIndex)?
        sentenceRecognizer,
    required TapGestureRecognizer? Function(ReaderLinkTarget target)?
        linkRecognizer,
  }) {
    final spans = <InlineSpan>[];
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
            recognizer:
                run.style.linkTarget != null && linkRecognizer != null
                    ? linkRecognizer(run.style.linkTarget!)
                    : recognizer,
          ),
        );
      }
      if (sentenceIdx < sentences.length - 1) {
        spans.add(TextSpan(text: ' ', style: baseStyle));
      }
    }
    return spans;
  }

  static List<InlineSpan> _buildInlineSpans(
    List<TextRun> runs,
    ReaderRenderTheme theme,
    Color baseColor, {
    TextStyle? baseStyle,
    TapGestureRecognizer? Function(ReaderLinkTarget target)? linkRecognizer,
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
            recognizer:
                run.style.linkTarget != null && linkRecognizer != null
                    ? linkRecognizer(run.style.linkTarget!)
                    : null,
          ),
        )
        .toList();
  }

  static List<InlineSpan> _buildInlineSpansFromInlines(
    List<ReaderInline> inlines,
    ReaderRenderTheme theme,
    Color baseColor, {
    required TextStyle baseStyle,
    required TapGestureRecognizer? Function(ReaderLinkTarget target)?
        linkRecognizer,
    required EpubResourceResolver? resolver,
  }) {
    return inlines
        .map(
          (inline) => _inlineToSpan(
            inline,
            theme,
            baseColor,
            baseStyle: baseStyle,
            linkRecognizer: linkRecognizer,
            resolver: resolver,
          ),
        )
        .toList();
  }

  static InlineSpan _inlineToSpan(
    ReaderInline inline,
    ReaderRenderTheme theme,
    Color baseColor, {
    required TextStyle baseStyle,
    required TapGestureRecognizer? Function(ReaderLinkTarget target)?
        linkRecognizer,
    required EpubResourceResolver? resolver,
  }) {
    if (inline is TextInline) {
      return TextSpan(text: inline.text, style: baseStyle);
    }
    if (inline is LineBreakInline) {
      return TextSpan(text: '\n', style: baseStyle);
    }
    if (inline is InlineImage) {
      if (resolver == null) {
        return TextSpan(text: inline.alt ?? '', style: baseStyle);
      }
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _InlineImageWidget(
          resource: inline.resource,
          alt: inline.alt,
          resolver: resolver,
          colorScheme: theme.colorScheme,
        ),
      );
    }
    if (inline is LinkInline) {
      return TextSpan(
        style: _applyRunStyle(
          baseStyle,
          TextRunStyle(linkTarget: inline.target, underline: true),
          baseStyle.color ?? baseColor,
          null,
          PlayerThemeSentenceHighlightStyle.background,
        ),
        recognizer:
            linkRecognizer != null ? linkRecognizer(inline.target) : null,
        children: _buildInlineSpansFromInlines(
          inline.children,
          theme,
          baseColor,
          baseStyle: baseStyle,
          linkRecognizer: linkRecognizer,
          resolver: resolver,
        ),
      );
    }
    if (inline is SpanInline) {
      var spanStyle = TextRunStyle();
      if (inline.styleHints.contains(SpanStyleHint.italic)) {
        spanStyle = spanStyle.copyWith(italic: true);
      }
      if (inline.styleHints.contains(SpanStyleHint.bold)) {
        spanStyle = spanStyle.copyWith(bold: true);
      }
      if (inline.styleHints.contains(SpanStyleHint.underline)) {
        spanStyle = spanStyle.copyWith(underline: true);
      }
      if (inline.styleHints.contains(SpanStyleHint.superscript)) {
        spanStyle = spanStyle.copyWith(sup: true);
      }
      if (inline.styleHints.contains(SpanStyleHint.subscript)) {
        spanStyle = spanStyle.copyWith(sub: true);
      }
      if (inline.styleHints.contains(SpanStyleHint.code)) {
        spanStyle = spanStyle.copyWith(code: true);
      }
      return TextSpan(
        style: _applyRunStyle(
          baseStyle,
          spanStyle,
          baseStyle.color ?? baseColor,
          null,
          PlayerThemeSentenceHighlightStyle.background,
        ),
        children: _buildInlineSpansFromInlines(
          inline.children,
          theme,
          baseColor,
          baseStyle: baseStyle,
          linkRecognizer: linkRecognizer,
          resolver: resolver,
        ),
      );
    }
    return const TextSpan(text: '');
  }

  static InlineSpan _runToSpan(
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
    if (runStyle.linkTarget != null) {
      style = style.copyWith(color: baseStyle.color ?? baseColor);
    }
    if (runStyle.code) {
      style = style.copyWith(
        fontFamily: 'monospace',
        backgroundColor:
            highlightColor == null || highlightColor.opacity == 0
                ? baseColor.withOpacity(0.08)
                : highlightColor,
      );
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

  static Widget _buildCodeBlock(
    CodeBlock block,
    ReaderRenderTheme theme,
    RenderBlockStyle style,
  ) {
    final indent = _indentForStyle(theme, style);
    final baseStyle = _buildReaderTextStyle(
      baseStyle: theme.textTheme.bodyMedium,
      theme: theme.readerTheme,
      color: theme.colorScheme.onSurface,
    ).copyWith(
      fontFamily: 'monospace',
      height: 1.45,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(indent, 12, 0, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.6),
          ),
        ),
        child: Text(block.text, style: baseStyle),
      ),
    );
  }

  static bool _containsInlineImages(List<ReaderInline> inlines) {
    for (final inline in inlines) {
      if (inline is InlineImage) return true;
      if (inline is SpanInline && _containsInlineImages(inline.children)) {
        return true;
      }
      if (inline is LinkInline && _containsInlineImages(inline.children)) {
        return true;
      }
    }
    return false;
  }

  static bool _containsInteractiveLinks(List<ReaderInline> inlines) {
    for (final inline in inlines) {
      if (inline is LinkInline) return true;
      if (inline is SpanInline && _containsInteractiveLinks(inline.children)) {
        return true;
      }
    }
    return false;
  }
}

class _InlineImageWidget extends StatelessWidget {
  final ReaderResourceRef resource;
  final String? alt;
  final EpubResourceResolver resolver;
  final ColorScheme colorScheme;

  const _InlineImageWidget({
    required this.resource,
    required this.alt,
    required this.resolver,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: resolver.loadResource(resource),
      builder: (context, snapshot) {
        _logImageSnapshot(
          'inline',
          href: resource.href,
          alt: alt,
          connectionState: snapshot.connectionState,
          bytes: snapshot.data?.length,
          error: snapshot.error,
        );
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.broken_image_outlined,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.image_outlined,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            height: 18,
            errorBuilder: (_, error, __) {
              _logImageDecodeError(
                'inline',
                href: resource.href,
                alt: alt,
                error: error,
              );
              return Icon(
                Icons.broken_image_outlined,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              );
            },
          ),
        );
      },
    );
  }
}

final Set<String> _imageDebugStates = <String>{};

void _logImageSnapshot(
  String scope, {
  required String href,
  required String? alt,
  required ConnectionState connectionState,
  required int? bytes,
  required Object? error,
}) {
  if (!kDebugMode || !ReaderDebugLogging.imageLogsEnabled) return;
  final stateKey =
      '$scope|$href|${alt ?? ''}|${connectionState.name}|${bytes ?? -1}|${error ?? ''}';
  if (!_imageDebugStates.add(stateKey)) return;
  debugPrint(
    '[image-debug] scope=$scope href="$href" alt="${alt ?? ''}" '
    'state=${connectionState.name} bytes=${bytes ?? 0} error=${error ?? 'none'}',
  );
}

void _logImageDecodeError(
  String scope, {
  required String href,
  required String? alt,
  required Object error,
}) {
  if (!kDebugMode || !ReaderDebugLogging.imageLogsEnabled) return;
  debugPrint(
    '[image-debug] scope=$scope href="$href" alt="${alt ?? ''}" '
    'decode-error=$error',
  );
}

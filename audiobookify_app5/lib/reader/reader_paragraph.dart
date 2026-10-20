import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'epub_resource_resolver.dart';
import 'reader_ir.dart';
import 'reader_renderer.dart';
import 'reader_segmentation.dart';

/// Animates sentence selection locally, without ticking the chapter or player.
class ReaderParagraph extends StatefulWidget {
  final ReaderRenderBlock renderBlock;
  final ReaderRenderTheme theme;
  final EpubResourceResolver resolver;
  final bool isActive;
  final int sentenceIndex;
  final ReaderTtsParagraph ttsData;
  final TapGestureRecognizer? Function(int sentenceIndex)? sentenceRecognizer;
  final TapGestureRecognizer? Function(ReaderLinkTarget target)? linkRecognizer;
  final VoidCallback? onTapParagraph;

  const ReaderParagraph({
    super.key,
    required this.renderBlock,
    required this.theme,
    required this.resolver,
    required this.isActive,
    required this.sentenceIndex,
    required this.ttsData,
    this.sentenceRecognizer,
    this.linkRecognizer,
    this.onTapParagraph,
  });

  @override
  State<ReaderParagraph> createState() => _ReaderParagraphState();
}

class _ReaderParagraphState extends State<ReaderParagraph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  int _previousSentenceIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: 1,
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(ReaderParagraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.renderBlock != widget.renderBlock) {
      _previousSentenceIndex = -1;
      _controller.value = 1;
    } else if (oldWidget.isActive != widget.isActive ||
        oldWidget.sentenceIndex != widget.sentenceIndex) {
      _previousSentenceIndex = oldWidget.isActive
          ? oldWidget.sentenceIndex
          : -1;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    builder: (context, child) => ReaderBlockRenderer.buildBlock(
      renderBlock: widget.renderBlock,
      theme: widget.theme,
      resolver: widget.resolver,
      isActiveParagraph: widget.isActive,
      activeSentenceIndex: widget.isActive ? widget.sentenceIndex : -1,
      previousSentenceIndex: _controller.value < 1
          ? _previousSentenceIndex
          : -1,
      transitionValue: _curve.value,
      sentenceRecognizer: widget.sentenceRecognizer,
      linkRecognizer: widget.linkRecognizer,
      onTapParagraph: widget.onTapParagraph,
      ttsData: widget.ttsData,
    ),
  );
}

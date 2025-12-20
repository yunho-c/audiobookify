import 'package:flutter/material.dart';

enum PlayerThemeBackgroundMode { coverAmbient, customImage, solid, gradient }

enum PlayerThemeTextColorMode { auto, fixed }

enum PlayerThemeActiveParagraphStyle {
  highlight,
  underline,
  leftBar,
  highlightBar,
}

enum PlayerThemeSentenceHighlightStyle { background, underline }

/// Model for reader theme customization on the player screen.
@immutable
class PlayerThemeSettings {
  final String? fontFamily;
  final double fontSize;
  final int fontWeight;
  final double lineHeight;
  final double paragraphSpacing;
  final double paragraphIndent;
  final double pagePaddingHorizontal;
  final double pagePaddingVertical;
  final PlayerThemeBackgroundMode backgroundMode;
  final String? backgroundImagePath;
  final double backgroundBlur;
  final double backgroundOpacity;
  final PlayerThemeTextColorMode textColorMode;
  final Color? textColor;
  final PlayerThemeActiveParagraphStyle activeParagraphStyle;
  final double activeParagraphOpacity;
  final PlayerThemeSentenceHighlightStyle sentenceHighlightStyle;

  const PlayerThemeSettings({
    this.fontFamily = 'Lora',
    this.fontSize = 18.0,
    this.fontWeight = 400,
    this.lineHeight = 1.8,
    this.paragraphSpacing = 4.0,
    this.paragraphIndent = 0.0,
    this.pagePaddingHorizontal = 28.0,
    this.pagePaddingVertical = 12.0,
    this.backgroundMode = PlayerThemeBackgroundMode.coverAmbient,
    this.backgroundImagePath,
    this.backgroundBlur = 20.0,
    this.backgroundOpacity = 0.5,
    this.textColorMode = PlayerThemeTextColorMode.auto,
    this.textColor,
    this.activeParagraphStyle = PlayerThemeActiveParagraphStyle.highlightBar,
    this.activeParagraphOpacity = 0.12,
    this.sentenceHighlightStyle = PlayerThemeSentenceHighlightStyle.background,
  });

  PlayerThemeSettings copyWith({
    String? fontFamily,
    double? fontSize,
    int? fontWeight,
    double? lineHeight,
    double? paragraphSpacing,
    double? paragraphIndent,
    double? pagePaddingHorizontal,
    double? pagePaddingVertical,
    PlayerThemeBackgroundMode? backgroundMode,
    String? backgroundImagePath,
    double? backgroundBlur,
    double? backgroundOpacity,
    PlayerThemeTextColorMode? textColorMode,
    Color? textColor,
    PlayerThemeActiveParagraphStyle? activeParagraphStyle,
    double? activeParagraphOpacity,
    PlayerThemeSentenceHighlightStyle? sentenceHighlightStyle,
  }) {
    return PlayerThemeSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
      pagePaddingHorizontal: pagePaddingHorizontal ?? this.pagePaddingHorizontal,
      pagePaddingVertical: pagePaddingVertical ?? this.pagePaddingVertical,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      backgroundBlur: backgroundBlur ?? this.backgroundBlur,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      textColorMode: textColorMode ?? this.textColorMode,
      textColor: textColor ?? this.textColor,
      activeParagraphStyle: activeParagraphStyle ?? this.activeParagraphStyle,
      activeParagraphOpacity:
          activeParagraphOpacity ?? this.activeParagraphOpacity,
      sentenceHighlightStyle:
          sentenceHighlightStyle ?? this.sentenceHighlightStyle,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerThemeSettings &&
          runtimeType == other.runtimeType &&
          fontFamily == other.fontFamily &&
          fontSize == other.fontSize &&
          fontWeight == other.fontWeight &&
          lineHeight == other.lineHeight &&
          paragraphSpacing == other.paragraphSpacing &&
          paragraphIndent == other.paragraphIndent &&
          pagePaddingHorizontal == other.pagePaddingHorizontal &&
          pagePaddingVertical == other.pagePaddingVertical &&
          backgroundMode == other.backgroundMode &&
          backgroundImagePath == other.backgroundImagePath &&
          backgroundBlur == other.backgroundBlur &&
          backgroundOpacity == other.backgroundOpacity &&
          textColorMode == other.textColorMode &&
          textColor == other.textColor &&
          activeParagraphStyle == other.activeParagraphStyle &&
          activeParagraphOpacity == other.activeParagraphOpacity &&
          sentenceHighlightStyle == other.sentenceHighlightStyle;

  @override
  int get hashCode => Object.hash(
        fontFamily,
        fontSize,
        fontWeight,
        lineHeight,
        paragraphSpacing,
        paragraphIndent,
        pagePaddingHorizontal,
        pagePaddingVertical,
        backgroundMode,
        backgroundImagePath,
        backgroundBlur,
        backgroundOpacity,
        textColorMode,
        textColor,
        activeParagraphStyle,
        activeParagraphOpacity,
        sentenceHighlightStyle,
      );
}

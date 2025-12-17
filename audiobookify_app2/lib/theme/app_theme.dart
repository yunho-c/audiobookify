import 'package:flutter/material.dart';

/// App color palette based on dark wood library aesthetic
class AppColors {
  // Background
  static const background = Color(0xFF1c1917);
  static const backgroundLight = Color(0xFF292524);

  // Wood shelf
  static const shelfWood = Color(0xFF431407);
  static const shelfBorder = Color(0xFF78350f);

  // Brown UI elements
  static const primaryBrown = Color(0xFF5d4037);
  static const darkBrown = Color(0xFF3e2723);

  // Text colors
  static const cream = Color(0xFFf5f5dc);
  static const lightStone = Color(0xFFe7e5e4);
  static const warmStone = Color(0xFFd7ccc8);

  // Gold stamp
  static const gold = Color(0xFFeebb66);
  static const goldLight = Color(0xFFfde047);

  // Silver stamp
  static const silver = Color(0xFFe2e8f0);

  // Reader theme
  static const readerBg = Color(0xFFfff8e1);
  static const readerHeader = Color(0xFFfae8b4);
  static const readerText = Color(0xFF4e342e);
  static const readerAccent = Color(0xFFffe0b2);

  // Interior pages
  static const pageCream = Color(0xFFfdfbf7);
  static const pageEdge = Color(0xFFe8e6e1);
}

/// Animation constants
class AppAnimations {
  static const bookTransformDuration = Duration(milliseconds: 800);
  static const bookTransformCurve = Cubic(0.34, 1.56, 0.64, 1);

  static const fadeDuration = Duration(milliseconds: 300);
  static const slideDuration = Duration(milliseconds: 500);
}

/// Text styles
class AppTextStyles {
  static const goldStamp = TextStyle(
    color: AppColors.gold,
    fontWeight: FontWeight.bold,
    letterSpacing: 2.0,
    shadows: [
      Shadow(
        color: Color(0xE6000000),
        offset: Offset(0, 1),
        blurRadius: 1,
      ),
      Shadow(
        color: Color(0x4Deebb66),
        offset: Offset(0, 0),
        blurRadius: 2,
      ),
    ],
  );

  static const silverStamp = TextStyle(
    color: AppColors.silver,
    fontWeight: FontWeight.bold,
    letterSpacing: 2.0,
    shadows: [
      Shadow(
        color: Color(0xE6000000),
        offset: Offset(0, 1),
        blurRadius: 1,
      ),
    ],
  );

  static TextStyle title(BuildContext context) => TextStyle(
        fontFamily: 'serif',
        fontSize: 48,
        fontWeight: FontWeight.w400,
        color: AppColors.lightStone,
        letterSpacing: -0.5,
        shadows: [
          Shadow(
            color: AppColors.gold.withOpacity(0.3),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      );
}

/// App theme data
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBrown,
      brightness: Brightness.dark,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'serif',
        fontWeight: FontWeight.w400,
      ),
      titleLarge: TextStyle(
        fontFamily: 'serif',
        fontWeight: FontWeight.bold,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'serif',
      ),
      labelSmall: TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: 2.0,
      ),
    ),
  );
}

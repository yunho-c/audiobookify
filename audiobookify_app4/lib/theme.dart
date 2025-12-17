import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App color constants
class AppColors {
  // Background colors
  static const Color background = Color(0xFF111827); // gray-900
  static const Color surface = Color(0xFF1F2937); // gray-800
  static const Color surfaceLight = Color(0xFF374151); // gray-700

  // Text colors
  static const Color textPrimary = Color(0xFFF3F4F6); // gray-100
  static const Color textSecondary = Color(0xFF9CA3AF); // gray-400
  static const Color textMuted = Color(0xFF6B7280); // gray-500

  // Accent colors
  static const Color indigo = Color(0xFF6366F1); // indigo-500
  static const Color indigoLight = Color(0xFF818CF8); // indigo-400

  // Border colors
  static const Color border = Color(0xFF1F2937); // gray-800
}

/// Dark theme configuration
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.background,
      primary: AppColors.indigo,
      secondary: AppColors.indigoLight,
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme.copyWith(
        displayLarge: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        headlineLarge: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        headlineMedium: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          color: AppColors.textSecondary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        bodySmall: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    ),
    iconTheme: const IconThemeData(color: AppColors.textSecondary),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.indigo,
      inactiveTrackColor: AppColors.surfaceLight,
      thumbColor: Colors.white,
      overlayColor: AppColors.indigo.withOpacity(0.2),
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
  );
}

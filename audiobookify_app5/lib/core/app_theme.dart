import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App color palette based on Tailwind stone/orange theme
class AppColors {
  // Stone palette
  static const stone50 = Color(0xFFFAFAF9);
  static const stone100 = Color(0xFFF5F5F4);
  static const stone200 = Color(0xFFE7E5E4);
  static const stone300 = Color(0xFFD6D3D1);
  static const stone400 = Color(0xFFA8A29E);
  static const stone500 = Color(0xFF78716C);
  static const stone600 = Color(0xFF57534E);
  static const stone700 = Color(0xFF44403C);
  static const stone800 = Color(0xFF292524);
  static const stone900 = Color(0xFF1C1917);

  // Orange accent
  static const orange50 = Color(0xFFFFF7ED);
  static const orange100 = Color(0xFFFFEDD5);
  static const orange200 = Color(0xFFFED7AA);
  static const orange400 = Color(0xFFFB923C);
  static const orange600 = Color(0xFFEA580C);
  static const orange700 = Color(0xFFC2410C);

  // Book cover colors
  static const indigo700 = Color(0xFF4338CA);
  static const slate700 = Color(0xFF334155);
  static const rose700 = Color(0xFFBE123C);
  static const amber800 = Color(0xFF92400E);
  static const sky700 = Color(0xFF0369A1);

  // Settings wheel colors
  static const rose100 = Color(0xFFFFE4E6);
  static const rose600 = Color(0xFFE11D48);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber600 = Color(0xFFD97706);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue600 = Color(0xFF2563EB);
  static const emerald100 = Color(0xFFD1FAE5);
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald400 = Color(0xFF34D399);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);
  static const red400 = Color(0xFFF87171);
  static const red600 = Color(0xFFDC2626);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.stone50,
      colorScheme: ColorScheme.light(
        primary: AppColors.orange600,
        onPrimary: Colors.white,
        secondary: AppColors.stone800,
        onSecondary: Colors.white,
        surface: AppColors.stone50,
        onSurface: AppColors.stone800,
        error: AppColors.red600,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        // Serif headings
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.stone800,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.stone800,
        ),
        headlineLarge: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.stone800,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.stone800,
        ),
        headlineSmall: GoogleFonts.playfairDisplay(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.stone800,
        ),
        // Body text
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: AppColors.stone700),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: AppColors.stone600),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: AppColors.stone500),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.stone700,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.stone500,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
          color: AppColors.stone400,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withAlpha(25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.stone800,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.stone600, size: 24),
    );
  }
}

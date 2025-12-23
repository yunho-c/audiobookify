import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App color palette based on Tailwind stone/orange theme.
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

enum AppThemePreference { system, light, dark, sepia }

extension AppThemePreferenceX on AppThemePreference {
  String get label {
    switch (this) {
      case AppThemePreference.system:
        return 'System';
      case AppThemePreference.light:
        return 'Light';
      case AppThemePreference.dark:
        return 'Dark';
      case AppThemePreference.sepia:
        return 'Sepia';
    }
  }
}

@immutable
class AppThemeExtras extends ThemeExtension<AppThemeExtras> {
  final List<Color> bookCoverPalette;
  final List<Color> accentPalette;
  final List<Color> accentSoftPalette;
  final Color glassBackground;
  final Color glassBorder;
  final Color glassShadow;

  const AppThemeExtras({
    required this.bookCoverPalette,
    required this.accentPalette,
    required this.accentSoftPalette,
    required this.glassBackground,
    required this.glassBorder,
    required this.glassShadow,
  });

  @override
  AppThemeExtras copyWith({
    List<Color>? bookCoverPalette,
    List<Color>? accentPalette,
    List<Color>? accentSoftPalette,
    Color? glassBackground,
    Color? glassBorder,
    Color? glassShadow,
  }) {
    return AppThemeExtras(
      bookCoverPalette: bookCoverPalette ?? this.bookCoverPalette,
      accentPalette: accentPalette ?? this.accentPalette,
      accentSoftPalette: accentSoftPalette ?? this.accentSoftPalette,
      glassBackground: glassBackground ?? this.glassBackground,
      glassBorder: glassBorder ?? this.glassBorder,
      glassShadow: glassShadow ?? this.glassShadow,
    );
  }

  @override
  AppThemeExtras lerp(ThemeExtension<AppThemeExtras>? other, double t) {
    if (other is! AppThemeExtras) return this;
    return AppThemeExtras(
      bookCoverPalette: t < 0.5 ? bookCoverPalette : other.bookCoverPalette,
      accentPalette: t < 0.5 ? accentPalette : other.accentPalette,
      accentSoftPalette:
          t < 0.5 ? accentSoftPalette : other.accentSoftPalette,
      glassBackground: Color.lerp(glassBackground, other.glassBackground, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
    );
  }
}

class AppTheme {
  static ThemeData get light => _themeFromPalette(_lightPalette, _lightExtras);
  static ThemeData get dark => _themeFromPalette(_darkPalette, _darkExtras);
  static ThemeData get sepia => _themeFromPalette(_sepiaPalette, _sepiaExtras);

  static ThemeData themeFor(AppThemePreference preference) {
    switch (preference) {
      case AppThemePreference.dark:
        return dark;
      case AppThemePreference.sepia:
        return sepia;
      case AppThemePreference.system:
      case AppThemePreference.light:
        return light;
    }
  }

  static ThemeMode modeFor(AppThemePreference preference) {
    switch (preference) {
      case AppThemePreference.system:
        return ThemeMode.system;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.light:
      case AppThemePreference.sepia:
        return ThemeMode.light;
    }
  }

  static ThemeData _themeFromPalette(
    _AppPalette palette,
    AppThemeExtras extras,
  ) {
    final colorScheme = (palette.brightness == Brightness.dark
            ? ColorScheme.dark(
                primary: palette.primary,
                onPrimary: palette.onPrimary,
                secondary: palette.secondary,
                onSecondary: palette.onSecondary,
                surface: palette.surface,
                onSurface: palette.onSurface,
                error: palette.error,
                onError: palette.onError,
              )
            : ColorScheme.light(
                primary: palette.primary,
                onPrimary: palette.onPrimary,
                secondary: palette.secondary,
                onSecondary: palette.onSecondary,
                surface: palette.surface,
                onSurface: palette.onSurface,
                error: palette.error,
                onError: palette.onError,
              ))
        .copyWith(
          background: palette.background,
          onBackground: palette.onBackground,
          surfaceVariant: palette.surfaceVariant,
          onSurfaceVariant: palette.onSurfaceVariant,
          outline: palette.outline,
          outlineVariant: palette.divider,
          surfaceTint: palette.primary,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: _textTheme(palette),
      shadowColor: palette.shadow,
      cardTheme: CardThemeData(
        color: palette.surfaceElevated,
        elevation: 2,
        shadowColor: palette.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceVariant,
        selectedColor: palette.primary.withAlpha(160),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: palette.textSecondary,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: palette.onPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: palette.divider, thickness: 1),
      iconTheme: IconThemeData(color: palette.textSecondary, size: 24),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: palette.surfaceVariant,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      extensions: <ThemeExtension<dynamic>>[extras],
    );
  }

  static TextTheme _textTheme(_AppPalette palette) {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displayLarge: GoogleFonts.playfairDisplay(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: palette.textPrimary,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: palette.textPrimary,
      ),
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: palette.textPrimary,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: palette.textPrimary,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: palette.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(fontSize: 16, color: palette.textSecondary),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: palette.textSecondary),
      bodySmall: GoogleFonts.inter(fontSize: 12, color: palette.textMuted),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: palette.textSecondary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: palette.textMuted,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
        color: palette.textMuted,
      ),
    );
  }

  static const _AppPalette _lightPalette = _AppPalette(
    brightness: Brightness.light,
    background: AppColors.stone50,
    surface: Colors.white,
    surfaceVariant: AppColors.stone100,
    surfaceElevated: Colors.white,
    primary: AppColors.orange600,
    onPrimary: Colors.white,
    secondary: AppColors.stone800,
    onSecondary: Colors.white,
    onSurface: AppColors.stone800,
    onSurfaceVariant: AppColors.stone600,
    onBackground: AppColors.stone800,
    textPrimary: AppColors.stone800,
    textSecondary: AppColors.stone600,
    textMuted: AppColors.stone500,
    outline: AppColors.stone300,
    divider: AppColors.stone100,
    error: AppColors.red600,
    onError: Colors.white,
    shadow: Color(0x19000000),
  );

  static const _AppPalette _darkPalette = _AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF12110F),
    surface: Color(0xFF1C1A17),
    surfaceVariant: Color(0xFF26231F),
    surfaceElevated: Color(0xFF2B2723),
    primary: Color(0xFFF97316),
    onPrimary: Color(0xFF1C120B),
    secondary: Color(0xFFE7E5E4),
    onSecondary: Color(0xFF1C1A17),
    onSurface: Color(0xFFF5F5F4),
    onSurfaceVariant: Color(0xFFD6D3D1),
    onBackground: Color(0xFFF5F5F4),
    textPrimary: Color(0xFFF5F5F4),
    textSecondary: Color(0xFFD6D3D1),
    textMuted: Color(0xFFA8A29E),
    outline: Color(0xFF3F3A34),
    divider: Color(0xFF2A2622),
    error: Color(0xFFF87171),
    onError: Color(0xFF2A0C0C),
    shadow: Color(0x66000000),
  );

  static const _AppPalette _sepiaPalette = _AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF7F1E7),
    surface: Color(0xFFFFFBF5),
    surfaceVariant: Color(0xFFF0E6D6),
    surfaceElevated: Color(0xFFFFF7ED),
    primary: Color(0xFFB45309),
    onPrimary: Colors.white,
    secondary: Color(0xFF3B2F23),
    onSecondary: Colors.white,
    onSurface: Color(0xFF3B2F23),
    onSurfaceVariant: Color(0xFF5B4A3A),
    onBackground: Color(0xFF3B2F23),
    textPrimary: Color(0xFF3B2F23),
    textSecondary: Color(0xFF5B4A3A),
    textMuted: Color(0xFF7A6A5A),
    outline: Color(0xFFE2D3C0),
    divider: Color(0xFFEADFCC),
    error: Color(0xFFB42318),
    onError: Colors.white,
    shadow: Color(0x1A3B2F23),
  );

  static const AppThemeExtras _lightExtras = AppThemeExtras(
    bookCoverPalette: <Color>[
      AppColors.emerald700,
      AppColors.indigo700,
      AppColors.slate700,
      AppColors.rose700,
      AppColors.amber800,
      AppColors.sky700,
    ],
    accentPalette: <Color>[
      AppColors.rose600,
      AppColors.amber600,
      AppColors.blue600,
      AppColors.emerald600,
    ],
    accentSoftPalette: <Color>[
      AppColors.rose100,
      AppColors.amber100,
      AppColors.blue100,
      AppColors.emerald100,
    ],
    glassBackground: Color(0xC8FFFFFF),
    glassBorder: Color(0x32FFFFFF),
    glassShadow: Color(0x19000000),
  );

  static const AppThemeExtras _darkExtras = AppThemeExtras(
    bookCoverPalette: <Color>[
      Color(0xFF34D399),
      Color(0xFF818CF8),
      Color(0xFF94A3B8),
      Color(0xFFFB7185),
      Color(0xFFFBBF24),
      Color(0xFF38BDF8),
    ],
    accentPalette: <Color>[
      Color(0xFFF43F5E),
      Color(0xFFF59E0B),
      Color(0xFF60A5FA),
      Color(0xFF34D399),
    ],
    accentSoftPalette: <Color>[
      Color(0xFF3B1F24),
      Color(0xFF3B2A16),
      Color(0xFF1E2A3A),
      Color(0xFF1B332A),
    ],
    glassBackground: Color(0xE01C1A17),
    glassBorder: Color(0x1AFFFFFF),
    glassShadow: Color(0x66000000),
  );

  static const AppThemeExtras _sepiaExtras = AppThemeExtras(
    bookCoverPalette: <Color>[
      Color(0xFF8B5E3C),
      Color(0xFF5C4B3B),
      Color(0xFFB56A3B),
      Color(0xFF7A4E2B),
      Color(0xFF9C6B43),
      Color(0xFF4E3B2F),
    ],
    accentPalette: <Color>[
      Color(0xFFB45309),
      Color(0xFF8B5E3C),
      Color(0xFF6B4E3D),
      Color(0xFF7A6A5A),
    ],
    accentSoftPalette: <Color>[
      Color(0xFFF2E5D4),
      Color(0xFFEAD9C5),
      Color(0xFFE0D2C2),
      Color(0xFFE4D8C9),
    ],
    glassBackground: Color(0xE6FFFBF5),
    glassBorder: Color(0x33DCCBB7),
    glassShadow: Color(0x1A3B2F23),
  );
}

class _AppPalette {
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color surfaceElevated;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color onBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color outline;
  final Color divider;
  final Color error;
  final Color onError;
  final Color shadow;

  const _AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceElevated,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.outline,
    required this.divider,
    required this.error,
    required this.onError,
    required this.shadow,
  });
}

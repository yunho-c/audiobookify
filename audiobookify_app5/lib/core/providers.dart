import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart' show StateNotifierProvider;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audiobookify/objectbox.g.dart';
import '../data/built_in_backdrops.dart';
import '../models/backdrop_image.dart';
import '../models/backdrop_settings.dart';
import '../services/book_service.dart';
import '../services/epub_service.dart';
import '../services/open_library_service.dart';
import '../services/tts_audio_handler.dart';
import '../services/tts_service.dart';
import '../models/player_settings.dart';
import '../models/player_theme_settings.dart';
import '../models/public_book.dart';
import 'app_theme.dart';
import 'error_reporter.dart';

/// ObjectBox Store provider - overridden in main.dart
final storeProvider = Provider<Store>((ref) {
  throw UnimplementedError('Store must be overridden in ProviderScope');
});

/// BookService provider - depends on Store
final bookServiceProvider = Provider<BookService>((ref) {
  return BookService(ref.read(storeProvider));
});

final epubServiceProvider = Provider<EpubService>((ref) {
  return const EpubService();
});

/// Reactive stream of all books
final booksProvider = StreamProvider((ref) {
  return ref.watch(bookServiceProvider).watchAllBooks();
});

// ========================================
// Open Library
// ========================================

/// Open Library service provider.
final openLibraryServiceProvider = Provider<OpenLibraryService>((ref) {
  final service = OpenLibraryService();
  ref.onDispose(service.dispose);
  return service;
});

class OpenLibrarySearchArgs {
  final String query;
  final int page;
  final int limit;
  final String? language;

  const OpenLibrarySearchArgs({
    required this.query,
    this.page = 1,
    this.limit = 20,
    this.language,
  });

  @override
  bool operator ==(Object other) {
    return other is OpenLibrarySearchArgs &&
        other.query == query &&
        other.page == page &&
        other.limit == limit &&
        other.language == language;
  }

  @override
  int get hashCode => Object.hash(query, page, limit, language);
}

/// Search provider for public-domain Open Library results.
final openLibrarySearchProvider =
    FutureProvider.family<List<PublicBook>, OpenLibrarySearchArgs>(
  (ref, args) {
    return ref.read(openLibraryServiceProvider).searchPublicDomain(
          query: args.query,
          page: args.page,
          limit: args.limit,
          language: args.language,
        );
  },
);

/// SharedPreferences provider - overridden in main.dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'SharedPreferences must be overridden in ProviderScope',
  );
});

/// Theme preference notifier with persistence.
class ThemePreferenceNotifier extends Notifier<AppThemePreference> {
  static const _themeKey = 'app_theme_preference';

  @override
  AppThemePreference build() {
    return _loadFromPrefs();
  }

  AppThemePreference _loadFromPrefs() {
    final prefs = ref.read(sharedPreferencesProvider);
    final value = prefs.getString(_themeKey);
    return AppThemePreference.values.firstWhere(
      (theme) => theme.name == value,
      orElse: () => AppThemePreference.system,
    );
  }

  Future<void> _saveToPrefs(AppThemePreference preference) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_themeKey, preference.name);
  }

  void setPreference(AppThemePreference preference) {
    state = preference;
    _saveToPrefs(preference);
  }
}

/// Theme preference provider.
final themePreferenceProvider =
    NotifierProvider<ThemePreferenceNotifier, AppThemePreference>(
      ThemePreferenceNotifier.new,
    );

/// Player settings notifier with persistence
class PlayerSettingsNotifier extends Notifier<PlayerSettings> {
  static const _speedKey = 'player_speed';
  static const _pitchKey = 'player_pitch';
  static const _voiceNameKey = 'player_voice_name';
  static const _voiceLocaleKey = 'player_voice_locale';

  @override
  PlayerSettings build() {
    return _loadFromPrefs();
  }

  PlayerSettings _loadFromPrefs() {
    final prefs = ref.read(sharedPreferencesProvider);
    return PlayerSettings(
      speed: prefs.getDouble(_speedKey) ?? 1.0,
      pitch: prefs.getDouble(_pitchKey) ?? 1.0,
      voiceName: prefs.getString(_voiceNameKey),
      voiceLocale: prefs.getString(_voiceLocaleKey),
    );
  }

  Future<void> _saveToPrefs() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble(_speedKey, state.speed);
    await prefs.setDouble(_pitchKey, state.pitch);
    if (state.voiceName != null) {
      await prefs.setString(_voiceNameKey, state.voiceName!);
    }
    if (state.voiceLocale != null) {
      await prefs.setString(_voiceLocaleKey, state.voiceLocale!);
    }
  }

  void setSpeed(double speed) {
    state = state.copyWith(speed: speed.clamp(0.5, 2.0));
    _saveToPrefs();
  }

  void setPitch(double pitch) {
    state = state.copyWith(pitch: pitch.clamp(0.5, 2.0));
    _saveToPrefs();
  }

  void setVoice(String name, String locale) {
    state = state.copyWith(voiceName: name, voiceLocale: locale);
    _saveToPrefs();
  }

  void reset() {
    state = const PlayerSettings();
    _saveToPrefs();
  }
}

/// Player settings provider
final playerSettingsProvider =
    NotifierProvider<PlayerSettingsNotifier, PlayerSettings>(
      () => PlayerSettingsNotifier(),
    );

/// Player theme settings notifier with persistence.
class PlayerThemeSettingsNotifier extends Notifier<PlayerThemeSettings> {
  static const _fontFamilyKey = 'player_theme_font_family';
  static const _fontSizeKey = 'player_theme_font_size';
  static const _fontWeightKey = 'player_theme_font_weight';
  static const _lineHeightKey = 'player_theme_line_height';
  static const _paragraphSpacingKey = 'player_theme_paragraph_spacing';
  static const _paragraphIndentKey = 'player_theme_paragraph_indent';
  static const _pagePaddingHorizontalKey = 'player_theme_page_padding_horizontal';
  static const _pagePaddingVerticalKey = 'player_theme_page_padding_vertical';
  static const _backgroundModeKey = 'player_theme_background_mode';
  static const _backgroundImagePathKey = 'player_theme_background_image_path';
  static const _backgroundBlurKey = 'player_theme_background_blur';
  static const _backgroundOpacityKey = 'player_theme_background_opacity';
  static const _textColorModeKey = 'player_theme_text_color_mode';
  static const _textColorKey = 'player_theme_text_color';
  static const _activeParagraphStyleKey = 'player_theme_active_paragraph_style';
  static const _activeParagraphOpacityKey =
      'player_theme_active_paragraph_opacity';
  static const _sentenceHighlightStyleKey =
      'player_theme_sentence_highlight_style';

  @override
  PlayerThemeSettings build() {
    return _loadFromPrefs();
  }

  PlayerThemeSettings _loadFromPrefs() {
    final prefs = ref.read(sharedPreferencesProvider);
    final defaultTheme = const PlayerThemeSettings();
    final fontFamily = prefs.getString(_fontFamilyKey);
    final textColorValue = prefs.getInt(_textColorKey);

    return PlayerThemeSettings(
      fontFamily:
          (fontFamily == null || fontFamily.trim().isEmpty) ? null : fontFamily,
      fontSize: prefs.getDouble(_fontSizeKey) ?? defaultTheme.fontSize,
      fontWeight: _sanitizeFontWeight(
        prefs.getInt(_fontWeightKey) ?? defaultTheme.fontWeight,
      ),
      lineHeight: prefs.getDouble(_lineHeightKey) ?? defaultTheme.lineHeight,
      paragraphSpacing:
          prefs.getDouble(_paragraphSpacingKey) ??
              defaultTheme.paragraphSpacing,
      paragraphIndent:
          prefs.getDouble(_paragraphIndentKey) ?? defaultTheme.paragraphIndent,
      pagePaddingHorizontal:
          prefs.getDouble(_pagePaddingHorizontalKey) ??
              defaultTheme.pagePaddingHorizontal,
      pagePaddingVertical:
          prefs.getDouble(_pagePaddingVerticalKey) ??
              defaultTheme.pagePaddingVertical,
      backgroundMode: _readEnum<PlayerThemeBackgroundMode>(
        prefs.getString(_backgroundModeKey),
        PlayerThemeBackgroundMode.values,
        defaultTheme.backgroundMode,
      ),
      backgroundImagePath: prefs.getString(_backgroundImagePathKey),
      backgroundBlur:
          prefs.getDouble(_backgroundBlurKey) ?? defaultTheme.backgroundBlur,
      backgroundOpacity:
          prefs.getDouble(_backgroundOpacityKey) ??
              defaultTheme.backgroundOpacity,
      textColorMode: _readEnum<PlayerThemeTextColorMode>(
        prefs.getString(_textColorModeKey),
        PlayerThemeTextColorMode.values,
        defaultTheme.textColorMode,
      ),
      textColor: textColorValue == null ? null : Color(textColorValue),
      activeParagraphStyle: _readEnum<PlayerThemeActiveParagraphStyle>(
        prefs.getString(_activeParagraphStyleKey),
        PlayerThemeActiveParagraphStyle.values,
        defaultTheme.activeParagraphStyle,
      ),
      activeParagraphOpacity:
          prefs.getDouble(_activeParagraphOpacityKey) ??
              defaultTheme.activeParagraphOpacity,
      sentenceHighlightStyle: _readEnum<PlayerThemeSentenceHighlightStyle>(
        prefs.getString(_sentenceHighlightStyleKey),
        PlayerThemeSentenceHighlightStyle.values,
        defaultTheme.sentenceHighlightStyle,
      ),
    );
  }

  static T _readEnum<T>(String? value, List<T> values, T fallback) {
    if (value == null) return fallback;
    for (final entry in values) {
      if (entry is Enum && entry.name == value) {
        return entry;
      }
    }
    return fallback;
  }

  static int _sanitizeFontWeight(int weight) {
    final rounded = ((weight / 100).round() * 100).clamp(100, 900);
    return rounded;
  }

  Future<void> _saveToPrefs(PlayerThemeSettings settings) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (settings.fontFamily == null ||
        settings.fontFamily!.trim().isEmpty) {
      await prefs.remove(_fontFamilyKey);
    } else {
      await prefs.setString(_fontFamilyKey, settings.fontFamily!.trim());
    }
    await prefs.setDouble(_fontSizeKey, settings.fontSize);
    await prefs.setInt(
      _fontWeightKey,
      _sanitizeFontWeight(settings.fontWeight),
    );
    await prefs.setDouble(_lineHeightKey, settings.lineHeight);
    await prefs.setDouble(_paragraphSpacingKey, settings.paragraphSpacing);
    await prefs.setDouble(_paragraphIndentKey, settings.paragraphIndent);
    await prefs.setDouble(
      _pagePaddingHorizontalKey,
      settings.pagePaddingHorizontal,
    );
    await prefs.setDouble(
      _pagePaddingVerticalKey,
      settings.pagePaddingVertical,
    );
    await prefs.setString(_backgroundModeKey, settings.backgroundMode.name);
    if (settings.backgroundImagePath == null ||
        settings.backgroundImagePath!.trim().isEmpty) {
      await prefs.remove(_backgroundImagePathKey);
    } else {
      await prefs.setString(
        _backgroundImagePathKey,
        settings.backgroundImagePath!.trim(),
      );
    }
    await prefs.setDouble(_backgroundBlurKey, settings.backgroundBlur);
    await prefs.setDouble(_backgroundOpacityKey, settings.backgroundOpacity);
    await prefs.setString(_textColorModeKey, settings.textColorMode.name);
    if (settings.textColor == null) {
      await prefs.remove(_textColorKey);
    } else {
      await prefs.setInt(_textColorKey, settings.textColor!.value);
    }
    await prefs.setString(
      _activeParagraphStyleKey,
      settings.activeParagraphStyle.name,
    );
    await prefs.setDouble(
      _activeParagraphOpacityKey,
      settings.activeParagraphOpacity,
    );
    await prefs.setString(
      _sentenceHighlightStyleKey,
      settings.sentenceHighlightStyle.name,
    );
  }

  void setTheme(PlayerThemeSettings settings) {
    state = settings;
    _saveToPrefs(state);
  }

  void reset() {
    state = const PlayerThemeSettings();
    _saveToPrefs(state);
  }
}

/// Player theme settings provider.
final playerThemeProvider =
    NotifierProvider<PlayerThemeSettingsNotifier, PlayerThemeSettings>(
      PlayerThemeSettingsNotifier.new,
    );

// ========================================
// Backdrop Library
// ========================================

class BackdropLibraryNotifier extends Notifier<List<BackdropImage>> {
  static const _libraryKey = 'backdrop_library_v1';

  @override
  List<BackdropImage> build() {
    return _loadFromPrefs();
  }

  List<BackdropImage> _loadFromPrefs() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_libraryKey);
    final custom = <BackdropImage>[];

    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final entry in decoded) {
            try {
              if (entry is Map<String, dynamic>) {
                custom.add(BackdropImage.fromJson(entry));
              } else if (entry is Map) {
                custom.add(
                  BackdropImage.fromJson(
                    Map<String, dynamic>.from(entry),
                  ),
                );
              }
            } catch (_) {
              // Skip malformed entries.
            }
          }
        }
      } catch (_) {
        // Ignore malformed cache entries.
      }
    }

    return List.unmodifiable([...builtInBackdrops, ...custom]);
  }

  bool _isBuiltIn(String id) {
    for (final entry in builtInBackdrops) {
      if (entry.id == id) return true;
    }
    return false;
  }

  Future<void> _saveCustom(List<BackdropImage> images) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final custom =
        images.where((image) => !_isBuiltIn(image.id)).toList();
    final payload =
        jsonEncode(custom.map((image) => image.toJson()).toList());
    await prefs.setString(_libraryKey, payload);
  }

  void addImage(BackdropImage image) {
    final updated = [
      ...state.where((entry) => entry.id != image.id),
      image,
    ];
    state = List.unmodifiable(updated);
    _saveCustom(state);
  }

  void removeImage(String id) {
    if (_isBuiltIn(id)) return;
    state =
        List.unmodifiable(state.where((entry) => entry.id != id));
    _saveCustom(state);
  }

  BackdropImage? findById(String id) {
    for (final entry in state) {
      if (entry.id == id) return entry;
    }
    return null;
  }
}

final backdropLibraryProvider =
    NotifierProvider<BackdropLibraryNotifier, List<BackdropImage>>(
      BackdropLibraryNotifier.new,
    );

class BackdropSettingsNotifier extends Notifier<BackdropSettings> {
  static const _backdropIdKey = 'backdrop_settings_id';
  static const _brightnessKey = 'backdrop_settings_brightness';

  @override
  BackdropSettings build() {
    return _loadFromPrefs();
  }

  BackdropSettings _loadFromPrefs() {
    final prefs = ref.read(sharedPreferencesProvider);
    final defaultId =
        builtInBackdrops.isEmpty ? '' : builtInBackdrops.first.id;
    final id = prefs.getString(_backdropIdKey) ?? defaultId;
    final brightness = prefs.getDouble(_brightnessKey) ?? 0.0;
    return BackdropSettings(
      id: id,
      brightness: brightness.clamp(-1.0, 1.0),
    );
  }

  Future<void> _saveToPrefs() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (state.id.trim().isEmpty) {
      await prefs.remove(_backdropIdKey);
    } else {
      await prefs.setString(_backdropIdKey, state.id.trim());
    }
    await prefs.setDouble(_brightnessKey, state.brightness);
  }

  void setBackdropId(String id) {
    state = state.copyWith(id: id.trim());
    _saveToPrefs();
  }

  void setBrightness(double brightness) {
    state = state.copyWith(brightness: brightness.clamp(-1.0, 1.0));
    _saveToPrefs();
  }

  void reset() {
    final defaultId =
        builtInBackdrops.isEmpty ? '' : builtInBackdrops.first.id;
    state = BackdropSettings(id: defaultId, brightness: 0.0);
    _saveToPrefs();
  }
}

final backdropSettingsProvider =
    NotifierProvider<BackdropSettingsNotifier, BackdropSettings>(
      BackdropSettingsNotifier.new,
    );

// ========================================
// Debug Mode
// ========================================

class DebugModeNotifier extends Notifier<bool> {
  static const _debugKey = 'debug_mode_enabled';

  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_debugKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_debugKey, enabled);
  }
}

final debugModeProvider =
    NotifierProvider<DebugModeNotifier, bool>(DebugModeNotifier.new);

// ========================================
// Crash Reporting
// ========================================

const crashReportingPrefsKey = 'crash_reporting_enabled';
const crashReportingDefaultEnabled = false;
const crashReportingPromptedKey = 'crash_reporting_prompted_v1';

class CrashReportingNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(crashReportingPrefsKey) ??
        crashReportingDefaultEnabled;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(crashReportingPrefsKey, enabled);
  }
}

final crashReportingProvider =
    NotifierProvider<CrashReportingNotifier, bool>(
      CrashReportingNotifier.new,
    );

final crashReportingSyncProvider = Provider<void>((ref) {
  setCrashReportingEnabled(ref.read(crashReportingProvider));
  ref.listen<bool>(crashReportingProvider, (previous, next) {
    setCrashReportingEnabled(next);
  });
});

// ========================================
// Labs Mode
// ========================================

class LabsModeNotifier extends Notifier<bool> {
  static const _labsKey = 'labs_mode_enabled';

  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_labsKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_labsKey, enabled);
  }
}

final labsModeProvider =
    NotifierProvider<LabsModeNotifier, bool>(LabsModeNotifier.new);

// ========================================
// TTS Playback State Management
// ========================================

/// TTS Provider - single source of truth for playback
final ttsProvider = StateNotifierProvider<TtsService, TtsPlaybackState>((ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
});

/// Audio handler - overridden in main.dart to enable background controls.
final audioHandlerProvider = Provider<TtsAudioHandler>((ref) {
  throw UnimplementedError('AudioHandler must be overridden in ProviderScope');
});

/// Keep TTS engine settings in sync with persisted PlayerSettings.
final ttsSettingsSyncProvider = Provider<void>((ref) {
  final tts = ref.read(ttsProvider.notifier);
  tts.applySettings(ref.read(playerSettingsProvider));

  ref.listen<PlayerSettings>(playerSettingsProvider, (previous, next) {
    tts.applySettings(next);
  });
});

// ========================================
// Bucketed Progress
// ========================================

class BucketProgressArgs {
  final int bookId;
  final int chapterIndex;
  final int bucketCount;

  const BucketProgressArgs({
    required this.bookId,
    required this.chapterIndex,
    this.bucketCount = 64,
  });

  @override
  bool operator ==(Object other) {
    return other is BucketProgressArgs &&
        other.bookId == bookId &&
        other.chapterIndex == chapterIndex &&
        other.bucketCount == bucketCount;
  }

  @override
  int get hashCode => Object.hash(bookId, chapterIndex, bucketCount);
}

final bucketProgressProvider =
    StreamProvider.family<Uint8List, BucketProgressArgs>((ref, args) {
  return ref.watch(bookServiceProvider).watchBucketProgress(
        bookId: args.bookId,
        chapterIndex: args.chapterIndex,
        bucketCount: args.bucketCount,
      );
});

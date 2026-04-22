import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_riverpod/legacy.dart' show StateNotifierProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audiobookify/objectbox.g.dart';
import '../data/built_in_backdrops.dart';
import '../models/backdrop_image.dart';
import '../models/backdrop_settings.dart';
import '../services/book_service.dart';
import '../services/epub_service.dart';
import '../services/open_tts_backend.dart';
import '../services/speech_backend.dart';
import '../services/system_flutter_tts_backend.dart';
import '../services/open_library_service.dart';
import '../services/tts_audio_handler.dart';
import '../services/tts_debug_logging.dart';
import '../services/tts_service.dart';
import '../models/book_resume_position.dart';
import '../models/player_settings.dart';
import '../models/player_theme_settings.dart';
import '../models/public_book.dart';
import 'app_theme.dart';
import 'error_reporter.dart';
import '../services/bundled_kokoro_onnx.dart';

const String _playerSpeedKey = 'player_speed';
const String _playerPitchKey = 'player_pitch';
const String _playerBackendKey = 'player_backend';
const String _playerVoiceIdKey = 'player_voice_id';
const String _playerVoiceNameKey = 'player_voice_name';
const String _playerVoiceLocaleKey = 'player_voice_locale';
const String _openTtsExecutionProviderOverrideKey =
    'open_tts_execution_provider_override';

PlayerSettings loadPlayerSettingsFromPrefs(
  SharedPreferences prefs, {
  required bool preferOpenTts,
}) {
  final storedVoiceId = prefs.getString(_playerVoiceIdKey);
  final legacyVoiceName = prefs.getString(_playerVoiceNameKey);
  final legacyVoiceLocale = prefs.getString(_playerVoiceLocaleKey);
  final migratedVoiceId =
      storedVoiceId ??
      (legacyVoiceName != null && legacyVoiceLocale != null
          ? SystemFlutterTtsBackend.voiceIdFor(
              locale: legacyVoiceLocale,
              name: legacyVoiceName,
            )
          : null);

  final SpeechBackendKind backend;
  if (prefs.containsKey(_playerBackendKey)) {
    final backendName = prefs.getString(_playerBackendKey);
    backend = SpeechBackendKind.values.firstWhere(
      (candidate) => candidate.name == backendName,
      orElse: () => SpeechBackendKind.system,
    );
  } else if (prefs.containsKey(_playerVoiceNameKey) ||
      prefs.containsKey(_playerVoiceLocaleKey)) {
    backend = SpeechBackendKind.system;
  } else {
    backend = preferOpenTts
        ? SpeechBackendKind.openTts
        : SpeechBackendKind.system;
  }

  return PlayerSettings(
    speed: prefs.getDouble(_playerSpeedKey) ?? 1.0,
    pitch: prefs.getDouble(_playerPitchKey) ?? 1.0,
    backend: backend,
    voiceId: migratedVoiceId,
  );
}

OpenTtsExecutionProviderOverride loadOpenTtsExecutionProviderOverrideFromPrefs(
  SharedPreferences prefs,
) {
  return loadOpenTtsExecutionProviderOverrideFromName(
    prefs.getString(_openTtsExecutionProviderOverrideKey),
  );
}

/// ObjectBox Store provider - overridden in main.dart
final storeProvider = Provider<Store>((ref) {
  throw UnimplementedError('Store must be overridden in ProviderScope');
});

/// BookService provider - depends on Store
final bookServiceProvider = Provider<BookService>((ref) {
  return BookService(ref.read(storeProvider));
});

final epubServiceProvider = Provider<EpubService>((ref) {
  return EpubService();
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
  final prefs = ref.read(sharedPreferencesProvider);
  final service = OpenLibraryService(preferences: prefs);
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
    FutureProvider.family<List<PublicBook>, OpenLibrarySearchArgs>((ref, args) {
      return ref
          .read(openLibraryServiceProvider)
          .searchPublicDomain(
            query: args.query,
            page: args.page,
            limit: args.limit,
            language: args.language,
          );
    });

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
  @override
  PlayerSettings build() {
    return _loadFromPrefs();
  }

  PlayerSettings _loadFromPrefs() {
    final prefs = ref.read(sharedPreferencesProvider);
    return loadPlayerSettingsFromPrefs(
      prefs,
      preferOpenTts: ref.read(openTtsFactoryProvider) != null,
    );
  }

  Future<void> _saveToPrefs() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble(_playerSpeedKey, state.speed);
    await prefs.setDouble(_playerPitchKey, state.pitch);
    await prefs.setString(_playerBackendKey, state.backend.name);
    if (state.voiceId != null) {
      await prefs.setString(_playerVoiceIdKey, state.voiceId!);
    } else {
      await prefs.remove(_playerVoiceIdKey);
    }
    await prefs.remove(_playerVoiceNameKey);
    await prefs.remove(_playerVoiceLocaleKey);
  }

  void setSpeed(double speed) {
    state = state.copyWith(speed: speed.clamp(0.5, 2.0));
    _saveToPrefs();
  }

  void setPitch(double pitch) {
    state = state.copyWith(pitch: pitch.clamp(0.5, 2.0));
    _saveToPrefs();
  }

  void setBackend(SpeechBackendKind backend) {
    state = state.copyWith(backend: backend, voiceId: null);
    _saveToPrefs();
  }

  void setVoice(String? voiceId) {
    state = state.copyWith(voiceId: voiceId);
    _saveToPrefs();
  }

  void reset() {
    state = PlayerSettings(
      backend: ref.read(openTtsFactoryProvider) != null
          ? SpeechBackendKind.openTts
          : SpeechBackendKind.system,
    );
    _saveToPrefs();
  }
}

/// Player settings provider
final playerSettingsProvider =
    NotifierProvider<PlayerSettingsNotifier, PlayerSettings>(
      () => PlayerSettingsNotifier(),
    );

final openTtsFactoryProvider = Provider<OpenTtsFactory?>((ref) => null);

final coreMlBackendProvider = Provider<SpeechBackend?>((ref) => null);

final speechBackendsProvider = Provider<List<SpeechBackend>>((ref) {
  final backends = <SpeechBackend>[SystemFlutterTtsBackend()];
  final openTtsFactory = ref.watch(openTtsFactoryProvider);
  if (openTtsFactory != null) {
    backends.add(OpenTtsBackend(createOpenTts: openTtsFactory));
  }
  final coreMlBackend = ref.watch(coreMlBackendProvider);
  if (coreMlBackend != null) {
    backends.add(coreMlBackend);
  }
  return backends;
});

/// Player theme settings notifier with persistence.
class PlayerThemeSettingsNotifier extends Notifier<PlayerThemeSettings> {
  static const _fontFamilyKey = 'player_theme_font_family';
  static const _fontSizeKey = 'player_theme_font_size';
  static const _fontWeightKey = 'player_theme_font_weight';
  static const _lineHeightKey = 'player_theme_line_height';
  static const _paragraphSpacingKey = 'player_theme_paragraph_spacing';
  static const _paragraphIndentKey = 'player_theme_paragraph_indent';
  static const _pagePaddingHorizontalKey =
      'player_theme_page_padding_horizontal';
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
      fontFamily: (fontFamily == null || fontFamily.trim().isEmpty)
          ? null
          : fontFamily,
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
    if (settings.fontFamily == null || settings.fontFamily!.trim().isEmpty) {
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
      await prefs.setInt(_textColorKey, settings.textColor!.toARGB32());
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
                  BackdropImage.fromJson(Map<String, dynamic>.from(entry)),
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
    final custom = images.where((image) => !_isBuiltIn(image.id)).toList();
    final payload = jsonEncode(custom.map((image) => image.toJson()).toList());
    await prefs.setString(_libraryKey, payload);
  }

  void addImage(BackdropImage image) {
    final updated = [...state.where((entry) => entry.id != image.id), image];
    state = List.unmodifiable(updated);
    _saveCustom(state);
  }

  void removeImage(String id) {
    if (_isBuiltIn(id)) return;
    state = List.unmodifiable(state.where((entry) => entry.id != id));
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
    final defaultId = builtInBackdrops.isEmpty ? '' : builtInBackdrops.first.id;
    final id = prefs.getString(_backdropIdKey) ?? defaultId;
    final brightness = prefs.getDouble(_brightnessKey) ?? 0.0;
    return BackdropSettings(id: id, brightness: brightness.clamp(-1.0, 1.0));
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
    final defaultId = builtInBackdrops.isEmpty ? '' : builtInBackdrops.first.id;
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

final debugModeProvider = NotifierProvider<DebugModeNotifier, bool>(
  DebugModeNotifier.new,
);

class ImageDebugLoggingNotifier extends Notifier<bool> {
  static const _imageDebugKey = 'image_debug_logging_enabled';

  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_imageDebugKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_imageDebugKey, enabled);
  }
}

final imageDebugLoggingProvider =
    NotifierProvider<ImageDebugLoggingNotifier, bool>(
      ImageDebugLoggingNotifier.new,
    );

class TtsDebugLoggingNotifier extends Notifier<bool> {
  static const _ttsDebugKey = 'tts_debug_logging_enabled';

  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_ttsDebugKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_ttsDebugKey, enabled);
  }
}

final ttsDebugLoggingProvider = NotifierProvider<TtsDebugLoggingNotifier, bool>(
  TtsDebugLoggingNotifier.new,
);

final ttsDebugLoggingSyncProvider = Provider<void>((ref) {
  setTtsDebugLogsEnabled(ref.read(ttsDebugLoggingProvider));
  ref.listen<bool>(ttsDebugLoggingProvider, (previous, next) {
    setTtsDebugLogsEnabled(next);
  });
});

class OpenTtsExecutionProviderOverrideNotifier
    extends Notifier<OpenTtsExecutionProviderOverride> {
  @override
  OpenTtsExecutionProviderOverride build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return loadOpenTtsExecutionProviderOverrideFromPrefs(prefs);
  }

  Future<void> setOverride(OpenTtsExecutionProviderOverride override) async {
    state = override;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_openTtsExecutionProviderOverrideKey, override.name);
  }
}

final openTtsExecutionProviderOverrideProvider =
    NotifierProvider<
      OpenTtsExecutionProviderOverrideNotifier,
      OpenTtsExecutionProviderOverride
    >(OpenTtsExecutionProviderOverrideNotifier.new);

final openTtsExecutionProviderOverrideSyncProvider = Provider<void>((ref) {
  final tts = ref.read(ttsProvider.notifier);
  ref.listen<OpenTtsExecutionProviderOverride>(
    openTtsExecutionProviderOverrideProvider,
    (previous, next) {
      if (previous == null || previous == next) {
        return;
      }
      unawaited(
        tts.refreshOpenTtsExecutionProviderOverride(
          previous: previous,
          next: next,
        ),
      );
    },
  );
});

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

final crashReportingProvider = NotifierProvider<CrashReportingNotifier, bool>(
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

final labsModeProvider = NotifierProvider<LabsModeNotifier, bool>(
  LabsModeNotifier.new,
);

// ========================================
// TTS Playback State Management
// ========================================

/// TTS Provider - single source of truth for playback
final ttsProvider = StateNotifierProvider<TtsService, TtsPlaybackState>((ref) {
  final service = TtsService(
    backends: ref.read(speechBackendsProvider),
    initialSettings: ref.read(playerSettingsProvider),
  );
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
      return ref
          .watch(bookServiceProvider)
          .watchBucketProgress(
            bookId: args.bookId,
            chapterIndex: args.chapterIndex,
            bucketCount: args.bucketCount,
          );
    });

// ========================================
// Resume Position
// ========================================

class BookResumeNotifier extends Notifier<Map<int, BookResumePosition>> {
  static const _resumeKey = 'book_resume_positions_v1';
  static const _saveDebounce = Duration(milliseconds: 500);
  Timer? _saveTimer;
  late final SharedPreferences _prefs;
  Map<int, BookResumePosition> _latestState = const <int, BookResumePosition>{};

  @override
  Map<int, BookResumePosition> build() {
    _prefs = ref.read(sharedPreferencesProvider);
    final initialState = _loadFromPrefs();
    _latestState = initialState;
    ref.onDispose(() {
      _saveTimer?.cancel();
      _saveTimer = null;
      unawaited(_saveToPrefs(_latestState));
    });
    return initialState;
  }

  Map<int, BookResumePosition> _loadFromPrefs() {
    final raw = _prefs.getString(_resumeKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <int, BookResumePosition>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <int, BookResumePosition>{};
      final positions = <int, BookResumePosition>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final id = int.tryParse(key.toString());
        if (id == null) continue;
        final position = BookResumePosition.fromJson(entry.value);
        if (position != null) {
          positions[id] = position;
        }
      }
      return Map.unmodifiable(positions);
    } catch (_) {
      return const <int, BookResumePosition>{};
    }
  }

  Future<void> _saveToPrefs(Map<int, BookResumePosition> positions) async {
    final payload = <String, dynamic>{};
    for (final entry in positions.entries) {
      payload[entry.key.toString()] = entry.value.toJson();
    }
    await _prefs.setString(_resumeKey, jsonEncode(payload));
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () {
      _saveTimer = null;
      unawaited(_saveToPrefs(_latestState));
    });
  }

  void setPosition({
    required int bookId,
    required int chapterIndex,
    required int paragraphIndex,
    required int sentenceIndex,
  }) {
    final position = BookResumePosition(
      chapterIndex: chapterIndex.clamp(0, 1 << 30).toInt(),
      paragraphIndex: paragraphIndex.clamp(0, 1 << 30).toInt(),
      sentenceIndex: sentenceIndex.clamp(0, 1 << 30).toInt(),
      updatedAt: DateTime.now(),
    );
    final next = Map<int, BookResumePosition>.from(state)..[bookId] = position;
    state = Map.unmodifiable(next);
    _latestState = state;
    _scheduleSave();
  }

  void clearPosition(int bookId) {
    if (!state.containsKey(bookId)) return;
    final next = Map<int, BookResumePosition>.from(state)..remove(bookId);
    state = Map.unmodifiable(next);
    _latestState = state;
    unawaited(_saveToPrefs(_latestState));
  }

  void clearAll() {
    if (state.isEmpty) return;
    state = const <int, BookResumePosition>{};
    _latestState = state;
    unawaited(_saveToPrefs(_latestState));
  }
}

final bookResumeProvider =
    NotifierProvider<BookResumeNotifier, Map<int, BookResumePosition>>(
      BookResumeNotifier.new,
    );

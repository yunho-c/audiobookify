import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audiobookify_app5/objectbox.g.dart';
import '../services/book_service.dart';
import '../models/player_settings.dart';

/// ObjectBox Store provider - overridden in main.dart
final storeProvider = Provider<Store>((ref) {
  throw UnimplementedError('Store must be overridden in ProviderScope');
});

/// BookService provider - depends on Store
final bookServiceProvider = Provider<BookService>((ref) {
  return BookService(ref.read(storeProvider));
});

/// Reactive stream of all books
final booksProvider = StreamProvider((ref) {
  return ref.watch(bookServiceProvider).watchAllBooks();
});

/// SharedPreferences provider - overridden in main.dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'SharedPreferences must be overridden in ProviderScope',
  );
});

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

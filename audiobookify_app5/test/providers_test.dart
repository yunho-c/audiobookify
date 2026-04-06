import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audiobookify/core/app_theme.dart';
import 'package:audiobookify/core/providers.dart';
import 'package:audiobookify/models/player_settings.dart';
import 'package:audiobookify/services/system_flutter_tts_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemePreferenceNotifier persists selection', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(themePreferenceProvider), AppThemePreference.system);

    container
        .read(themePreferenceProvider.notifier)
        .setPreference(AppThemePreference.dark);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(container.read(themePreferenceProvider), AppThemePreference.dark);
    expect(prefs.getString('app_theme_preference'), 'dark');
  });

  test('PlayerSettingsNotifier clamps and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(playerSettingsProvider.notifier);
    final voiceId = SystemFlutterTtsBackend.voiceIdFor(
      locale: 'en-US',
      name: 'Test Voice',
    );

    notifier.setSpeed(3.5);
    notifier.setPitch(0.2);
    notifier.setBackend(SpeechBackendKind.openTts);
    notifier.setVoice(voiceId);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    final settings = container.read(playerSettingsProvider);
    expect(settings.speed, 2.0);
    expect(settings.pitch, 0.5);
    expect(settings.backend, SpeechBackendKind.openTts);
    expect(settings.voiceId, voiceId);

    expect(prefs.getDouble('player_speed'), 2.0);
    expect(prefs.getDouble('player_pitch'), 0.5);
    expect(prefs.getString('player_backend'), 'openTts');
    expect(prefs.getString('player_voice_id'), voiceId);
  });

  test('PlayerSettingsNotifier migrates legacy system voice prefs', () async {
    SharedPreferences.setMockInitialValues({
      'player_voice_name': 'Legacy Voice',
      'player_voice_locale': 'en-GB',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final settings = container.read(playerSettingsProvider);
    expect(settings.backend, SpeechBackendKind.system);
    expect(
      settings.voiceId,
      SystemFlutterTtsBackend.voiceIdFor(locale: 'en-GB', name: 'Legacy Voice'),
    );
  });

  test(
    'PlayerSettingsNotifier defaults fresh installs to OpenTTS when ready',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          openTtsFactoryProvider.overrideWithValue(_fakeOpenTtsFactory),
        ],
      );
      addTearDown(container.dispose);

      final settings = container.read(playerSettingsProvider);
      expect(settings.backend, SpeechBackendKind.openTts);
    },
  );

  test(
    'PlayerSettingsNotifier preserves persisted backend over OpenTTS default',
    () async {
      SharedPreferences.setMockInitialValues({'player_backend': 'system'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          openTtsFactoryProvider.overrideWithValue(_fakeOpenTtsFactory),
        ],
      );
      addTearDown(container.dispose);

      final settings = container.read(playerSettingsProvider);
      expect(settings.backend, SpeechBackendKind.system);
    },
  );

  test('CrashReportingNotifier defaults to opt-in and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(crashReportingProvider), isFalse);

    await container.read(crashReportingProvider.notifier).setEnabled(true);

    expect(container.read(crashReportingProvider), isTrue);
    expect(prefs.getBool(crashReportingPrefsKey), isTrue);
  });

  test('TtsDebugLoggingNotifier defaults to off and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(ttsDebugLoggingProvider), isFalse);

    await container.read(ttsDebugLoggingProvider.notifier).setEnabled(true);

    expect(container.read(ttsDebugLoggingProvider), isTrue);
    expect(prefs.getBool('tts_debug_logging_enabled'), isTrue);
  });
}

Future<Never> _fakeOpenTtsFactory(_) {
  throw UnimplementedError();
}

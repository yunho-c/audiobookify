import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audiobookify_app5/core/app_theme.dart';
import 'package:audiobookify_app5/core/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemePreferenceNotifier persists selection', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(themePreferenceProvider),
      AppThemePreference.system,
    );

    container
        .read(themePreferenceProvider.notifier)
        .setPreference(AppThemePreference.dark);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(
      container.read(themePreferenceProvider),
      AppThemePreference.dark,
    );
    expect(prefs.getString('app_theme_preference'), 'dark');
  });

  test('PlayerSettingsNotifier clamps and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(playerSettingsProvider.notifier);

    notifier.setSpeed(3.5);
    notifier.setPitch(0.2);
    notifier.setVoice('Test Voice', 'en-US');
    await Future<void>.delayed(const Duration(milliseconds: 1));

    final settings = container.read(playerSettingsProvider);
    expect(settings.speed, 2.0);
    expect(settings.pitch, 0.5);
    expect(settings.voiceName, 'Test Voice');
    expect(settings.voiceLocale, 'en-US');

    expect(prefs.getDouble('player_speed'), 2.0);
    expect(prefs.getDouble('player_pitch'), 0.5);
    expect(prefs.getString('player_voice_name'), 'Test Voice');
    expect(prefs.getString('player_voice_locale'), 'en-US');
  });
}

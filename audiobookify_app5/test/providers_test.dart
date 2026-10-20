import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audiobookify/core/app_theme.dart';
import 'package:audiobookify/core/providers.dart';
import 'package:audiobookify/models/player_settings.dart';
import 'package:audiobookify/services/speech_backend.dart';
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
    notifier.setBackend(SpeechBackendKind.mlsr);
    notifier.setVoice(voiceId);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    final settings = container.read(playerSettingsProvider);
    expect(settings.speed, 2.0);
    expect(settings.pitch, 0.5);
    expect(settings.backend, SpeechBackendKind.mlsr);
    expect(settings.voiceId, voiceId);

    expect(prefs.getDouble('player_speed'), 2.0);
    expect(prefs.getDouble('player_pitch'), 0.5);
    expect(prefs.getString('player_backend'), 'mlsr');
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
    'PlayerSettingsNotifier defaults fresh installs to MLSR when ready',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mlsrBackendProvider.overrideWithValue(_FakeRegisteredBackend()),
        ],
      );
      addTearDown(container.dispose);

      final settings = container.read(playerSettingsProvider);
      expect(settings.backend, SpeechBackendKind.mlsr);
    },
  );

  test(
    'PlayerSettingsNotifier preserves persisted backend over MLSR default',
    () async {
      SharedPreferences.setMockInitialValues({'player_backend': 'system'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mlsrBackendProvider.overrideWithValue(_FakeRegisteredBackend()),
        ],
      );
      addTearDown(container.dispose);

      final settings = container.read(playerSettingsProvider);
      expect(settings.backend, SpeechBackendKind.system);
    },
  );

  test('PlayerSettingsNotifier persists and reloads MLSR backend', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(playerSettingsProvider.notifier);
    notifier.setBackend(SpeechBackendKind.mlsr);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(
      container.read(playerSettingsProvider).backend,
      SpeechBackendKind.mlsr,
    );
    expect(prefs.getString('player_backend'), 'mlsr');

    final reloaded = loadPlayerSettingsFromPrefs(prefs, preferMlsr: true);
    expect(reloaded.backend, SpeechBackendKind.mlsr);
  });

  test('speechBackendsProvider includes the injected MLSR backend', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mlsrBackendProvider.overrideWithValue(_FakeRegisteredBackend()),
      ],
    );
    addTearDown(container.dispose);

    final backends = container.read(speechBackendsProvider);
    expect(
      backends.map((backend) => backend.backendId),
      contains(SpeechBackendKind.mlsr),
    );
  });

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

  for (final oldBackend in ['openTts', 'coreMlKokoro']) {
    for (final available in [true, false]) {
      test('migrate $oldBackend with MLSR available=$available', () async {
        SharedPreferences.setMockInitialValues({
          'player_backend': oldBackend,
          'player_voice_id': 'af_heart',
          'player_speed': 1.5,
          'player_pitch': 0.8,
          'open_tts_execution_provider_override': 'cpu',
          'book_resume_42': 'preserved',
        });
        final prefs = await SharedPreferences.getInstance();
        final expected = available
            ? SpeechBackendKind.mlsr
            : SpeechBackendKind.system;
        final before = loadPlayerSettingsFromPrefs(
          prefs,
          preferMlsr: available,
        );
        expect(before.backend, expected);
        expect(before.voiceId, isNull);
        await migrateSpeechPreferences(prefs, mlsrAvailable: available);
        await migrateSpeechPreferences(prefs, mlsrAvailable: available);
        final settings = loadPlayerSettingsFromPrefs(
          prefs,
          preferMlsr: available,
        );
        expect(settings.backend, expected);
        expect(settings.speed, 1.5);
        expect(settings.pitch, 0.8);
        expect(settings.voiceId, isNull);
        expect(prefs.getString('player_backend'), expected.name);
        expect(prefs.containsKey('player_voice_id'), isFalse);
        expect(
          prefs.containsKey('open_tts_execution_provider_override'),
          isFalse,
        );
        expect(prefs.getString('book_resume_42'), 'preserved');
      });
    }
  }

  test(
    'migration preserves explicit System voice and fresh MLSR voice',
    () async {
      for (final entry in {
        'system': 'en-US::Samantha',
        'mlsr': 'supertonic3:F1',
      }.entries) {
        SharedPreferences.setMockInitialValues({
          'player_backend': entry.key,
          'player_voice_id': entry.value,
        });
        final prefs = await SharedPreferences.getInstance();
        await migrateSpeechPreferences(prefs, mlsrAvailable: true);
        final settings = loadPlayerSettingsFromPrefs(prefs, preferMlsr: true);
        expect(settings.backend.name, entry.key);
        expect(settings.voiceId, entry.value);
      }
    },
  );

  test(
    'unavailable or unknown backend does not reuse its voice for System',
    () async {
      for (final backend in ['mlsr', 'obsolete']) {
        SharedPreferences.setMockInitialValues({
          'player_backend': backend,
          'player_voice_id': 'supertonic3:M1',
        });
        final prefs = await SharedPreferences.getInstance();
        final settings = loadPlayerSettingsFromPrefs(prefs, preferMlsr: false);
        expect(settings.backend, SpeechBackendKind.system);
        expect(settings.voiceId, isNull);
      }
    },
  );
}

class _FakeRegisteredBackend implements SpeechBackend {
  @override
  SpeechBackendKind get backendId => SpeechBackendKind.mlsr;

  @override
  SpeechBackendCapabilities get capabilities => const SpeechBackendCapabilities(
    supportsPitch: false,
    supportsVoiceSelection: true,
    supportsPause: true,
  );

  @override
  String get displayName => 'MLSR';

  @override
  Stream<SpeechBackendEvent> get events =>
      const Stream<SpeechBackendEvent>.empty();

  @override
  Future<void> applySettings(PlayerSettings settings) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<List<SpeechVoiceOption>> listVoices() async =>
      const <SpeechVoiceOption>[];

  @override
  Future<void> pause() async {}

  @override
  Future<void> speak(String text, {String? languageCode}) async {}

  @override
  Future<void> stop() async {}
}

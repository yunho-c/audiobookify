import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audiobookify/core/app_theme.dart';
import 'package:audiobookify/core/providers.dart';
import 'package:audiobookify/screens/settings_screen.dart';
import 'package:audiobookify/services/bundled_kokoro_onnx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'SettingsScreen toggles debug mode, crash reporting, tts debug logs, labs, and theme preference',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      Finder switchForTitle(String title) {
        final rowContainer = find.ancestor(
          of: find.text(title),
          matching: find.byType(Padding),
        );
        return find.descendant(
          of: rowContainer.first,
          matching: find.byType(Switch),
        );
      }

      final debugSwitchFinder = switchForTitle('Debug Mode');
      final crashSwitchFinder = switchForTitle('Crash Reporting');
      final ttsDebugSwitchFinder = switchForTitle('TTS Debug Logs');
      final labsSwitchFinder = switchForTitle('Labs');

      expect(debugSwitchFinder, findsOneWidget);
      expect(crashSwitchFinder, findsOneWidget);
      expect(ttsDebugSwitchFinder, findsOneWidget);
      expect(labsSwitchFinder, findsOneWidget);

      final debugSwitch = tester.widget<Switch>(debugSwitchFinder);
      final crashSwitch = tester.widget<Switch>(crashSwitchFinder);
      final ttsDebugSwitch = tester.widget<Switch>(ttsDebugSwitchFinder);
      final labsSwitch = tester.widget<Switch>(labsSwitchFinder);
      expect(debugSwitch.value, isFalse);
      expect(crashSwitch.value, isFalse);
      expect(ttsDebugSwitch.value, isFalse);
      expect(labsSwitch.value, isFalse);

      expect(find.text('Account'), findsNothing);
      expect(find.text('Log Out'), findsNothing);

      await tester.ensureVisible(find.text('Debug Mode'));
      await tester.tap(debugSwitchFinder);
      await tester.pumpAndSettle();
      expect(container.read(debugModeProvider), isTrue);
      expect(prefs.getBool('debug_mode_enabled'), isTrue);

      await tester.ensureVisible(find.text('Crash Reporting'));
      await tester.tap(crashSwitchFinder);
      await tester.pumpAndSettle();
      expect(container.read(crashReportingProvider), isTrue);
      expect(prefs.getBool(crashReportingPrefsKey), isTrue);

      await tester.ensureVisible(find.text('TTS Debug Logs'));
      await tester.tap(ttsDebugSwitchFinder);
      await tester.pumpAndSettle();
      expect(container.read(ttsDebugLoggingProvider), isTrue);
      expect(prefs.getBool('tts_debug_logging_enabled'), isTrue);

      await tester.ensureVisible(find.text('Labs'));
      await tester.tap(labsSwitchFinder);
      await tester.pumpAndSettle();
      expect(container.read(labsModeProvider), isTrue);
      expect(prefs.getBool('labs_mode_enabled'), isTrue);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);

      await tester.ensureVisible(find.text('Dark'));
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(container.read(themePreferenceProvider), AppThemePreference.dark);
      expect(prefs.getString('app_theme_preference'), 'dark');
    },
  );

  testWidgets(
    'SettingsScreen shows and persists the OpenTTS execution provider override when available',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          openTtsFactoryProvider.overrideWithValue(_fakeOpenTtsFactory),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      final options = bundledKokoroProviderOverridesForPlatform(
        Platform.operatingSystem,
      );
      if (options.length <= 1) {
        expect(find.text('OpenTTS Execution Provider'), findsNothing);
        return;
      }

      final targetOption = options.last;
      final targetLabel = bundledKokoroProviderOverrideLabel(
        targetOption,
        Platform.operatingSystem,
      );

      await tester.ensureVisible(find.text('OpenTTS Execution Provider'));
      await tester.tap(find.text('OpenTTS Execution Provider'));
      await tester.pumpAndSettle();

      expect(find.text(targetLabel), findsWidgets);

      await tester.tap(find.text(targetLabel).last);
      await tester.pumpAndSettle();

      expect(
        container.read(openTtsExecutionProviderOverrideProvider),
        targetOption,
      );
      expect(
        prefs.getString('open_tts_execution_provider_override'),
        targetOption.name,
      );
    },
  );
}

Future<Never> _fakeOpenTtsFactory(_) {
  throw UnimplementedError();
}

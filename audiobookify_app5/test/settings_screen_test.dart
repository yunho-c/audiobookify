import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audiobookify_app5/core/app_theme.dart';
import 'package:audiobookify_app5/core/providers.dart';
import 'package:audiobookify_app5/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'SettingsScreen toggles debug mode, crash reporting, labs, and theme preference',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(3));

    final debugSwitch = tester.widget<Switch>(switches.at(0));
    final crashSwitch = tester.widget<Switch>(switches.at(1));
    final labsSwitch = tester.widget<Switch>(switches.at(2));
    expect(debugSwitch.value, isFalse);
    expect(crashSwitch.value, isTrue);
    expect(labsSwitch.value, isFalse);

    expect(find.text('Account'), findsNothing);
    expect(find.text('Log Out'), findsNothing);

    await tester.tap(switches.at(0));
    await tester.pumpAndSettle();
    expect(container.read(debugModeProvider), isTrue);
    expect(prefs.getBool('debug_mode_enabled'), isTrue);

    await tester.tap(switches.at(1));
    await tester.pumpAndSettle();
    expect(container.read(crashReportingProvider), isFalse);
    expect(prefs.getBool(crashReportingPrefsKey), isFalse);

    await tester.tap(switches.at(2));
    await tester.pumpAndSettle();
    expect(container.read(labsModeProvider), isTrue);
    expect(prefs.getBool('labs_mode_enabled'), isTrue);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(themePreferenceProvider), AppThemePreference.dark);
    expect(prefs.getString('app_theme_preference'), 'dark');
  });
}

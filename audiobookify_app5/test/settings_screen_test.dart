import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audiobookify_app5/core/app_theme.dart';
import 'package:audiobookify_app5/core/providers.dart';
import 'package:audiobookify_app5/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SettingsScreen toggles debug mode and theme preference',
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

    final debugSwitchFinder = find.byType(Switch);
    expect(debugSwitchFinder, findsOneWidget);
    final debugSwitch =
        tester.widget<Switch>(debugSwitchFinder);
    expect(debugSwitch.value, isFalse);

    await tester.tap(debugSwitchFinder);
    await tester.pumpAndSettle();
    expect(container.read(debugModeProvider), isTrue);
    expect(prefs.getBool('debug_mode_enabled'), isTrue);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(themePreferenceProvider), AppThemePreference.dark);
    expect(prefs.getString('app_theme_preference'), 'dark');
  });
}

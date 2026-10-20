import 'package:audiobookify/core/providers.dart';
import 'package:audiobookify/services/tts_service.dart';
import 'package:audiobookify/widgets/settings_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tts_service_test.dart' show FakeSpeechBackend;

void main() {
  Future<(ProviderContainer, SharedPreferences, FakeSpeechBackend)>
  openSettings(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'player_backend': 'mlsr'});
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeSpeechBackend();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mlsrBackendProvider.overrideWithValue(backend),
        speechBackendsProvider.overrideWithValue([backend]),
      ],
    );
    final service = container.read(ttsProvider.notifier);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                ref.watch(ttsSettingsSyncProvider);
                return SettingsWheel(onClose: () {});
              },
            ),
          ),
        ),
      ),
    );
    service.loadContent(['Keep reading this sentence.']);
    await service.play();
    await tester.pumpAndSettle();
    expect(service.playbackState.status, TtsStatus.playing);
    expect(backend.settings.last.speed, 1.0);
    return (container, prefs, backend);
  }

  testWidgets('speed buttons apply and persist the displayed value', (
    tester,
  ) async {
    final (container, prefs, backend) = await openSettings(tester);
    await tester.tap(find.byTooltip('Increase').first);
    await tester.pumpAndSettle();
    expect(find.text('1.1x'), findsOneWidget);
    expect(container.read(playerSettingsProvider).speed, 1.1);
    expect(backend.settings.last.speed, 1.1);
    expect(prefs.getDouble('player_speed'), 1.1);

    await tester.tap(find.byTooltip('Decrease').first);
    await tester.pumpAndSettle();
    expect(find.text('1.0x'), findsOneWidget);
    expect(container.read(playerSettingsProvider).speed, 1.0);
    expect(backend.settings.last.speed, 1.0);
    expect(prefs.getDouble('player_speed'), 1.0);
  });

  testWidgets('speed drag applies a displayed tenth only when released', (
    tester,
  ) async {
    final (container, prefs, backend) = await openSettings(tester);
    final slider = find.byType(Slider).first;
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(13, 0));
    await tester.pump();
    expect(container.read(playerSettingsProvider).speed, 1.0);
    expect(backend.settings.last.speed, 1.0);
    await gesture.up();
    await tester.pumpAndSettle();

    final speed = container.read(playerSettingsProvider).speed;
    expect(speed, greaterThan(1.0));
    expect(speed, double.parse(speed.toStringAsFixed(1)));
    expect(find.text('${speed.toStringAsFixed(1)}x'), findsOneWidget);
    expect(backend.settings.last.speed, speed);
    expect(prefs.getDouble('player_speed'), speed);
    expect(loadPlayerSettingsFromPrefs(prefs, preferMlsr: true).speed, speed);
  });
}

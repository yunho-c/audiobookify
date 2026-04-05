import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audiobookify/core/providers.dart';
import 'package:audiobookify/screens/settings_screen.dart';
import 'package:audiobookify/widgets/bottom_nav.dart';
import 'package:audiobookify/widgets/player_controls.dart';
import 'package:audiobookify/widgets/shared/pressable.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const packageInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/package_info',
  );
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, (call) async {
          if (call.method == 'getAll') {
            return <String, dynamic>{
              'appName': 'Audiobookify',
              'packageName': 'dev.audiobookify.test',
              'version': '1.0.0',
              'buildNumber': '1',
              'buildSignature': '',
            };
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          if (call.method == 'checkPermissionStatus') {
            return 1;
          }
          if (call.method == 'requestPermissions') {
            return <int, int>{17: 1};
          }
          if (call.method == 'openAppSettings') {
            return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  testWidgets('enabled pressable exposes click cursor and button semantics', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Pressable(onTap: _noop, child: Text('Open')),
          ),
        ),
      );

      final focusable = tester.widget<FocusableActionDetector>(
        find.byType(FocusableActionDetector),
      );
      expect(focusable.mouseCursor, SystemMouseCursors.click);
      expect(
        tester.getSemantics(find.byType(Pressable)),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets(
    'disabled pressable exposes basic cursor and disabled semantics',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Pressable(
                enabled: false,
                onTap: _noop,
                child: Text('Disabled'),
              ),
            ),
          ),
        );

        final focusable = tester.widget<FocusableActionDetector>(
          find.byType(FocusableActionDetector),
        );
        expect(focusable.mouseCursor, SystemMouseCursors.basic);
        expect(
          tester.getSemantics(find.byType(Pressable)),
          matchesSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
          ),
        );
      } finally {
        semanticsHandle.dispose();
      }
    },
  );

  testWidgets('pressable activates on Enter and Space', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Pressable(
            focusNode: focusNode,
            onTap: () => taps += 1,
            child: const Text('Activate'),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(taps, 2);
  });

  testWidgets('bottom navigation items use shared click cursor behavior', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(bottomNavigationBar: BottomNav(currentIndex: 0)),
      ),
    );

    final focusable = tester.widget<FocusableActionDetector>(
      find.ancestor(
        of: find.byIcon(LucideIcons.home),
        matching: find.byType(FocusableActionDetector),
      ),
    );
    expect(focusable.mouseCursor, SystemMouseCursors.click);
  });

  testWidgets('player play control uses shared click cursor behavior', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerControls(
            isPlaying: false,
            progress: 0.2,
            onPlayPause: _noop,
          ),
        ),
      ),
    );

    final focusable = tester.widget<FocusableActionDetector>(
      find.ancestor(
        of: find.byIcon(LucideIcons.play),
        matching: find.byType(FocusableActionDetector),
      ),
    );
    expect(focusable.mouseCursor, SystemMouseCursors.click);
  });

  testWidgets('settings rows use shared click cursor behavior', (tester) async {
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
    await _pumpUntilFound(tester, find.text('Crash Reporting Details'));

    final focusable = tester.widget<FocusableActionDetector>(
      find.ancestor(
        of: find.text('Crash Reporting Details'),
        matching: find.byType(FocusableActionDetector),
      ),
    );
    expect(focusable.mouseCursor, SystemMouseCursors.click);
  });
}

void _noop() {}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxTries = 20,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < maxTries; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Could not find widget: $finder');
}

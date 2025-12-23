import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audiobookify/src/rust/frb_generated.dart';
import 'package:audiobookify/objectbox.g.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/app_theme.dart';
import 'core/error_reporter.dart';
import 'core/nav_transition.dart';
import 'core/providers.dart';
import 'core/route_observer.dart';
import 'widgets/bottom_nav.dart';
import 'screens/home_screen.dart';
import 'screens/book_detail_screen.dart';
import 'screens/player_screen.dart';
import 'screens/create_screen.dart';
import 'screens/settings_screen.dart';
import 'services/tts_audio_handler.dart';
import 'services/tts_service.dart';

Future<void> main() async {
  return runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      _initErrorHandling();

      final prefs = await SharedPreferences.getInstance();
      setCrashReportingEnabled(
        prefs.getBool(crashReportingPrefsKey) ?? crashReportingDefaultEnabled,
      );

      final dsn = const String.fromEnvironment('SENTRY_DSN');
      if (dsn.isEmpty) {
        await _startApp(prefs);
        return;
      }

      await SentryFlutter.init(
        (options) {
          options.dsn = dsn;
          final environment = const String.fromEnvironment('APP_ENV');
          options.environment =
              environment.isNotEmpty
                  ? environment
                  : (kReleaseMode ? 'production' : 'development');
          final release = const String.fromEnvironment('APP_RELEASE');
          if (release.isNotEmpty) {
            options.release = release;
          }
          final crashReportingEnabled = isCrashReportingEnabled;
          options.tracesSampleRate = crashReportingEnabled ? 0.1 : 0.0;
          options.enableAutoSessionTracking = crashReportingEnabled;
          options.enableAutoPerformanceTracing = crashReportingEnabled;
          options.beforeSend = (event, hint) {
            return isCrashReportingEnabled ? event : null;
          };
          options.beforeSendTransaction = (transaction, hint) {
            return isCrashReportingEnabled ? transaction : null;
          };
        },
        appRunner: () => _startApp(prefs),
      );
    },
    (error, stackTrace) {
      reportError(error, stackTrace, context: 'zone');
    },
  );
}

Future<void> _startApp(SharedPreferences prefs) async {
  try {
    // Initialize flutter_rust_bridge
    await RustLib.init();

    // Initialize ObjectBox
    final appDir = await getApplicationDocumentsDirectory();
    final store = await openStore(directory: '${appDir.path}/objectbox');

    // Initialize SharedPreferences
    await _maybeRequestAndroidNotificationPermission(prefs);

    // Initialize audio handler + TTS service for background controls.
    final ttsService = TtsService();
    final audioHandler = await AudioService.init(
      builder: () => TtsAudioHandler(ttsService),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'audiobookify.playback',
        androidNotificationChannelName: 'Audiobookify Playback',
        androidNotificationChannelDescription: 'Audiobookify playback controls',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );

    runApp(
      ProviderScope(
        overrides: [
          storeProvider.overrideWithValue(store),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ttsProvider.overrideWith((ref) => ttsService),
          audioHandlerProvider.overrideWithValue(
            audioHandler as TtsAudioHandler,
          ),
        ],
        child: const AudiobookifyApp(),
      ),
    );
  } catch (error, stackTrace) {
    reportError(error, stackTrace, context: 'startup');
    runApp(
      _BootstrapErrorApp(
        message: _startupErrorMessage(error, stackTrace),
      ),
    );
  }
}

Future<void> _maybeRequestAndroidNotificationPermission(
  SharedPreferences prefs,
) async {
  if (!Platform.isAndroid) return;
  const key = 'notification_permission_prompted_v1';
  if (prefs.getBool(key) ?? false) return;
  try {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  } catch (_) {
    // Ignore permission request failures.
  } finally {
    await prefs.setBool(key, true);
  }
}

void _initErrorHandling() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reportError(
      details.exception,
      details.stack ?? StackTrace.current,
      context: 'flutter',
    );
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    reportError(error, stackTrace, context: 'platform');
    return true;
  };
}

String _startupErrorMessage(Object error, StackTrace stackTrace) {
  if (kDebugMode) {
    return '$error\n\n$stackTrace';
  }
  return 'Please restart the app. If the problem persists, reinstall.';
}

class _BootstrapErrorApp extends StatelessWidget {
  final String message;

  const _BootstrapErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'App failed to start',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AudiobookifyApp extends ConsumerWidget {
  const AudiobookifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ttsSettingsSyncProvider);
    ref.watch(crashReportingSyncProvider);
    final themePreference = ref.watch(themePreferenceProvider);
    return MaterialApp.router(
      title: 'Audiobookify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(themePreference),
      darkTheme: AppTheme.dark,
      themeMode: AppTheme.modeFor(themePreference),
      routerConfig: _router,
    );
  }
}

/// Shell widget that wraps pages with the bottom navigation bar
class AppShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;

  const AppShell({super.key, required this.child, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: BottomNav(currentIndex: currentIndex),
    );
  }
}

/// Router configuration with shell for bottom nav
final _router = GoRouter(
  initialLocation: '/',
  observers: [routeObserver],
  routes: [
    // Shell route for pages with bottom nav
    ShellRoute(
      builder: (context, state, child) {
        int index = 0;
        final location = state.uri.path;
        if (location.startsWith('/create')) {
          index = 1;
        } else if (location.startsWith('/settings')) {
          index = 2;
        }
        return AppShell(currentIndex: index, child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              _navTransitionPage(state, const HomeScreen()),
        ),
        GoRoute(
          path: '/create',
          pageBuilder: (context, state) =>
              _navTransitionPage(state, const CreateScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              _navTransitionPage(state, const SettingsScreen()),
        ),
      ],
    ),
    // Routes without bottom nav
    GoRoute(
      path: '/book/:id',
      builder: (context, state) =>
          BookDetailScreen(bookId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/player/:id',
      builder: (context, state) =>
          PlayerScreen(bookId: state.pathParameters['id']!),
    ),
  ],
);

CustomTransitionPage<void> _navTransitionPage(
  GoRouterState state,
  Widget child,
) {
  final extra = state.extra;
  final isForward =
      extra is NavTransitionData ? extra.isForward : true;
  final isCreateRoute = state.uri.path.startsWith('/create');
  final beginOffset = isCreateRoute
      ? (isForward ? const Offset(0, 0.12) : const Offset(0, -0.12))
      : (isForward ? const Offset(0.12, 0) : const Offset(-0.12, 0));
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return SlideTransition(
        position: Tween<Offset>(
          begin: beginOffset,
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audiobookify_app5/src/rust/frb_generated.dart';
import 'package:audiobookify_app5/objectbox.g.dart';
import 'package:audiobookify_app5/services/book_service.dart';
import 'core/app_theme.dart';
import 'widgets/bottom_nav.dart';
import 'screens/home_screen.dart';
import 'screens/book_detail_screen.dart';
import 'screens/player_screen.dart';
import 'screens/create_screen.dart';
import 'screens/settings_screen.dart';

/// Global ObjectBox store and services
late final Store objectboxStore;
late final BookService bookService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flutter_rust_bridge
  await RustLib.init();

  // Initialize ObjectBox
  final appDir = await getApplicationDocumentsDirectory();
  objectboxStore = await openStore(directory: '${appDir.path}/objectbox');
  bookService = BookService(objectboxStore);

  runApp(const AudiobookifyApp());
}

class AudiobookifyApp extends StatelessWidget {
  const AudiobookifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Audiobookify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
      body: child,
      bottomNavigationBar: BottomNav(currentIndex: currentIndex),
    );
  }
}

/// Router configuration with shell for bottom nav
final _router = GoRouter(
  initialLocation: '/',
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
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/create',
          builder: (context, state) => const CreateScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
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

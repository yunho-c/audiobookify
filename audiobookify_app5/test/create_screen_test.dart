import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audiobookify/core/providers.dart';
import 'package:audiobookify/models/open_library_work.dart';
import 'package:audiobookify/models/public_book.dart';
import 'package:audiobookify/screens/create_screen.dart';
import 'package:audiobookify/services/open_library_service.dart';
import 'package:audiobookify/widgets/shared/pressable.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CreateScreen shows Open Library results after search', (
    WidgetTester tester,
  ) async {
    final results = [
      const PublicBook(
        title: 'Sherlock Holmes',
        authors: ['Arthur Conan Doyle'],
        firstPublishYear: 1892,
        coverUrl: null,
        epubUrl: 'https://example.com/sherlock.epub',
        key: '/works/OL1W',
        iaId: 'sherlockholmes',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openLibrarySearchProvider.overrideWith((ref, args) async => results),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: const CreateScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Sherlock');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Results for "Sherlock"'), findsOneWidget);
    expect(find.text('Sherlock Holmes'), findsOneWidget);
    expect(find.text('Arthur Conan Doyle • 1892'), findsOneWidget);
  });

  testWidgets('CreateScreen formats html descriptions in details sheet', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final results = [
      const PublicBook(
        title: 'Sherlock Holmes',
        authors: ['Arthur Conan Doyle'],
        firstPublishYear: 1892,
        coverUrl: null,
        epubUrl: 'https://example.com/sherlock.epub',
        key: '/works/OL1W',
        iaId: 'sherlockholmes',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          openLibrarySearchProvider.overrideWith((ref, args) async => results),
          openLibraryServiceProvider.overrideWithValue(
            _FakeOpenLibraryService(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: const CreateScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sherlock');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final cardFinder = find.ancestor(
      of: find.text('Sherlock Holmes').first,
      matching: find.byType(Pressable),
    );
    await tester.ensureVisible(cardFinder.first);
    await tester.tap(cardFinder.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('A mystery unfolds.\n\n• Clue one\n• Clue two'),
      findsOneWidget,
    );
    expect(find.textContaining('<p>'), findsNothing);
    expect(find.textContaining('<li>'), findsNothing);
  });
}

class _FakeOpenLibraryService extends OpenLibraryService {
  _FakeOpenLibraryService()
    : super(preferences: null, networkChecker: () async => true);

  @override
  Future<OpenLibraryWork?> fetchWorkDetails(String key) async {
    return const OpenLibraryWork(
      title: 'Sherlock Holmes',
      description:
          '<p>A mystery <em>unfolds</em>.</p><ul><li>Clue one</li><li>Clue two</li></ul>',
      subjects: ['Mystery'],
      firstPublishDate: '1892',
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:audiobookify_app5/core/providers.dart';
import 'package:audiobookify_app5/models/public_book.dart';
import 'package:audiobookify_app5/screens/create_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CreateScreen shows Open Library results after search',
      (WidgetTester tester) async {
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
          openLibrarySearchProvider.overrideWith(
            (ref, args) async => results,
          ),
        ],
        child: const MaterialApp(
          home: CreateScreen(),
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
}

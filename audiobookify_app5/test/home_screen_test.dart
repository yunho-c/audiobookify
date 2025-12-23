import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:audiobookify/core/providers.dart';
import 'package:audiobookify/models/book.dart';
import 'package:audiobookify/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HomeScreen shows continue listening for in-progress book',
      (WidgetTester tester) async {
    final bookA = Book(
      id: 1,
      title: 'Alpha',
      author: 'Author A',
      chapterCount: 10,
      filePath: 'alpha.epub',
      progress: 25,
      addedAt: DateTime(2024, 1, 10),
    );
    final bookB = Book(
      id: 2,
      title: 'Bravo',
      author: 'Author B',
      chapterCount: 20,
      filePath: 'bravo.epub',
      progress: 60,
      addedAt: DateTime(2024, 2, 5),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith((ref) => Stream.value([bookA, bookB])),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Continue Listening'), findsOneWidget);
    expect(find.text('Bravo'), findsWidgets);
    expect(find.text('Chapter 12 of 20'), findsOneWidget);
    expect(find.text('2 titles'), findsOneWidget);
  });

  testWidgets('HomeScreen hides continue section when nothing in progress',
      (WidgetTester tester) async {
    final completed = Book(
      id: 3,
      title: 'Completed',
      author: 'Author C',
      chapterCount: 12,
      filePath: 'completed.epub',
      progress: 100,
      addedAt: DateTime(2024, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith((ref) => Stream.value([completed])),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Continue Listening'), findsNothing);
    expect(find.text('1 titles'), findsOneWidget);
  });
}

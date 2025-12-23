import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audiobookify/main.dart';
import 'package:audiobookify/core/providers.dart';
import 'package:audiobookify/models/book.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots to empty library', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ttsSettingsSyncProvider.overrideWith((ref) {}),
          booksProvider.overrideWith(
            (ref) => Stream.value(<Book>[]),
          ),
        ],
        child: const AudiobookifyApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('No books yet'), findsOneWidget);
  });
}

import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:audiobookify/core/providers.dart';
import 'package:audiobookify/main.dart';
import 'package:audiobookify/models/book.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots and navigates to create', (WidgetTester tester) async {
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

    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();
    expect(find.text('Create Audiobook'), findsOneWidget);
  });
}

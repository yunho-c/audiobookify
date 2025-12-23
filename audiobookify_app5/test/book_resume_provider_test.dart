import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audiobookify/core/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('book resume state persists the latest position', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(bookResumeProvider.notifier);
    notifier.setPosition(
      bookId: 7,
      chapterIndex: 1,
      paragraphIndex: 2,
      sentenceIndex: 3,
    );
    notifier.setPosition(
      bookId: 7,
      chapterIndex: 4,
      paragraphIndex: 5,
      sentenceIndex: 6,
    );

    await Future<void>.delayed(const Duration(milliseconds: 650));

    final restoredContainer = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(restoredContainer.dispose);

    final restored = restoredContainer.read(bookResumeProvider)[7];
    expect(restored, isNotNull);
    expect(restored!.chapterIndex, 4);
    expect(restored.paragraphIndex, 5);
    expect(restored.sentenceIndex, 6);
  });

  test('book resume state clears positions', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(bookResumeProvider.notifier);
    notifier.setPosition(
      bookId: 2,
      chapterIndex: 0,
      paragraphIndex: 1,
      sentenceIndex: 0,
    );
    await Future<void>.delayed(const Duration(milliseconds: 650));

    notifier.clearPosition(2);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final restoredContainer = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(restoredContainer.dispose);

    final restored = restoredContainer.read(bookResumeProvider)[2];
    expect(restored, isNull);
  });
}

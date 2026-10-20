import 'package:audiobookify/services/tts_service.dart';
import 'package:audiobookify/widgets/speech_status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'preparation stays hidden while persistent fallback offers retry',
    (tester) async {
      var retries = 0;
      Future<void> show(TtsPlaybackState state) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpeechStatusBar(state: state, onRetry: () => retries++),
          ),
        ),
      );
      await show(const TtsPlaybackState());
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      await show(const TtsPlaybackState(isPreparing: true));
      expect(find.text('Preparing speech…'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      await show(
        const TtsPlaybackState(
          status: TtsStatus.playing,
          notice: 'MLSR is unavailable. Using System voice.',
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text('MLSR is unavailable. Using System voice.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    },
  );
}

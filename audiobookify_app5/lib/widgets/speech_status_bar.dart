import 'package:flutter/material.dart';

import '../services/tts_service.dart';

/// Shows actionable speech notices without surfacing transient preparation.
class SpeechStatusBar extends StatelessWidget {
  const SpeechStatusBar({
    super.key,
    required this.state,
    required this.onRetry,
  });

  final TtsPlaybackState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final notice = state.notice;
    if (notice == null) {
      return const SizedBox.shrink();
    }
    return Semantics(
      liveRegion: true,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(notice)),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

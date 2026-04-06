import 'dart:developer' as developer;

class TtsDebugLogging {
  static bool enabled = false;
}

void setTtsDebugLogsEnabled(bool enabled) {
  TtsDebugLogging.enabled = enabled;
}

void logTtsDebug(
  String message, {
  String category = 'tts',
  Object? error,
  StackTrace? stackTrace,
}) {
  if (!TtsDebugLogging.enabled) {
    return;
  }
  developer.log(
    message,
    name: 'audiobookify:$category',
    error: error,
    stackTrace: stackTrace,
  );
}

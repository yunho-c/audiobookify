import 'dart:async';
import 'dart:developer';
import 'package:sentry_flutter/sentry_flutter.dart';

bool _crashReportingEnabled = false;

bool get isCrashReportingEnabled => _crashReportingEnabled;

void setCrashReportingEnabled(bool enabled) {
  _crashReportingEnabled = enabled;
}

void reportError(
  Object error,
  StackTrace stackTrace, {
  String? context,
}) {
  final name = context == null ? 'audiobookify' : 'audiobookify:$context';
  log(
    'Unhandled error',
    name: name,
    error: error,
    stackTrace: stackTrace,
  );
  if (!_crashReportingEnabled) return;
  unawaited(
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
    ),
  );
}

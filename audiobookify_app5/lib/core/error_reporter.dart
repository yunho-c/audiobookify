import 'dart:async';
import 'dart:developer';
import 'package:sentry_flutter/sentry_flutter.dart';

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
  unawaited(
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
    ),
  );
}

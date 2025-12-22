import 'dart:developer';

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
}

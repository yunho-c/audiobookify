import 'package:kokoro_flutter/kokoro_flutter.dart';

abstract interface class ManagedOpenTtsAudioRenderer
    implements OpenTtsAudioRenderer {
  void Function(String requestId)? get onPlaybackStart;
  set onPlaybackStart(void Function(String requestId)? callback);

  void Function(String requestId)? get onPlaybackComplete;
  set onPlaybackComplete(void Function(String requestId)? callback);

  Future<void> dispose();
}

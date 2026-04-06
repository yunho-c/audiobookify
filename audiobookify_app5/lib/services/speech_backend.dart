import 'dart:async';

import '../models/player_settings.dart';

enum SpeechBackendEventType { start, complete, error }

class SpeechBackendEvent {
  final SpeechBackendEventType type;
  final String? message;

  const SpeechBackendEvent({required this.type, this.message});
}

class SpeechBackendCapabilities {
  final bool supportsPitch;
  final bool supportsVoiceSelection;
  final bool supportsPause;

  const SpeechBackendCapabilities({
    required this.supportsPitch,
    required this.supportsVoiceSelection,
    required this.supportsPause,
  });
}

class SpeechVoiceOption {
  final SpeechBackendKind backend;
  final String id;
  final String label;
  final String? languageCode;
  final String? localeLabel;
  final String? gender;

  const SpeechVoiceOption({
    required this.backend,
    required this.id,
    required this.label,
    this.languageCode,
    this.localeLabel,
    this.gender,
  });
}

abstract class SpeechBackend {
  SpeechBackendKind get backendId;

  String get displayName;

  SpeechBackendCapabilities get capabilities;

  Stream<SpeechBackendEvent> get events;

  Future<void> initialize();

  Future<void> dispose();

  Future<List<SpeechVoiceOption>> listVoices();

  Future<void> applySettings(PlayerSettings settings);

  Future<void> speak(String text);

  Future<void> pause();

  Future<void> stop();
}

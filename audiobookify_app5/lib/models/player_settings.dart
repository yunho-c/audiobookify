import 'package:flutter/material.dart';

enum SpeechBackendKind { system, mlsr }

extension SpeechBackendKindLabel on SpeechBackendKind {
  String get label {
    switch (this) {
      case SpeechBackendKind.system:
        return 'System';
      case SpeechBackendKind.mlsr:
        return 'MLSR';
    }
  }
}

/// Model for player settings (speed, pitch, voice)
@immutable
class PlayerSettings {
  final double speed; // 0.5 - 2.0
  final double pitch; // 0.5 - 2.0
  final SpeechBackendKind backend;
  final String? voiceId;

  const PlayerSettings({
    this.speed = 1.0,
    this.pitch = 1.0,
    this.backend = SpeechBackendKind.system,
    this.voiceId,
  });

  PlayerSettings copyWith({
    double? speed,
    double? pitch,
    SpeechBackendKind? backend,
    Object? voiceId = _sentinel,
  }) {
    return PlayerSettings(
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      backend: backend ?? this.backend,
      voiceId: identical(voiceId, _sentinel)
          ? this.voiceId
          : voiceId as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerSettings &&
          runtimeType == other.runtimeType &&
          speed == other.speed &&
          pitch == other.pitch &&
          backend == other.backend &&
          voiceId == other.voiceId;

  @override
  int get hashCode =>
      speed.hashCode ^ pitch.hashCode ^ backend.hashCode ^ voiceId.hashCode;
}

const Object _sentinel = Object();

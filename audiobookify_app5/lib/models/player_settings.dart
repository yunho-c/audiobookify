import 'package:flutter/material.dart';

/// Model for player settings (speed, pitch, voice)
@immutable
class PlayerSettings {
  final double speed; // 0.5 - 2.0
  final double pitch; // 0.5 - 2.0
  final String? voiceName;
  final String? voiceLocale;

  const PlayerSettings({
    this.speed = 1.0,
    this.pitch = 1.0,
    this.voiceName,
    this.voiceLocale,
  });

  PlayerSettings copyWith({
    double? speed,
    double? pitch,
    String? voiceName,
    String? voiceLocale,
  }) {
    return PlayerSettings(
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      voiceName: voiceName ?? this.voiceName,
      voiceLocale: voiceLocale ?? this.voiceLocale,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerSettings &&
          runtimeType == other.runtimeType &&
          speed == other.speed &&
          pitch == other.pitch &&
          voiceName == other.voiceName &&
          voiceLocale == other.voiceLocale;

  @override
  int get hashCode =>
      speed.hashCode ^
      pitch.hashCode ^
      voiceName.hashCode ^
      voiceLocale.hashCode;
}

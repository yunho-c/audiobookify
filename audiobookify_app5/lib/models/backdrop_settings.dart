import 'package:flutter/foundation.dart';

@immutable
class BackdropSettings {
  final String id;
  final double brightness;

  const BackdropSettings({
    this.id = '',
    this.brightness = 0.0,
  });

  BackdropSettings copyWith({
    String? id,
    double? brightness,
  }) {
    return BackdropSettings(
      id: id ?? this.id,
      brightness: brightness ?? this.brightness,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackdropSettings &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          brightness == other.brightness;

  @override
  int get hashCode => Object.hash(id, brightness);
}

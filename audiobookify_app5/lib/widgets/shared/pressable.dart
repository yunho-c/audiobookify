import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum PressableHaptic { none, selection, light, medium }

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedOpacity;
  final double pressedScale;
  final Duration duration;
  final PressableHaptic haptic;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedOpacity = 0.75,
    this.pressedScale = 0.98,
    this.duration = const Duration(milliseconds: 140),
    this.haptic = PressableHaptic.none,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    _performHaptic();
    widget.onTap!();
  }

  void _performHaptic() {
    switch (widget.haptic) {
      case PressableHaptic.selection:
        HapticFeedback.selectionClick();
        break;
      case PressableHaptic.light:
        HapticFeedback.lightImpact();
        break;
      case PressableHaptic.medium:
        HapticFeedback.mediumImpact();
        break;
      case PressableHaptic.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: !enabled ? null : (_) => _setPressed(true),
      onTapUp: !enabled ? null : (_) => _setPressed(false),
      onTapCancel: !enabled ? null : () => _setPressed(false),
      onTap: !enabled ? null : _handleTap,
      child: AnimatedOpacity(
        duration: widget.duration,
        opacity: _isPressed ? widget.pressedOpacity : 1,
        child: AnimatedScale(
          duration: widget.duration,
          scale: _isPressed ? widget.pressedScale : 1,
          child: widget.child,
        ),
      ),
    );
  }
}

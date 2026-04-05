import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum PressableHaptic { none, selection, light, medium }

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool? enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final MouseCursor? mouseCursor;
  final bool semanticButton;
  final double pressedOpacity;
  final double pressedScale;
  final Duration duration;
  final PressableHaptic haptic;
  final PressableHaptic longPressHaptic;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled,
    this.focusNode,
    this.autofocus = false,
    this.mouseCursor,
    this.semanticButton = true,
    this.pressedOpacity = 0.75,
    this.pressedScale = 0.98,
    this.duration = const Duration(milliseconds: 140),
    this.haptic = PressableHaptic.none,
    this.longPressHaptic = PressableHaptic.none,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _isPressed = false;
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isEnabled =>
      widget.enabled ?? (widget.onTap != null || widget.onLongPress != null);

  bool get _canTap => _isEnabled && widget.onTap != null;

  bool get _canLongPress => _isEnabled && widget.onLongPress != null;

  MouseCursor get _mouseCursor =>
      widget.mouseCursor ??
      (_isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic);

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  void _setHovered(bool value) {
    if (_isHovered == value) return;
    setState(() => _isHovered = value);
  }

  void _setFocused(bool value) {
    if (_isFocused == value) return;
    setState(() => _isFocused = value);
  }

  void _handleTap() {
    if (!_canTap) return;
    _performHaptic(widget.haptic);
    widget.onTap!();
  }

  void _performHaptic(PressableHaptic haptic) {
    switch (haptic) {
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

  void _handleLongPress() {
    if (!_canLongPress) return;
    final haptic = widget.longPressHaptic == PressableHaptic.none
        ? widget.haptic
        : widget.longPressHaptic;
    _performHaptic(haptic);
    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.semanticButton,
      enabled: _isEnabled,
      onTap: _canTap ? _handleTap : null,
      onLongPress: _canLongPress ? _handleLongPress : null,
      child: FocusableActionDetector(
        enabled: _isEnabled,
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        mouseCursor: _mouseCursor,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _handleTap();
              return null;
            },
          ),
        },
        onShowHoverHighlight: _setHovered,
        onShowFocusHighlight: _setFocused,
        child: GestureDetector(
          onTapDown: !_isEnabled ? null : (_) => _setPressed(true),
          onTapUp: !_isEnabled ? null : (_) => _setPressed(false),
          onTapCancel: !_isEnabled ? null : () => _setPressed(false),
          onTap: _canTap ? _handleTap : null,
          onLongPress: _canLongPress ? _handleLongPress : null,
          child: AnimatedOpacity(
            duration: widget.duration,
            alwaysIncludeSemantics: _isPressed || _isHovered || _isFocused,
            opacity: _isPressed ? widget.pressedOpacity : 1,
            child: AnimatedScale(
              duration: widget.duration,
              scale: _isPressed ? widget.pressedScale : 1,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

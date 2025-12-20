import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'pressable.dart';

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double radius;
  final double iconSize;
  final double blurSigma;
  final double pressedOpacity;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.radius = 14,
    this.iconSize = 20,
    this.blurSigma = 14,
    this.pressedOpacity = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final glassBackground =
        extras?.glassBackground ?? colorScheme.surface.withAlpha(200);
    final glassBorder =
        extras?.glassBorder ?? colorScheme.onSurface.withAlpha(40);
    final glassShadow =
        extras?.glassShadow ?? Theme.of(context).shadowColor.withAlpha(30);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: glassShadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Pressable(
            onTap: onTap,
            pressedOpacity: pressedOpacity,
            pressedScale: 1,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: glassBackground,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: glassBorder, width: 1),
              ),
              child: Icon(
                icon,
                color: colorScheme.onSurface,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

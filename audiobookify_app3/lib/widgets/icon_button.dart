import 'package:flutter/material.dart';
import '../theme/theme.dart';

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final EdgeInsets padding;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 24.0,
    this.color,
    this.padding = const EdgeInsets.all(8.0),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(50),
        splashColor: AppTheme.divider,
        highlightColor: AppTheme.divider,
        child: Padding(
          padding: padding,
          child: Icon(icon, size: size, color: color ?? Colors.white),
        ),
      ),
    );
  }
}

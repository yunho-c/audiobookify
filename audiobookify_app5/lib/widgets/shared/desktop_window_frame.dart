import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/desktop_window.dart';

class DesktopWindowFrame extends StatelessWidget {
  final Widget child;

  const DesktopWindowFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!isDesktopWindowChromeEnabled) return child;

    return Column(
      children: [
        if (isDesktopWindowWindows)
          _WindowsWindowCaption()
        else if (isDesktopWindowMacOS)
          const _MacOSWindowInset(),
        Expanded(child: child),
      ],
    );
  }
}

class _MacOSWindowInset extends StatelessWidget {
  const _MacOSWindowInset();

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: const SizedBox(
        height: kDesktopMacTitleBarHeight,
        width: double.infinity,
      ),
    );
  }
}

class _WindowsWindowCaption extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = colorScheme.surface.withAlpha(
      theme.brightness == Brightness.dark ? 230 : 205,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withAlpha(100)),
        ),
      ),
      child: WindowCaption(
        backgroundColor: Colors.transparent,
        brightness: theme.brightness,
        title: Text(
          'Audiobookify',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurface.withAlpha(190),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

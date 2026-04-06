import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/desktop_window.dart';

class DesktopWindowFrame extends StatelessWidget {
  final Widget child;

  const DesktopWindowFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!isDesktopWindowChromeEnabled) return child;

    if (isDesktopWindowMacOS) {
      return _MacOSWindowFrame(child: child);
    }

    return Column(
      children: [
        if (isDesktopWindowWindows) _WindowsWindowCaption(),
        Expanded(child: child),
      ],
    );
  }
}

class _MacOSWindowFrame extends StatelessWidget {
  final Widget child;

  const _MacOSWindowFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topInset = mediaQuery.padding.top > kDesktopMacContentTopInset
        ? mediaQuery.padding.top
        : kDesktopMacContentTopInset;
    final insetMediaQuery = mediaQuery.copyWith(
      padding: mediaQuery.padding.copyWith(top: topInset),
      viewPadding: mediaQuery.viewPadding.copyWith(top: topInset),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: MediaQuery(data: insetMediaQuery, child: child),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: kDesktopMacTitleBarHeight,
          child: const _MacOSTitleBarDragRegion(),
        ),
      ],
    );
  }
}

class _MacOSTitleBarDragRegion extends StatelessWidget {
  const _MacOSTitleBarDragRegion();

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

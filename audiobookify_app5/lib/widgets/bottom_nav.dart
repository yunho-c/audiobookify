import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';
import '../core/nav_transition.dart';

/// Bottom navigation bar with glassmorphism panel and raised create button
class BottomNav extends StatelessWidget {
  final int currentIndex;

  const BottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final glassBackground =
        extras?.glassBackground ?? colorScheme.surface.withAlpha(200);
    final glassBorder =
        extras?.glassBorder ?? colorScheme.onSurface.withAlpha(50);
    final glassShadow =
        extras?.glassShadow ?? Theme.of(context).shadowColor.withAlpha(25);
    const navHeight = 68.0;
    const highlightSize = 44.0;
    final highlightColor = colorScheme.primary.withAlpha(18);
    int scaledAlpha(double factor) {
      final value = (glassBackground.alpha * factor).round();
      if (value < 0) return 0;
      if (value > 255) return 255;
      return value;
    }

    return SafeArea(
      top: false,
      left: false,
      right: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: SizedBox(
          height: navHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / 3;
              final highlightLeft =
                  itemWidth * currentIndex + (itemWidth - highlightSize) / 2;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Glassmorphism background
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        height: navHeight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              glassBackground.withAlpha(scaledAlpha(0.9)),
                              glassBackground.withAlpha(scaledAlpha(0.75)),
                            ],
                          ),
                          border: Border.all(color: glassBorder, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: glassShadow,
                              blurRadius: 24,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    left: highlightLeft,
                    top: (navHeight - highlightSize) / 2,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: currentIndex == 1 ? 0 : 1,
                      child: Container(
                        width: highlightSize,
                        height: highlightSize,
                        decoration: BoxDecoration(
                          color: highlightColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  // Navigation items
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: _NavItem(
                            icon: LucideIcons.home,
                            isActive: currentIndex == 0,
                            onTap: () => context.go(
                              '/',
                              extra: NavTransitionData(
                                fromIndex: currentIndex,
                                toIndex: 0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: _NavItem(
                            icon: LucideIcons.plus,
                            isActive: currentIndex == 1,
                            isPrimary: true,
                            onTap: () => context.go(
                              '/create',
                              extra: NavTransitionData(
                                fromIndex: currentIndex,
                                toIndex: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: _NavItem(
                            icon: LucideIcons.settings,
                            isActive: currentIndex == 2,
                            onTap: () => context.go(
                              '/settings',
                              extra: NavTransitionData(
                                fromIndex: currentIndex,
                                toIndex: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final bool isPrimary;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    // Primary button (add) has orange background and glow
    if (isPrimary) {
      final colorScheme = Theme.of(context).colorScheme;
      return _NavButton(
        isPrimary: true,
        isActive: isActive,
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withAlpha(120),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, size: 26, color: colorScheme.onPrimary),
        ),
      );
    }

    // Regular nav item
    final colorScheme = Theme.of(context).colorScheme;
    return _NavButton(
      isActive: isActive,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color:
              isActive ? colorScheme.primary.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final bool isPrimary;
  final VoidCallback onTap;

  const _NavButton({
    required this.child,
    required this.onTap,
    required this.isActive,
    this.isPrimary = false,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  void _handleTap() {
    if (widget.isPrimary) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _handleTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _isPressed ? 0.85 : 1,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _isPressed ? 0.96 : 1,
          child: widget.child,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';

/// Bottom navigation bar with glassmorphism effect and raised create button
class BottomNav extends StatelessWidget {
  final int currentIndex;

  const BottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Glassmorphism background
          ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(200),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withAlpha(50),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Navigation items
          SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Home
                _NavItem(
                  icon: LucideIcons.home,
                  isActive: currentIndex == 0,
                  onTap: () => context.go('/'),
                ),
                // Create (center) - primary accent button
                _NavItem(
                  icon: LucideIcons.plus,
                  isActive: currentIndex == 1,
                  isPrimary: true,
                  onTap: () => context.go('/create'),
                ),
                // Settings
                _NavItem(
                  icon: LucideIcons.settings,
                  isActive: currentIndex == 2,
                  onTap: () => context.go('/settings'),
                ),
              ],
            ),
          ),
        ],
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
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.orange600,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange600.withAlpha(100),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 24, color: Colors.white),
        ),
      );
    }

    // Regular nav item
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.orange50 : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          icon,
          size: 24,
          color: isActive ? AppColors.orange600 : AppColors.stone500,
        ),
      ),
    );
  }
}

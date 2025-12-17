import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bottom navigation dock with About, Settings, Feedback buttons
class NavigationDock extends StatelessWidget {
  final bool visible;

  const NavigationDock({
    super.key,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      offset: visible ? Offset.zero : const Offset(0, 2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: visible ? 1.0 : 0.0,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryBrown,
            borderRadius: BorderRadius.circular(32),
            border: const Border(
              top: BorderSide(color: Color(0xFFa16207), width: 1),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavButton(label: 'About'),
                _NavButton(label: 'Settings'),
                _NavButton(label: 'Feedback'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final String label;

  const _NavButton({required this.label});

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          // TODO: Implement navigation actions
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: _isHovered ? AppColors.goldLight : AppColors.lightStone,
                ),
              ),
              if (_isHovered)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 24,
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.goldLight,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

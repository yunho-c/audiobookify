import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';

/// Audio settings modal with 2x2 grid of options and decorative wheel
class SettingsWheel extends StatelessWidget {
  final VoidCallback onClose;

  const SettingsWheel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final settings = [
      _SettingItem(
        id: 'speed',
        label: 'Speed',
        icon: LucideIcons.gauge,
        value: '1.0x',
        bgColor: AppColors.rose100,
        fgColor: AppColors.rose600,
      ),
      _SettingItem(
        id: 'pitch',
        label: 'Pitch',
        icon: LucideIcons.music,
        value: 'Deep',
        bgColor: AppColors.amber100,
        fgColor: AppColors.amber600,
      ),
      _SettingItem(
        id: 'style',
        label: 'Style',
        icon: LucideIcons.mic2,
        value: 'Sample',
        bgColor: AppColors.blue100,
        fgColor: AppColors.blue600,
      ),
      _SettingItem(
        id: 'accent',
        label: 'Accent',
        icon: LucideIcons.languages,
        value: 'British',
        bgColor: AppColors.emerald100,
        fgColor: AppColors.emerald600,
      ),
    ];

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withAlpha(50),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent tap-through
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(50),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: onClose,
                      child: const Icon(
                        LucideIcons.x,
                        size: 20,
                        color: AppColors.stone400,
                      ),
                    ),
                  ),
                  // Title
                  Text(
                    'Audio Settings',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.stone800,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Settings grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    physics: const NeverScrollableScrollPhysics(),
                    children: settings
                        .map((s) => _SettingButton(setting: s))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  // Decorative wheel
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CustomPaint(
                      painter: _WheelPainter(),
                      child: Center(
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.stone800,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingItem {
  final String id;
  final String label;
  final IconData icon;
  final String value;
  final Color bgColor;
  final Color fgColor;

  const _SettingItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.value,
    required this.bgColor,
    required this.fgColor,
  });
}

class _SettingButton extends StatelessWidget {
  final _SettingItem setting;

  const _SettingButton({required this.setting});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: setting.bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(setting.icon, size: 24, color: setting.fgColor),
          const SizedBox(height: 8),
          Text(
            setting.label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: setting.fgColor.withAlpha(150),
            ),
          ),
          Text(
            setting.value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: setting.fgColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final colors = [
      AppColors.rose600,
      AppColors.amber600,
      AppColors.blue600,
      AppColors.emerald600,
    ];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    for (int i = 0; i < 4; i++) {
      paint.color = colors[i];
      final startAngle = (i * 90 - 45) * 3.14159 / 180;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        startAngle,
        90 * 3.14159 / 180,
        false,
        paint,
      );
    }

    // Border circle
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = AppColors.stone100;
    canvas.drawCircle(center, radius - 10, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

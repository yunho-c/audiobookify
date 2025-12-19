import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';
import '../core/providers.dart';

/// Audio settings modal with interactive sliders for speed and pitch
class SettingsWheel extends ConsumerWidget {
  final VoidCallback onClose;

  const SettingsWheel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(playerSettingsProvider);

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withAlpha(50),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent tap-through
            child: Container(
              width: 320,
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
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Audio Settings',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.stone800,
                        ),
                      ),
                      GestureDetector(
                        onTap: onClose,
                        child: const Icon(
                          LucideIcons.x,
                          size: 20,
                          color: AppColors.stone400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Speed slider
                  _SettingSlider(
                    icon: LucideIcons.gauge,
                    label: 'Speed',
                    value: settings.speed,
                    min: 0.5,
                    max: 2.0,
                    displayValue: '${settings.speed.toStringAsFixed(1)}x',
                    bgColor: AppColors.rose100,
                    fgColor: AppColors.rose600,
                    onChanged: (value) {
                      ref.read(playerSettingsProvider.notifier).setSpeed(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Pitch slider
                  _SettingSlider(
                    icon: LucideIcons.music,
                    label: 'Pitch',
                    value: settings.pitch,
                    min: 0.5,
                    max: 2.0,
                    displayValue: settings.pitch.toStringAsFixed(1),
                    bgColor: AppColors.amber100,
                    fgColor: AppColors.amber600,
                    onChanged: (value) {
                      ref.read(playerSettingsProvider.notifier).setPitch(value);
                    },
                  ),
                  const SizedBox(height: 24),
                  // Reset button
                  TextButton(
                    onPressed: () {
                      ref.read(playerSettingsProvider.notifier).reset();
                    },
                    child: Text(
                      'Reset to Defaults',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.stone500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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

/// Interactive slider for a single setting
class _SettingSlider extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final Color bgColor;
  final Color fgColor;
  final ValueChanged<double> onChanged;

  const _SettingSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.bgColor,
    required this.fgColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: fgColor),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: fgColor.withAlpha(180),
                ),
              ),
              const Spacer(),
              Text(
                displayValue,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: fgColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: fgColor,
              inactiveTrackColor: fgColor.withAlpha(50),
              thumbColor: fgColor,
              overlayColor: fgColor.withAlpha(30),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
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

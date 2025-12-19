import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final accentPalette = extras?.accentPalette ??
        const [
          AppColors.rose600,
          AppColors.amber600,
          AppColors.blue600,
          AppColors.emerald600,
        ];
    final accentSoftPalette = extras?.accentSoftPalette ??
        const [
          AppColors.rose100,
          AppColors.amber100,
          AppColors.blue100,
          AppColors.emerald100,
        ];

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: colorScheme.scrim.withAlpha(120),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent tap-through
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withAlpha(50),
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
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: onClose,
                        child: Icon(
                          LucideIcons.x,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
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
                    bgColor: accentSoftPalette[0],
                    fgColor: accentPalette[0],
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
                    bgColor: accentSoftPalette[1],
                    fgColor: accentPalette[1],
                    onChanged: (value) {
                      ref.read(playerSettingsProvider.notifier).setPitch(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Style (voice selection) - 2x2 grid row
                  Row(
                    children: [
                      // Style card
                      Expanded(
                        child: _SettingCard(
                          icon: LucideIcons.mic2,
                          label: 'Style',
                          value:
                              settings.voiceName?.split('.').last ?? 'Default',
                          bgColor: accentSoftPalette[2],
                          fgColor: accentPalette[2],
                          onTap: () => _showVoiceSelector(context, ref),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Accent card (no-op)
                      Expanded(
                        child: _SettingCard(
                          icon: LucideIcons.languages,
                          label: 'Accent',
                          value: 'British',
                          bgColor: accentSoftPalette[3],
                          fgColor: accentPalette[3],
                          onTap: () {}, // No-op
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Reset button
                  TextButton(
                    onPressed: () {
                      ref.read(playerSettingsProvider.notifier).reset();
                    },
                    child: Text(
                      'Reset to Defaults',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Decorative wheel
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CustomPaint(
                      painter: _WheelPainter(
                        colors: accentPalette,
                        borderColor: colorScheme.outlineVariant,
                      ),
                      child: Center(
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface,
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
    final textTheme = Theme.of(context).textTheme;
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
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: fgColor.withAlpha(180),
                ),
              ),
              const Spacer(),
              Text(
                displayValue,
                style: textTheme.titleMedium?.copyWith(
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

/// Static card for tap-based settings (Style, Accent)
class _SettingCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color bgColor;
  final Color fgColor;
  final VoidCallback onTap;

  const _SettingCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.bgColor,
    required this.fgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: fgColor),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: fgColor.withAlpha(180),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: fgColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Show voice selection bottom sheet
void _showVoiceSelector(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _VoiceSelectorSheet(ref: ref),
  );
}

class _VoiceSelectorSheet extends StatefulWidget {
  final WidgetRef ref;

  const _VoiceSelectorSheet({required this.ref});

  @override
  State<_VoiceSelectorSheet> createState() => _VoiceSelectorSheetState();
}

class _VoiceSelectorSheetState extends State<_VoiceSelectorSheet> {
  List<Map<String, String>> _voices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    try {
      final voices = await _getSystemVoices();
      setState(() {
        _voices = voices
            .where((v) => v['locale']?.contains('en') ?? false)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, String>>> _getSystemVoices() async {
    final FlutterTts flutterTts = FlutterTts();
    final voices = await flutterTts.getVoices;
    return (voices as List)
        .map((v) => Map<String, String>.from(v as Map))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.ref.watch(playerSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Voice',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            )
          else if (_voices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Using system default voice',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _voices.length,
                itemBuilder: (context, index) {
                  final voice = _voices[index];
                  final isSelected = voice['name'] == settings.voiceName;
                  return ListTile(
                    title: Text(voice['name'] ?? 'Unknown'),
                    subtitle: Text(voice['locale'] ?? ''),
                    trailing: isSelected
                        ? Icon(
                            LucideIcons.check,
                            color: colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      widget.ref
                          .read(playerSettingsProvider.notifier)
                          .setVoice(voice['name']!, voice['locale']!);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<Color> colors;
  final Color borderColor;

  _WheelPainter({
    required this.colors,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

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
      ..color = borderColor;
    canvas.drawCircle(center, radius - 10, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

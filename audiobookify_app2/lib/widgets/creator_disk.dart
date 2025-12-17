import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Sector data for the creator disk
class DiskSector {
  final String id;
  final String label;
  final Color color;
  final double startAngle;

  const DiskSector({
    required this.id,
    required this.label,
    required this.color,
    required this.startAngle,
  });
}

/// Vinyl record-style parameter selector
class CreatorDisk extends StatefulWidget {
  final VoidCallback onGenerate;

  const CreatorDisk({
    super.key,
    required this.onGenerate,
  });

  @override
  State<CreatorDisk> createState() => _CreatorDiskState();
}

class _CreatorDiskState extends State<CreatorDisk>
    with SingleTickerProviderStateMixin {
  String? _activeSector;
  late AnimationController _pulseController;

  static const _sectors = [
    DiskSector(
        id: 'pitch', label: 'PITCH', color: Color(0xFFFCD34D), startAngle: 0),
    DiskSector(
        id: 'speed',
        label: 'SPEED',
        color: Color(0xFFFCA5A5),
        startAngle: math.pi / 2),
    DiskSector(
        id: 'sample',
        label: 'SAMPLE',
        color: Color(0xFF86EFAC),
        startAngle: math.pi),
    DiskSector(
        id: 'style',
        label: 'STYLE',
        color: Color(0xFFD8B4FE),
        startAngle: 3 * math.pi / 2),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Disk
          SizedBox(
            width: 192,
            height: 192,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring
                Container(
                  width: 192,
                  height: 192,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: CustomPaint(
                      size: const Size(192, 192),
                      painter: _DiskPainter(
                        sectors: _sectors,
                        activeSector: _activeSector,
                      ),
                    ),
                  ),
                ),

                // Center spindle
                GestureDetector(
                  onTapDown: _handleTap,
                  child: Container(
                    width: 192,
                    height: 192,
                    color: Colors.transparent,
                  ),
                ),

                // Center hole
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Active sector label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _activeSector != null
                  ? _sectors.firstWhere((s) => s.id == _activeSector).label
                  : 'Select Parameter',
              key: ValueKey(_activeSector),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBrown,
                letterSpacing: 2,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Generate button
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.02);
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: ElevatedButton.icon(
              onPressed: widget.onGenerate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBrown,
                foregroundColor: AppColors.cream,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.mic, size: 14),
              label: const Text(
                'GENERATE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(TapDownDetails details) {
    final center = const Offset(96, 96);
    final position = details.localPosition;
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;

    // Check if tap is within the disk but outside the center
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < 20 || distance > 96) return;

    // Calculate angle
    var angle = math.atan2(dy, dx);
    if (angle < 0) angle += 2 * math.pi;

    // Determine sector
    String? sector;
    if (angle < math.pi / 2) {
      sector = 'pitch';
    } else if (angle < math.pi) {
      sector = 'speed';
    } else if (angle < 3 * math.pi / 2) {
      sector = 'sample';
    } else {
      sector = 'style';
    }

    setState(() {
      _activeSector = sector;
    });
  }
}

/// Custom painter for the disk sectors
class _DiskPainter extends CustomPainter {
  final List<DiskSector> sectors;
  final String? activeSector;

  _DiskPainter({required this.sectors, this.activeSector});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (final sector in sectors) {
      final isActive = sector.id == activeSector;
      final paint = Paint()
        ..color = sector.color.withOpacity(isActive ? 1.0 : 0.7)
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          sector.startAngle,
          math.pi / 2,
          false,
        )
        ..close();

      canvas.drawPath(path, paint);

      // Draw sector border
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiskPainter oldDelegate) {
    return oldDelegate.activeSector != activeSector;
  }
}

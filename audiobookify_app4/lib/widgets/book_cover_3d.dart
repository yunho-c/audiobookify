import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// 3D tilt book cover widget with hover/touch effects
class BookCover3D extends StatefulWidget {
  final List<Color> gradientColors;
  final String title;
  final String author;
  final bool isLarge;
  final VoidCallback? onTap;

  const BookCover3D({
    super.key,
    required this.gradientColors,
    required this.title,
    required this.author,
    this.isLarge = false,
    this.onTap,
  });

  @override
  State<BookCover3D> createState() => _BookCover3DState();
}

class _BookCover3DState extends State<BookCover3D> {
  double _rotateX = 0;
  double _rotateY = 0;
  double _shineX = 0;
  double _shineY = 0;
  double _shineOpacity = 0;
  bool _isHovering = false;

  void _handlePointerMove(PointerEvent event, BoxConstraints constraints) {
    final x = event.localPosition.dx;
    final y = event.localPosition.dy;

    final centerX = constraints.maxWidth / 2;
    final centerY = constraints.maxHeight / 2;

    // Max 15 degrees rotation
    final rotateX = ((y - centerY) / centerY) * -15;
    final rotateY = ((x - centerX) / centerX) * 15;

    setState(() {
      _rotateX = rotateX;
      _rotateY = rotateY;
      _shineX = x;
      _shineY = y;
      _shineOpacity = 1;
      _isHovering = true;
    });
  }

  void _handlePointerExit() {
    setState(() {
      _rotateX = 0;
      _rotateY = 0;
      _shineOpacity = 0;
      _isHovering = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.isLarge ? 256.0 : 160.0;
    final height = widget.isLarge ? 384.0 : 240.0;

    return LayoutBuilder(
      builder: (context, _) {
        return MouseRegion(
          onHover: (e) => _handlePointerMove(
            e,
            BoxConstraints(maxWidth: width, maxHeight: height),
          ),
          onExit: (_) => _handlePointerExit(),
          child: GestureDetector(
            onTap: widget.onTap,
            onPanUpdate: (details) {
              // Touch drag support for mobile
              final x = details.localPosition.dx;
              final y = details.localPosition.dy;
              final centerX = width / 2;
              final centerY = height / 2;
              final rotateX = ((y - centerY) / centerY) * -15;
              final rotateY = ((x - centerX) / centerX) * 15;
              setState(() {
                _rotateX = rotateX;
                _rotateY = rotateY;
                _shineX = x;
                _shineY = y;
                _shineOpacity = 1;
                _isHovering = true;
              });
            },
            onPanEnd: (_) => _handlePointerExit(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: width,
              height: height,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // perspective
                ..rotateX(_rotateX * pi / 180)
                ..rotateY(_rotateY * pi / 180)
                ..scale(_isHovering ? 1.02 : 1.0),
              transformAlignment: Alignment.center,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.gradientColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 30,
                      offset: Offset(-_rotateY, _rotateX + 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Book spine effect
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.black.withOpacity(0.1),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Content
                    Padding(
                      padding: EdgeInsets.all(widget.isLarge ? 24 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: Icon(
                              LucideIcons.headphones,
                              color: Colors.white.withOpacity(0.8),
                              size: widget.isLarge ? 32 : 20,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: widget.isLarge ? 28 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(height: widget.isLarge ? 8 : 4),
                              Text(
                                widget.author,
                                style: TextStyle(
                                  fontSize: widget.isLarge ? 16 : 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Dynamic shine/glare
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _shineOpacity,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: RadialGradient(
                            center: Alignment(
                              (_shineX / width) * 2 - 1,
                              (_shineY / height) * 2 - 1,
                            ),
                            radius: 1,
                            colors: [
                              Colors.white.withOpacity(0.4),
                              Colors.white.withOpacity(0),
                            ],
                            stops: const [0, 0.6],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

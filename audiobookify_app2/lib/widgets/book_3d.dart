import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/book_data.dart';
import '../theme/app_theme.dart';

/// The view state of the 3D book
enum BookViewState { spine, isometric, open }

/// 3D animated book widget with multiple view states
class Book3D extends StatefulWidget {
  final Book book;
  final BookViewState viewState;
  final Widget? interiorContent;
  final VoidCallback? onTap;

  const Book3D({
    super.key,
    required this.book,
    required this.viewState,
    this.interiorContent,
    this.onTap,
  });

  @override
  State<Book3D> createState() => _Book3DState();
}

class _Book3DState extends State<Book3D> with TickerProviderStateMixin {
  late AnimationController _transformController;
  late AnimationController _coverController;
  late Animation<double> _rotateY;
  late Animation<double> _rotateX;
  late Animation<double> _rotateZ;
  late Animation<double> _coverRotation;

  @override
  void initState() {
    super.initState();

    _transformController = AnimationController(
      duration: AppAnimations.bookTransformDuration,
      vsync: this,
    );

    _coverController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _setupAnimations();
    _animateToState(widget.viewState);
  }

  void _setupAnimations() {
    final curve = CurvedAnimation(
      parent: _transformController,
      curve: AppAnimations.bookTransformCurve,
    );

    _rotateY = Tween<double>(begin: -90, end: -30).animate(curve);
    _rotateX = Tween<double>(begin: 0, end: 20).animate(curve);
    _rotateZ = Tween<double>(begin: 0, end: -5).animate(curve);

    _coverRotation = Tween<double>(begin: 0, end: -180).animate(
      CurvedAnimation(parent: _coverController, curve: Curves.easeInOut),
    );
  }

  void _animateToState(BookViewState state) {
    switch (state) {
      case BookViewState.spine:
        _transformController.reverse();
        _coverController.reverse();
      case BookViewState.isometric:
        _transformController.forward();
        _coverController.reverse();
      case BookViewState.open:
        _transformController.forward();
        _coverController.forward();
    }
  }

  @override
  void didUpdateWidget(Book3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewState != widget.viewState) {
      _animateToState(widget.viewState);
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    _coverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_transformController, _coverController]),
        builder: (context, child) {
          final isOpen = widget.viewState == BookViewState.open;
          final scale = isOpen ? 1.1 : 1.0;

          // Compute transform based on state
          double rotateY, rotateX, rotateZ;
          if (widget.viewState == BookViewState.spine) {
            rotateY = -90;
            rotateX = 0;
            rotateZ = 0;
          } else if (widget.viewState == BookViewState.open) {
            rotateY = 0;
            rotateX = 0;
            rotateZ = 0;
          } else {
            rotateY = _rotateY.value;
            rotateX = _rotateX.value;
            rotateZ = _rotateZ.value;
          }

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective
              ..scale(scale)
              ..rotateX(rotateX * math.pi / 180)
              ..rotateY(rotateY * math.pi / 180)
              ..rotateZ(rotateZ * math.pi / 180),
            child: SizedBox(
              width: 280,
              height: 420,
              child: Stack(
                children: [
                  // Back cover
                  _buildBackCover(),

                  // Page edges (right side)
                  _buildPageEdges(),

                  // Interior right (content area)
                  _buildInteriorRight(),

                  // Spine
                  _buildSpine(),

                  // Front cover with pivot animation
                  _buildFrontCover(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpine() {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 50,
      child: Transform(
        alignment: Alignment.centerRight,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(-90 * math.pi / 180),
        child: Container(
          decoration: BoxDecoration(
            color: widget.book.spineColor,
            borderRadius: BorderRadius.circular(2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 8,
                offset: Offset(-2, 0),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Shading overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0x99000000),
                        Color(0x0DFFFFFF),
                        Color(0x26FFFFFF),
                        Color(0x0DFFFFFF),
                        Color(0x99000000),
                      ],
                      stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                    ),
                  ),
                ),
              ),

              // Binding ridges
              if (widget.book.style != BookStyle.modern) ...[
                _buildSpineRidge(0.15),
                _buildSpineRidge(0.30),
                _buildSpineRidge(0.70),
                _buildSpineRidge(0.85),
              ],

              // Text label
              Center(
                child: RotatedBox(
                  quarterTurns: 1,
                  child: Text(
                    widget.book.title.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.goldStamp.copyWith(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpineRidge(double position) {
    return Positioned(
      top: 420 * position - 1.5,
      left: 0,
      right: 0,
      height: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          border: const Border(
            top: BorderSide(color: Color(0x26FFFFFF), width: 1),
            bottom: BorderSide(color: Color(0x66000000), width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildPageEdges() {
    return Positioned(
      right: 0,
      top: 2,
      bottom: 2,
      width: 46,
      child: Transform(
        alignment: Alignment.centerLeft,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(90 * math.pi / 180),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.pageCream,
                AppColors.pageEdge,
                AppColors.pageCream,
                AppColors.pageEdge,
                AppColors.pageCream,
              ],
              stops: [0.0, 0.05, 0.1, 0.15, 1.0],
            ),
            border: Border.all(color: const Color(0xFFd6d3cd), width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildBackCover() {
    return Positioned.fill(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..translate(0.0, 0.0, -25.0),
        child: Container(
          decoration: BoxDecoration(
            color: widget.book.color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              bottomLeft: Radius.circular(4),
              topRight: Radius.circular(2),
              bottomRight: Radius.circular(2),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteriorRight() {
    return Positioned(
      left: 4,
      right: 4,
      top: 4,
      bottom: 4,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..translate(0.0, 0.0, 20.0),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.pageCream,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 10,
                offset: Offset(2, 0),
              ),
            ],
          ),
          child: widget.interiorContent ?? const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildFrontCover() {
    return Positioned.fill(
      child: Transform(
        alignment: Alignment.centerLeft,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..translate(0.0, 0.0, 25.0)
          ..rotateY(_coverRotation.value * math.pi / 180),
        child: Stack(
          children: [
            // Front face
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.book.coverGradient,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  bottomLeft: Radius.circular(2),
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
                border: const Border(
                  left: BorderSide(color: Color(0x1AFFFFFF), width: 1),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 10,
                    offset: Offset(5, 5),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Leather texture overlay (noise pattern)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.15,
                      child: CustomPaint(
                        painter: _NoisePainter(),
                      ),
                    ),
                  ),

                  // Gold border
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: AppColors.gold.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                    ),
                  ),

                  // Title and author
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.book.title,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.goldStamp.copyWith(
                              fontSize: 28,
                              fontFamily: 'serif',
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.book.author,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: widget.book.textColor,
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Interior left (Ex Libris page) - visible when cover flips
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.pageCream,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                  border: Border(
                    right: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 10,
                      offset: Offset(-2, 0),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.warmStone,
                        width: 4,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ex Libris',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkBrown,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 48,
                          height: 1,
                          color: AppColors.darkBrown,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AUDIOBOOKIFY COLLECTION',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: AppColors.primaryBrown,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple noise painter for leather texture effect
class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final paint = Paint()..color = Colors.black;

    for (int i = 0; i < 1000; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = random.nextDouble() * 0.3;
      paint.color = Colors.black.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

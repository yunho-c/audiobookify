import 'package:flutter/material.dart';
import '../data/book_data.dart';
import '../theme/app_theme.dart';

/// Skeuomorphic book spine widget for shelf display
class BookSpine extends StatelessWidget {
  final Book book;
  final VoidCallback? onTap;

  const BookSpine({
    super.key,
    required this.book,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseHeight = 220.0 + book.heightVar;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 56,
          height: baseHeight,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: book.spineColor,
            borderRadius: BorderRadius.circular(2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                offset: Offset(0, 5),
                blurRadius: 10,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Cylindrical shading overlay
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
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x80000000),
                        blurRadius: 2,
                        spreadRadius: -1,
                      ),
                    ],
                  ),
                ),
              ),

              // Binding ridges (for non-modern styles)
              if (book.style != BookStyle.modern) ...[
                _SpineRidge(top: baseHeight * 0.15),
                _SpineRidge(top: baseHeight * 0.30),
                _SpineRidge(bottom: baseHeight * 0.30),
                _SpineRidge(bottom: baseHeight * 0.15),
              ],

              // Headcap (top edge detail)
              Positioned(
                top: -1,
                left: 0,
                right: 0,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                    gradient: RadialGradient(
                      center: const Alignment(0, 1),
                      radius: 1,
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ),

              // Rotated text label
              Center(
                child: RotatedBox(
                  quarterTurns: 1,
                  child: SizedBox(
                    width: 180,
                    child: Text(
                      book.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: (book.useSilverStamp
                              ? AppTextStyles.silverStamp
                              : AppTextStyles.goldStamp)
                          .copyWith(fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal binding ridge on spine
class _SpineRidge extends StatelessWidget {
  final double? top;
  final double? bottom;

  const _SpineRidge({this.top, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: 0,
      right: 0,
      height: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          border: const Border(
            top: BorderSide(
              color: Color(0x26FFFFFF),
              width: 1,
            ),
            bottom: BorderSide(
              color: Color(0x66000000),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

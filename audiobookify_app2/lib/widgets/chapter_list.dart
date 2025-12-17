import 'package:flutter/material.dart';
import '../data/book_data.dart';
import '../theme/app_theme.dart';

/// Chapter list for the "ready" state inside the book
class ChapterList extends StatelessWidget {
  final List<Chapter> chapters;
  final void Function(Chapter) onChapterTap;

  const ChapterList({
    super.key,
    required this.chapters,
    required this.onChapterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
              ),
            ),
            child: const Text(
              'CHAPTERS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.darkBrown,
                letterSpacing: 2,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Chapter list
          Expanded(
            child: ListView.separated(
              itemCount: chapters.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                return _ChapterButton(
                  chapter: chapter,
                  onTap: () => onChapterTap(chapter),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual chapter button
class _ChapterButton extends StatefulWidget {
  final Chapter chapter;
  final VoidCallback onTap;

  const _ChapterButton({
    required this.chapter,
    required this.onTap,
  });

  @override
  State<_ChapterButton> createState() => _ChapterButtonState();
}

class _ChapterButtonState extends State<_ChapterButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.darkBrown.withOpacity(0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              // Chapter number badge
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.darkBrown,
                ),
                child: Center(
                  child: Text(
                    '${widget.chapter.id}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cream,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Chapter title
              Expanded(
                child: Text(
                  widget.chapter.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkBrown,
                  ),
                ),
              ),

              // Play icon
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _isHovered ? 1.0 : 0.0,
                child: Icon(
                  Icons.play_arrow,
                  size: 14,
                  color: AppColors.darkBrown,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

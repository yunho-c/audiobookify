import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/book.dart';
import '../theme.dart';

/// Floating chapters panel overlay
class ChaptersPanel extends StatelessWidget {
  final Book book;
  final bool isVisible;
  final VoidCallback onClose;
  final Function(Chapter)? onChapterTap;

  const ChaptersPanel({
    super.key,
    required this.book,
    required this.isVisible,
    required this.onClose,
    this.onChapterTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      bottom: isVisible ? (isDesktop ? 96 : 0) : -500,
      left: isDesktop ? null : 0,
      right: isDesktop ? 32 : 0,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(24),
          topRight: const Radius.circular(24),
          bottomLeft: isDesktop ? const Radius.circular(16) : Radius.zero,
          bottomRight: isDesktop ? const Radius.circular(16) : Radius.zero,
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: isDesktop ? 384 : null,
            height: isDesktop ? null : MediaQuery.of(context).size.height * 0.6,
            constraints: BoxConstraints(
              maxHeight: isDesktop ? 400 : double.infinity,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.95),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(24),
                topRight: const Radius.circular(24),
                bottomLeft: isDesktop ? const Radius.circular(16) : Radius.zero,
                bottomRight: isDesktop
                    ? const Radius.circular(16)
                    : Radius.zero,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chapters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: onClose,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          child: const Icon(
                            LucideIcons.x,
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Chapter list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 24,
                    ),
                    itemCount: book.chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = book.chapters[index];
                      // Get just the chapter name (after the colon)
                      final chapterTitle = chapter.title.contains(':')
                          ? chapter.title.split(':')[1].trim()
                          : chapter.title;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onChapterTap?.call(chapter),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '${chapter.id}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    chapterTitle,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  chapter.duration,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

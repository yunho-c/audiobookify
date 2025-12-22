import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';
import 'shared/pressable.dart';

Future<void> showBookActionsSheet({
  required BuildContext context,
  required String title,
  required String author,
  Uint8List? coverImage,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(110),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return _BookActionsSheet(
        title: title,
        author: author,
        coverImage: coverImage,
        onDelete: onDelete,
      );
    },
  );
}

class _BookActionsSheet extends StatelessWidget {
  final String title;
  final String author;
  final Uint8List? coverImage;
  final VoidCallback onDelete;

  const _BookActionsSheet({
    required this.title,
    required this.author,
    required this.coverImage,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final glassBackground = extras?.glassBackground ?? colorScheme.surface;
    final glassBorder = extras?.glassBorder ?? colorScheme.outlineVariant;
    final glassShadow =
        extras?.glassShadow ?? Theme.of(context).shadowColor.withAlpha(25);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: glassBackground,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: glassBorder),
            boxShadow: [
              BoxShadow(
                color: glassShadow,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Row(
                children: [
                  _CoverThumb(coverImage: coverImage),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          author,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Pressable(
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
                pressedOpacity: 0.92,
                pressedScale: 0.98,
                haptic: PressableHaptic.medium,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withAlpha(18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colorScheme.error.withAlpha(120)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.trash2,
                        size: 18,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Delete Book',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Pressable(
                onTap: () => Navigator.of(context).pop(),
                pressedOpacity: 0.96,
                pressedScale: 0.98,
                haptic: PressableHaptic.selection,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
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

class _CoverThumb extends StatelessWidget {
  final Uint8List? coverImage;

  const _CoverThumb({required this.coverImage});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 54,
      height: 72,
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: coverImage == null
          ? Icon(
              LucideIcons.bookOpen,
              color: colorScheme.onSurfaceVariant,
              size: 22,
            )
          : Image.memory(coverImage!, fit: BoxFit.cover),
    );
  }
}

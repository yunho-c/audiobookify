import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LoadingScaffold extends StatelessWidget {
  final Color? backgroundColor;
  final Color? indicatorColor;

  const LoadingScaffold({
    super.key,
    this.backgroundColor,
    this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor:
          backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: CircularProgressIndicator(
          color: indicatorColor ?? colorScheme.primary,
        ),
      ),
    );
  }
}

class ErrorScaffold extends StatelessWidget {
  final String message;
  final String? title;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry? messagePadding;
  final TextAlign messageAlign;

  const ErrorScaffold({
    super.key,
    required this.message,
    this.title,
    this.onBack,
    this.messagePadding,
    this.messageAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasTitle = title != null && title!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: onBack == null
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(LucideIcons.arrowLeft, color: colorScheme.onSurface),
                onPressed: onBack,
              ),
            ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.alertCircle,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            if (hasTitle) ...[
              Text(
                title!,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: messageAlign,
              ),
              const SizedBox(height: 8),
            ],
            Padding(
              padding: messagePadding ?? EdgeInsets.zero,
              child: Text(
                message,
                style: (hasTitle ? textTheme.bodySmall : textTheme.bodyMedium)
                    ?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: messageAlign,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

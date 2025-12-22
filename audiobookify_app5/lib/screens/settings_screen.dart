import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';
import '../core/providers.dart';

/// Settings screen with profile card and menu items
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final themePreference = ref.watch(themePreferenceProvider);
    final debugEnabled = ref.watch(debugModeProvider);
    final crashReportingEnabled = ref.watch(crashReportingProvider);
    final labsEnabled = ref.watch(labsModeProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Header
              Text(
                'Settings',
                style: textTheme.displayLarge,
              ),
              const SizedBox(height: 24),
              if (labsEnabled) ...[
                // Profile card
                _SettingsCard(
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Center(
                          child: Icon(
                            LucideIcons.user,
                            size: 28,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Name and status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'John Doe',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Premium Member',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Edit button
                      Text(
                        'Edit',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              _SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preference in AppThemePreference.values)
                          ChoiceChip(
                            label: Text(preference.label),
                            selected: themePreference == preference,
                            onSelected: (_) {
                              ref
                                  .read(themePreferenceProvider.notifier)
                                  .setPreference(preference);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'System matches your device settings.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SettingsCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LucideIcons.bug,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Debug Mode',
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Show progress diagnostics',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: debugEnabled,
                      onChanged: (value) {
                        ref
                            .read(debugModeProvider.notifier)
                            .setEnabled(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SettingsCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LucideIcons.shield,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crash Reporting',
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Send anonymous diagnostics',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: crashReportingEnabled,
                      onChanged: (value) {
                        ref
                            .read(crashReportingProvider.notifier)
                            .setEnabled(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SettingsCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LucideIcons.flaskConical,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Labs',
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Opt-in to using experimental features',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: labsEnabled,
                      onChanged: (value) {
                        ref.read(labsModeProvider.notifier).setEnabled(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Menu items group 1
              _SettingsCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (labsEnabled)
                      _MenuItem(
                        icon: LucideIcons.user,
                        label: 'Account',
                        showDivider: true,
                      ),
                    _MenuItem(
                      icon: LucideIcons.bell,
                      label: 'Notifications',
                      showDivider: true,
                    ),
                    _MenuItem(
                      icon: LucideIcons.shield,
                      label: 'Privacy & Security',
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Menu items group 2
              _SettingsCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _MenuItem(
                      icon: LucideIcons.helpCircle,
                      label: 'Help & Support',
                      showDivider: true,
                    ),
                    if (labsEnabled)
                      _MenuItem(
                        icon: LucideIcons.logOut,
                        label: 'Log Out',
                        showDivider: false,
                        isDestructive: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Version
              Center(
                child: Text(
                  'Version 1.0.0',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 100), // Space for bottom nav
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool showDivider;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.showDivider,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isDestructive
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        isDestructive ? colorScheme.error : colorScheme.onSurface,
                  ),
                ),
              ),
              if (!isDestructive)
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: colorScheme.outline,
                ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SettingsCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shadowColor = Theme.of(context).shadowColor.withAlpha(15);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

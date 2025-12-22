import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_theme.dart';
import '../core/providers.dart';

/// Settings screen with profile card and menu items
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const String _issuesUrl =
      'https://github.com/yunho-c/audiobookify/issues';
  static const String _contactEmail = 'audiobookify@yunhocho.com';
  static const String _appStoreUrl = 'https://example.com/app-store';
  static const String _googlePlayUrl = 'https://example.com/google-play';
  static const String _microsoftStoreUrl = 'https://example.com/microsoft-store';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _openExternalUrl(
    BuildContext context,
    String url, {
    String failureMessage = 'Unable to open link.',
  }) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage)),
        );
      }
    }
  }

  Future<void> _openIssues(BuildContext context) async {
    await _openExternalUrl(
      context,
      SettingsScreen._issuesUrl,
      failureMessage: 'Unable to open GitHub Issues.',
    );
  }

  Future<void> _sendFeedback(BuildContext context) async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter feedback first.')),
      );
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: SettingsScreen._contactEmail,
      queryParameters: {'body': text},
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open email client.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Help & Feedback',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share bugs or feature requests on GitHub Issues.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openIssues(context),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open GitHub Issues'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Leave a review',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openExternalUrl(
                            context,
                            SettingsScreen._appStoreUrl,
                            failureMessage: 'Unable to open App Store.',
                          ),
                          icon: const Icon(Icons.store, size: 18),
                          label: const Text('App Store'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openExternalUrl(
                            context,
                            SettingsScreen._googlePlayUrl,
                            failureMessage: 'Unable to open Google Play.',
                          ),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Google Play'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openExternalUrl(
                            context,
                            SettingsScreen._microsoftStoreUrl,
                            failureMessage: 'Unable to open Microsoft Store.',
                          ),
                          icon: const Icon(Icons.window, size: 18),
                          label: const Text('Microsoft Store'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _feedbackController,
                      minLines: 3,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Share feedback...',
                        filled: true,
                        fillColor: colorScheme.surfaceVariant.withAlpha(120),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: colorScheme.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: colorScheme.primary, width: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _sendFeedback(context),
                        child: const Text('Send feedback'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        SelectableText(
                          SettingsScreen._contactEmail,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (labsEnabled) ...[
                const SizedBox(height: 24),
                _SettingsCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: const [
                      _MenuItem(
                        icon: LucideIcons.logOut,
                        label: 'Log Out',
                        showDivider: false,
                        isDestructive: true,
                      ),
                    ],
                  ),
                ),
              ],
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

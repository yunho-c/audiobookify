import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
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

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  final TextEditingController _feedbackController = TextEditingController();
  PackageInfo? _packageInfo;
  PermissionStatus? _notificationStatus;
  bool _notificationBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPackageInfo();
    _loadNotificationStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotificationStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _packageInfo = info);
  }

  Future<void> _loadNotificationStatus() async {
    final status = await Permission.notification.status;
    if (!mounted) return;
    setState(() => _notificationStatus = status);
  }

  String _versionLabel() {
    final info = _packageInfo;
    if (info == null) return 'Version -';
    final version = info.version.trim();
    final build = info.buildNumber.trim();
    if (version.isEmpty && build.isEmpty) return 'Version -';
    if (build.isEmpty) return 'Version $version';
    if (version.isEmpty) return 'Version $build';
    return 'Version $version ($build)';
  }

  String _notificationSubtitle(PermissionStatus? status) {
    if (status == null) return 'Check notification permission';
    if (status.isGranted) return 'Enabled';
    if (status.isLimited) return 'Limited';
    if (status.isPermanentlyDenied || status.isRestricted) {
      return 'Blocked in system settings';
    }
    if (status.isDenied) return 'Off';
    return 'Unavailable';
  }

  String _notificationActionLabel(PermissionStatus? status) {
    if (status == null) return 'Check';
    if (status.isGranted) return 'Manage';
    if (status.isPermanentlyDenied || status.isRestricted) {
      return 'Open Settings';
    }
    return 'Enable';
  }

  Future<void> _handleNotificationAction(BuildContext context) async {
    if (_notificationBusy) return;
    setState(() => _notificationBusy = true);
    try {
      final current =
          _notificationStatus ?? await Permission.notification.status;
      PermissionStatus updated;
      if (current.isGranted) {
        await openAppSettings();
        updated = await Permission.notification.status;
      } else if (current.isPermanentlyDenied || current.isRestricted) {
        await openAppSettings();
        updated = await Permission.notification.status;
      } else {
        updated = await Permission.notification.request();
      }
      if (!mounted) return;
      setState(() => _notificationStatus = updated);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update notifications.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _notificationBusy = false);
      }
    }
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
                    if (themePreference == AppThemePreference.system) ...[
                      const SizedBox(height: 8),
                      Text(
                        'System matches your device settings.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SettingsCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsToggleRow(
                      icon: LucideIcons.bug,
                      title: 'Debug Mode',
                      subtitle: 'Show progress diagnostics',
                      value: debugEnabled,
                      onChanged: (value) {
                        ref
                            .read(debugModeProvider.notifier)
                            .setEnabled(value);
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _SettingsToggleRow(
                      icon: LucideIcons.shield,
                      title: 'Crash Reporting',
                      subtitle: 'Send anonymous diagnostics',
                      value: crashReportingEnabled,
                      onChanged: (value) {
                        ref
                            .read(crashReportingProvider.notifier)
                            .setEnabled(value);
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _SettingsToggleRow(
                      icon: LucideIcons.flaskConical,
                      title: 'Labs',
                      subtitle: 'Opt-in to using experimental features',
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
                    _NotificationSettingsRow(
                      isBusy: _notificationBusy,
                      subtitle: _notificationSubtitle(_notificationStatus),
                      actionLabel:
                          _notificationActionLabel(_notificationStatus),
                      onAction: () => _handleNotificationAction(context),
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
                  _versionLabel(),
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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

class _NotificationSettingsRow extends StatelessWidget {
  final bool isBusy;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final bool showDivider;

  const _NotificationSettingsRow({
    required this.isBusy,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.showDivider,
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
                LucideIcons.bell,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: isBusy ? null : onAction,
                  child: isBusy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : Text(actionLabel),
                ),
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

class _SettingsToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
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
              icon,
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
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
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

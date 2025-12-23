import 'dart:io';
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
  static const String _microsoftStoreUrl =
      'https://example.com/microsoft-store';
  static const String _privacyPolicyUrl = 'https://example.com/privacy';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  final TextEditingController _feedbackController = TextEditingController();
  PackageInfo? _packageInfo;
  PermissionStatus? _notificationStatus;
  bool _notificationBusy = false;
  bool _isClearingAppData = false;

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failureMessage)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failureMessage)));
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

  Future<void> _showCrashReportingDetails(BuildContext context) async {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Crash Reporting Details'),
          content: SingleChildScrollView(
            child: DefaultTextStyle(
              style: textTheme.bodyMedium!.copyWith(
                color: colorScheme.onSurface,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'When enabled, crash reports include:',
                  ),
                  SizedBox(height: 8),
                  Text('• App version and build'),
                  Text('• Device model and OS version'),
                  Text('• Stack traces and error context'),
                  Text('• Performance traces (when enabled)'),
                  SizedBox(height: 12),
                  Text(
                    'Reports never include your book files or personal notes.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showThirdPartyDetails(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Third-Party Services'),
          content: const Text(
            'Audiobookify uses Open Library and Archive.org for discovery and '
            'downloads, and Sentry for optional crash reporting.',
          ),
          actions: [
            TextButton(
              onPressed: () => _openExternalUrl(
                dialogContext,
                'https://openlibrary.org/privacy',
                failureMessage: 'Unable to open Open Library privacy policy.',
              ),
              child: const Text('Open Library'),
            ),
            TextButton(
              onPressed: () => _openExternalUrl(
                dialogContext,
                'https://archive.org/about/privacy.php',
                failureMessage: 'Unable to open Archive.org privacy policy.',
              ),
              child: const Text('Archive.org'),
            ),
            TextButton(
              onPressed: () => _openExternalUrl(
                dialogContext,
                'https://sentry.io/privacy/',
                failureMessage: 'Unable to open Sentry privacy policy.',
              ),
              child: const Text('Sentry'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPermissionsDetails(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Permissions'),
          content: const Text(
            'Notification permissions are managed above. '
            'Use system settings to review or change permissions.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await openAppSettings();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<_StorageSnapshot> _loadStorageSnapshot() async {
    final service = ref.read(bookServiceProvider);
    final books = service.getAllBooks();
    var totalBytes = 0;
    for (final book in books) {
      final path = book.filePath.trim();
      if (path.isEmpty) continue;
      try {
        final file = File(path);
        if (await file.exists()) {
          totalBytes += await file.length();
        }
      } catch (_) {
        // Ignore file size errors.
      }
    }
    return _StorageSnapshot(
      bookCount: books.length,
      totalBytes: totalBytes,
    );
  }

  Future<void> _showStorageDetails(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final textTheme = Theme.of(sheetContext).textTheme;
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: FutureBuilder<_StorageSnapshot>(
            future: _loadStorageSnapshot(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Checking local storage...',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              }
              final data = snapshot.data!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stored on this device',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${data.bookCount} saved books',
                    style: textTheme.bodyMedium,
                  ),
                  Text(
                    _formatBytes(data.totalBytes),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Clearing app data removes downloads and listening history.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B used';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex += 1;
    }
    return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unitIndex]} used';
  }

  Future<void> _confirmClearAppData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear app data?'),
          content: const Text(
            'This removes downloaded books and listening progress from this '
            'device. Your preferences will remain.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
    if (confirm != true || !mounted) return;
    if (_isClearingAppData) return;
    setState(() => _isClearingAppData = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(bookServiceProvider);
      final books = service.getAllBooks();
      var removed = 0;
      for (final book in books) {
        final didRemove = await service.deleteBookAndAssets(book.id);
        if (didRemove) removed += 1;
      }
      ref.read(bookResumeProvider.notifier).clearAll();
      messenger.showSnackBar(
        SnackBar(content: Text('Removed $removed books from this device.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to clear app data.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isClearingAppData = false);
      }
    }
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
              Text('Settings', style: textTheme.displayLarge),
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
                    _MenuItem(
                      icon: LucideIcons.smile,
                      label: 'About Audiobookify',
                      showDivider: false,
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'Audiobookify',
                          applicationVersion: _versionLabel().replaceFirst(
                            'Version ',
                            '',
                          ),
                        );
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
                      actionLabel: _notificationActionLabel(
                        _notificationStatus,
                      ),
                      onAction: () => _handleNotificationAction(context),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SettingsCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacy & Security',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Manage disclosures, permissions, and local data.',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _InfoRow(
                      icon: LucideIcons.fileText,
                      title: 'Privacy Policy',
                      subtitle: 'What we collect and why',
                      trailingLabel: 'View',
                      showDivider: true,
                      showExternalIcon: true,
                      onTap: () => _openExternalUrl(
                        context,
                        SettingsScreen._privacyPolicyUrl,
                        failureMessage: 'Unable to open privacy policy.',
                      ),
                    ),
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
                    _InfoRow(
                      icon: LucideIcons.activity,
                      title: 'Crash Reporting Details',
                      subtitle: 'Diagnostics included in reports',
                      trailingLabel: 'View',
                      showDivider: true,
                      onTap: () => _showCrashReportingDetails(context),
                    ),
                    _InfoRow(
                      icon: LucideIcons.database,
                      title: 'Data Stored on Device',
                      subtitle: 'Books, progress, and preferences',
                      trailingLabel: 'View',
                      showDivider: true,
                      onTap: () => _showStorageDetails(context),
                    ),
                    _InfoRow(
                      icon: LucideIcons.key,
                      title: 'Permissions',
                      subtitle: 'Notifications and storage access',
                      trailingLabel: 'Manage',
                      showDivider: true,
                      onTap: () => _showPermissionsDetails(context),
                    ),
                    _InfoRow(
                      icon: LucideIcons.link,
                      title: 'Third-Party Services',
                      subtitle: 'Open Library, Archive.org, Sentry',
                      trailingLabel: 'View',
                      showDivider: true,
                      onTap: () => _showThirdPartyDetails(context),
                    ),
                    _InfoRow(
                      icon: LucideIcons.trash2,
                      title: 'Clear App Data',
                      subtitle: 'Remove downloads and history',
                      trailingLabel: _isClearingAppData ? 'Clearing...' : 'Clear',
                      showDivider: false,
                      isDestructive: true,
                      onTap: _isClearingAppData
                          ? null
                          : () => _confirmClearAppData(context),
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
                    const SizedBox(height: 12),
                    Text(
                      'Leave a review',
                      style: textTheme.labelLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      "Please freely share what you like/don't like about Audiobookify!",
                      style: textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        color: colorScheme.onSurfaceVariant,
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
                          label: const Text('Apple App Store'),
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
                        OutlinedButton.icon(
                          onPressed: () => _openExternalUrl(
                            context,
                            SettingsScreen._microsoftStoreUrl,
                            failureMessage: 'Unable to open Snap Store.',
                          ),
                          icon: const Icon(Icons.window, size: 18),
                          label: const Text('Snap Store'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Talk to developer',
                      style: textTheme.labelLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 1.4,
                          ),
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
                    const SizedBox(height: 16),
                    Text(
                      'Share bugs or feature requests',
                      style: textTheme.labelLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'on GitHub',
                      style: textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openIssues(context),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open GitHub Issues'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SettingsCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _MenuItem(
                      icon: LucideIcons.fileText,
                      label: 'Open-source licenses',
                      showDivider: false,
                      onTap: () {
                        showLicensePage(
                          context: context,
                          applicationName: 'Audiobookify',
                          applicationVersion: _versionLabel().replaceFirst(
                            'Version ',
                            '',
                          ),
                        );
                      },
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
              const SizedBox(height: 24),
              _SettingsCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Developer',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _SettingsToggleRow(
                      icon: LucideIcons.bug,
                      title: 'Debug Mode',
                      subtitle: 'Show diagnostics',
                      value: debugEnabled,
                      onChanged: (value) {
                        ref.read(debugModeProvider.notifier).setEnabled(value);
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
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.showDivider,
    this.isDestructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final row = Padding(
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
                color: isDestructive
                    ? colorScheme.error
                    : colorScheme.onSurface,
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
    );
    return Column(
      children: [
        if (onTap == null)
          row
        else
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: row,
          ),
        if (showDivider) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailingLabel;
  final bool showDivider;
  final bool isDestructive;
  final VoidCallback? onTap;
  final bool showExternalIcon;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.showDivider,
    this.isDestructive = false,
    this.onTap,
    this.showExternalIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final titleColor = isDestructive
        ? colorScheme.error
        : colorScheme.onSurface;
    final iconColor = isDestructive
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;
    final trailingColor = isDestructive
        ? colorScheme.error
        : colorScheme.outline;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            trailingLabel,
            style: textTheme.labelSmall?.copyWith(
              color: trailingColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showExternalIcon) ...[
            const SizedBox(width: 8),
            Icon(
              LucideIcons.externalLink,
              size: 16,
              color: colorScheme.outline,
            ),
          ],
        ],
      ),
    );

    return Column(
      children: [
        if (onTap == null)
          row
        else
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: row,
          ),
        if (showDivider) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

class _StorageSnapshot {
  final int bookCount;
  final int totalBytes;

  const _StorageSnapshot({
    required this.bookCount,
    required this.totalBytes,
  });
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
        if (showDivider) const Divider(height: 1, indent: 16, endIndent: 16),
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
            child: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
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
          Switch.adaptive(value: value, onChanged: onChanged),
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

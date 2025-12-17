import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';

/// Settings screen with profile card and menu items
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.stone50,
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
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.stone800,
                ),
              ),
              const SizedBox(height: 24),
              // Profile card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.stone200,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.user,
                          size: 28,
                          color: AppColors.stone500,
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
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.stone800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Premium Member',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.stone500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Edit button
                    Text(
                      'Edit',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.orange600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Menu items group 1
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
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
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _MenuItem(
                      icon: LucideIcons.helpCircle,
                      label: 'Help & Support',
                      showDivider: true,
                    ),
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
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.stone400,
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isDestructive ? AppColors.red400 : AppColors.stone400,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDestructive
                        ? AppColors.red600
                        : AppColors.stone700,
                  ),
                ),
              ),
              if (!isDestructive)
                const Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: AppColors.stone300,
                ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.stone100,
          ),
      ],
    );
  }
}

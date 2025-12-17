import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';

/// Create screen with upload area and options
class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.stone50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Header
              Text(
                'Create Audiobook',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.stone800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Turn your text into lifelike speech',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.stone500,
                ),
              ),
              const SizedBox(height: 48),
              // Main upload area
              Container(
                width: double.infinity,
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.stone200, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.orange100,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.upload,
                          size: 32,
                          color: AppColors.orange600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Upload Text',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.stone800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Drag & drop PDF, EPUB, or TXT files here',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.stone500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Option buttons
              Row(
                children: [
                  Expanded(
                    child: _OptionCard(
                      icon: LucideIcons.fileText,
                      label: 'Paste Text',
                      bgColor: AppColors.blue100,
                      fgColor: AppColors.blue600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _OptionCard(
                      icon: LucideIcons.mic,
                      label: 'Record Voice',
                      bgColor: AppColors.emerald100,
                      fgColor: AppColors.emerald600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Recent drafts
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent Drafts',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.stone800,
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.stone100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.fileText,
                        size: 18,
                        color: AppColors.stone400,
                      ),
                    ),
                  ),
                  title: Text(
                    'My Biography',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.stone800,
                    ),
                  ),
                  subtitle: Text(
                    'Edited 2h ago',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.stone400,
                    ),
                  ),
                  trailing: const Icon(
                    LucideIcons.arrowRight,
                    size: 18,
                    color: AppColors.stone300,
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

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color fgColor;

  const _OptionCard({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(child: Icon(icon, size: 20, color: fgColor)),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.stone700,
            ),
          ),
        ],
      ),
    );
  }
}

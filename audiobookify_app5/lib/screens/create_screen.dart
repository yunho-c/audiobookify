import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../core/app_theme.dart';
import '../src/rust/api/epub.dart';

/// Create screen with upload area and options
class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  bool _isLoading = false;
  EpubBook? _loadedBook;
  String? _errorMessage;

  Future<void> _pickAndLoadEpub() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          final book = await openEpub(path: path);
          setState(() {
            _loadedBook = book;
            _isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Loaded: ${book.metadata.title ?? "Unknown"}'),
                backgroundColor: AppColors.emerald600,
              ),
            );
          }
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } on EpubError catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

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
              // Main upload area - now tappable
              GestureDetector(
                onTap: _isLoading ? null : _pickAndLoadEpub,
                child: Container(
                  width: double.infinity,
                  height: 280,
                  decoration: BoxDecoration(
                    color: _loadedBook != null
                        ? AppColors.emerald50
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _loadedBook != null
                          ? AppColors.emerald400
                          : AppColors.stone200,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? _buildLoadingState()
                      : _loadedBook != null
                      ? _buildLoadedState()
                      : _buildUploadState(),
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

  Widget _buildUploadState() {
    return Column(
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
          'Upload EPUB',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.stone800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap to select an EPUB file',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.stone500),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: AppColors.orange600),
        const SizedBox(height: 24),
        Text(
          'Loading EPUB...',
          style: GoogleFonts.inter(fontSize: 16, color: AppColors.stone600),
        ),
      ],
    );
  }

  Widget _buildLoadedState() {
    final book = _loadedBook!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Cover image
          Container(
            width: 100,
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.stone200,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 8,
                  offset: const Offset(2, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: book.coverImage != null
                ? Image.memory(book.coverImage!, fit: BoxFit.cover)
                : const Center(
                    child: Icon(
                      LucideIcons.book,
                      size: 32,
                      color: AppColors.stone400,
                    ),
                  ),
          ),
          const SizedBox(width: 20),
          // Book info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emerald100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '✓ Loaded',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  book.metadata.title ?? 'Unknown Title',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.stone800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  book.metadata.creator ?? 'Unknown Author',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.stone500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${book.chapters.length} chapters',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.stone400,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Navigate to conversion/processing
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Create Audiobook',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

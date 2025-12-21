import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../core/app_theme.dart';
import '../core/providers.dart';
import '../src/rust/api/epub.dart';

/// Create screen with upload area and options
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  bool _isLoading = false;
  EpubBook? _loadedBook;
  String? _errorMessage;
  String? _loadedFilePath;

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
      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          final book = await openEpub(path: path);
          if (!mounted) return;
          setState(() {
            _loadedBook = book;
            _loadedFilePath = path;
            _isLoading = false;
          });

          final colorScheme = Theme.of(context).colorScheme;
          final extras = Theme.of(context).extension<AppThemeExtras>();
          final successColor = extras?.accentPalette[3] ?? colorScheme.primary;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded: ${book.metadata.title ?? "Unknown"}'),
              backgroundColor: successColor,
            ),
          );
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Unable to read file path.';
          });
          final colorScheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Error: unable to read file path'),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    } on EpubError catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.message}'),
          backgroundColor: colorScheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final accentPalette = extras?.accentPalette ??
        [
          colorScheme.primary,
          colorScheme.primary,
          colorScheme.primary,
          colorScheme.primary,
        ];
    final accentSoftPalette = extras?.accentSoftPalette ??
        [
          colorScheme.primary.withAlpha(15),
          colorScheme.primary.withAlpha(15),
          colorScheme.primary.withAlpha(15),
          colorScheme.primary.withAlpha(15),
        ];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Header
              Text(
                'Create Audiobook',
                style: textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Turn your text into lifelike speech',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
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
                        ? colorScheme.primary.withAlpha(15)
                        : colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _loadedBook != null
                          ? colorScheme.primary
                          : colorScheme.outline,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withAlpha(15),
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
                      bgColor: accentSoftPalette[2],
                      fgColor: accentPalette[2],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _OptionCard(
                      icon: LucideIcons.mic,
                      label: 'Record Voice',
                      bgColor: accentSoftPalette[3],
                      fgColor: accentPalette[3],
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
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withAlpha(15),
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
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        LucideIcons.fileText,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  title: Text(
                    'My Biography',
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Edited 2h ago',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    LucideIcons.arrowRight,
                    size: 18,
                    color: colorScheme.outline,
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: colorScheme.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Center(
            child: Icon(
              LucideIcons.upload,
              size: 32,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Upload EPUB',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap to select an EPUB file',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingState() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'Loading EPUB...',
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadedState() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final successColor = extras?.accentPalette[3] ?? colorScheme.primary;
    final successSoft =
        extras?.accentSoftPalette[3] ?? colorScheme.primary.withAlpha(15);
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
              color: colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withAlpha(30),
                  blurRadius: 8,
                  offset: const Offset(2, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: book.coverImage != null
                ? Image.memory(book.coverImage!, fit: BoxFit.cover)
                : Center(
                    child: Icon(
                      LucideIcons.book,
                      size: 32,
                      color: colorScheme.onSurfaceVariant,
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
                        color: successSoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '✓ Loaded',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: successColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  book.metadata.title ?? 'Unknown Title',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  book.metadata.creator ?? 'Unknown Author',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${book.chapters.length} chapters',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Save book to database
                      if (_loadedBook != null && _loadedFilePath != null) {
                        final savedBook = ref
                            .read(bookServiceProvider)
                            .saveBook(_loadedBook!, _loadedFilePath!);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added "${savedBook.title}" to library',
                              ),
                              backgroundColor: successColor,
                            ),
                          );

                          // Navigate to home screen
                          context.go('/');
                        }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Create Audiobook',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(15),
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
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

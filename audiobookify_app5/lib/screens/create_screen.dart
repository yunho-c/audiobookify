import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../core/app_theme.dart';
import '../core/providers.dart';
import '../models/public_book.dart';
import '../src/rust/api/epub.dart';

/// Create screen with upload area and options
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

enum _CreateMode { import, discover }

class _CreateScreenState extends ConsumerState<CreateScreen> {
  bool _isLoading = false;
  EpubBook? _loadedBook;
  String? _errorMessage;
  String? _loadedFilePath;
  _CreateMode _mode = _CreateMode.import;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchText = '';
  String _searchQuery = '';

  static const List<String> _exploreSuggestions = [
    'Sherlock Holmes',
    'Jane Austen',
    'Greek Mythology',
    'Science Fiction',
    'Poetry',
    'Philosophy',
  ];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

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

  void _selectMode(_CreateMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchText = value);
    if (value.trim().isEmpty) {
      _searchDebounce?.cancel();
      setState(() => _searchQuery = '');
      return;
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _searchQuery = value);
    });
  }

  void _setSearchQuery(String value) {
    _searchDebounce?.cancel();
    _searchController.text = value;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: _searchController.text.length),
    );
    setState(() {
      _searchText = value;
      _searchQuery = value;
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _showDownloadComingSoon(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download for \"$title\" coming next.'),
        backgroundColor: colorScheme.surface,
      ),
    );
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 24),
              _buildModeToggle(textTheme, colorScheme),
              const SizedBox(height: 32),
              if (_mode == _CreateMode.import)
                _buildImportSection(
                  context: context,
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                  accentPalette: accentPalette,
                  accentSoftPalette: accentSoftPalette,
                )
              else
                _buildDiscoverSection(
                  context: context,
                  ref: ref,
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
              const SizedBox(height: 100), // Space for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle(TextTheme textTheme, ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_CreateMode>(
        segments: [
          const ButtonSegment<_CreateMode>(
            value: _CreateMode.import,
            label: Text('Import'),
            icon: Icon(LucideIcons.upload),
          ),
          const ButtonSegment<_CreateMode>(
            value: _CreateMode.discover,
            label: Text('Discover'),
            icon: Icon(LucideIcons.search),
          ),
        ],
        selected: {_mode},
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          selectedForegroundColor: colorScheme.onPrimary,
          selectedBackgroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outlineVariant),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        onSelectionChanged: (selection) {
          _selectMode(selection.first);
        },
      ),
    );
  }

  Widget _buildImportSection({
    required BuildContext context,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    required List<Color> accentPalette,
    required List<Color> accentSoftPalette,
  }) {
    return Column(
      children: [
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
                color:
                    _loadedBook != null ? colorScheme.primary : colorScheme.outline,
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
      ],
    );
  }

  Widget _buildDiscoverSection({
    required BuildContext context,
    required WidgetRef ref,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    final searchQuery = _searchQuery.trim();
    final searchArgs = OpenLibrarySearchArgs(query: searchQuery);
    final searchProvider = openLibrarySearchProvider(searchArgs);
    final searchAsync = ref.watch(searchProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(colorScheme, textTheme),
        const SizedBox(height: 16),
        if (searchQuery.isEmpty)
          _buildExploreSection(textTheme, colorScheme)
        else ...[
          Text(
            'Results for \"$searchQuery\"',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          searchAsync.when(
            loading: () => _buildSearchLoading(colorScheme, textTheme),
            error: (error, _) => _buildSearchError(
              error,
              onRetry: () => ref.invalidate(searchProvider),
              textTheme: textTheme,
              colorScheme: colorScheme,
            ),
            data: (books) => _buildSearchResults(
              books,
              textTheme,
              colorScheme,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme, TextTheme textTheme) {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search public domain books',
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        prefixIcon: Icon(
          LucideIcons.search,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        suffixIcon: _searchText.trim().isEmpty
            ? null
            : IconButton(
                icon: const Icon(LucideIcons.x, size: 18),
                color: colorScheme.onSurfaceVariant,
                onPressed: () => _setSearchQuery(''),
              ),
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildExploreSection(TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore the public domain',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap a category or try a search to discover classics ready to play.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _exploreSuggestions
              .map(
                (label) => ActionChip(
                  label: Text(label),
                  onPressed: () => _setSearchQuery(label),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSearchLoading(ColorScheme colorScheme, TextTheme textTheme) {
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
          'Searching Open Library...',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchError(
    Object error, {
    required VoidCallback onRetry,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load results.',
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            error.toString(),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(
    List<PublicBook> books,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    if (books.isEmpty) {
      return Text(
        'No public-domain editions found. Try a different keyword.',
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _getResultsCrossAxisCount(constraints.maxWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: books.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.62,
          ),
          itemBuilder: (context, index) {
            final book = books[index];
            return _PublicBookCard(
              book: book,
              onDownload: () => _showDownloadComingSoon(book.title),
            );
          },
        );
      },
    );
  }

  int _getResultsCrossAxisCount(double width) {
    if (width >= 980) return 4;
    if (width >= 720) return 3;
    return 2;
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

class _PublicBookCard extends StatelessWidget {
  final PublicBook book;
  final VoidCallback onDownload;

  const _PublicBookCard({
    required this.book,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: book.coverUrl == null
                      ? _CoverPlaceholder()
                      : Image.network(
                          book.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _CoverPlaceholder();
                          },
                        ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withAlpha(210),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Public Domain',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(
              book.title,
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${book.primaryAuthor} • ${book.yearLabel}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDownload,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.primary),
                ),
                child: const Text('Download EPUB'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceVariant,
            colorScheme.surface,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          LucideIcons.bookOpen,
          color: colorScheme.onSurfaceVariant,
          size: 36,
        ),
      ),
    );
  }
}

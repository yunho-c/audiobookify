import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import '../core/app_theme.dart';
import '../core/error_reporter.dart';
import '../core/providers.dart';
import '../models/open_library_work.dart';
import '../models/public_book.dart';
import '../src/rust/api/epub.dart';
import '../widgets/shared/pressable.dart';

/// Create screen with upload area and options
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

enum _CreateMode { import, discover }

class _DownloadCanceled implements Exception {
  const _DownloadCanceled();
}

class _DownloadController {
  bool _isCanceled = false;
  StreamSubscription<List<int>>? subscription;
  http.Client? client;
  Future<void> Function()? _cancelHandler;

  bool get isCanceled => _isCanceled;

  void setCancelHandler(Future<void> Function() handler) {
    _cancelHandler = handler;
  }

  void cancel() {
    if (_isCanceled) return;
    _isCanceled = true;
    subscription?.cancel();
    client?.close();
    final handler = _cancelHandler;
    if (handler != null) {
      unawaited(handler());
    }
  }
}

bool _isValidEpubInIsolate(String path) {
  try {
    final file = File(path);
    if (!file.existsSync()) return false;
    final length = file.lengthSync();
    if (length < 1024) return false;
    final input = InputFileStream(path);
    try {
      final archive = ZipDecoder().decodeBuffer(input, verify: true);
      final mimetypeEntry = archive.findFile('mimetype');
      if (mimetypeEntry == null) return false;
      final mimetypeContent = mimetypeEntry.content;
      final mimetype = switch (mimetypeContent) {
        String value => value.trim(),
        List<int> bytes => utf8.decode(bytes, allowMalformed: true).trim(),
        _ => '',
      };
      if (mimetype != 'application/epub+zip') return false;
      return archive.findFile('META-INF/container.xml') != null;
    } finally {
      input.close();
    }
  } catch (_) {
    return false;
  }
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  bool _isLoading = false;
  EpubBook? _loadedBook;
  String? _errorMessage;
  String? _loadedFilePath;
  _CreateMode _mode = _CreateMode.import;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  String _searchText = '';
  String _searchQuery = '';
  final Set<String> _downloadsInProgress = {};
  final Map<String, double?> _downloadProgress = {};
  final Map<String, _DownloadController> _downloadControllers = {};

  static const Duration _requestTimeout = Duration(seconds: 12);
  static const Duration _downloadIdleTimeout = Duration(seconds: 20);

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
    _searchFocusNode.dispose();
    for (final controller in _downloadControllers.values) {
      controller.cancel();
    }
    _downloadControllers.clear();
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
    } on EpubError catch (e, stackTrace) {
      reportError(e, stackTrace, context: 'create_screen.pickEpub');
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
    } catch (e, stackTrace) {
      reportError(e, stackTrace, context: 'create_screen.pickEpub');
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
    if (mode == _CreateMode.discover) {
      _focusSearchSoon();
    }
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

  void _focusSearchSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  bool _isDownloading(PublicBook book) {
    return _downloadsInProgress.contains(book.iaId);
  }

  double? _downloadProgressFor(PublicBook book) {
    return _downloadProgress[book.iaId];
  }

  void _setDownloadProgress(String iaId, double progress) {
    if (progress.isNaN || progress < 0) {
      if (!mounted) return;
      setState(() => _downloadProgress[iaId] = null);
      return;
    }
    final clamped = progress.clamp(0.0, 1.0);
    final previous = _downloadProgress[iaId];
    if (previous != null && (clamped - previous).abs() < 0.02) {
      return;
    }
    if (!mounted) return;
    setState(() => _downloadProgress[iaId] = clamped);
  }

  void _cancelDownload(PublicBook book) {
    final controller = _downloadControllers[book.iaId];
    if (controller == null) return;
    controller.cancel();
  }

  Future<void> _downloadAndImport(PublicBook book, {bool closeDetails = false}) async {
    if (_downloadsInProgress.contains(book.iaId)) return;
    final controller = _DownloadController();
    setState(() {
      _downloadsInProgress.add(book.iaId);
      _downloadProgress[book.iaId] = null;
      _downloadControllers[book.iaId] = controller;
    });

    if (closeDetails && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final successColor = extras?.accentPalette[3] ?? colorScheme.primary;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final textTheme = Theme.of(context).textTheme;
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          'Downloading "${book.title}"...',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
      ),
    );

    File? downloadedFile;
    try {
      downloadedFile = await _downloadEpubToFile(
        book,
        onProgress: (progress) => _setDownloadProgress(book.iaId, progress),
        controller: controller,
      );
      if (!await _isValidEpub(downloadedFile)) {
        await _deleteIfExists(downloadedFile);
        throw const EpubError(message: 'Downloaded file is not a valid EPUB.');
      }
      final epub = await openEpub(path: downloadedFile.path);
      if (!mounted) return;
      final savedBook =
          ref.read(bookServiceProvider).saveBook(epub, downloadedFile.path);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Added "${savedBook.title}" to library'),
          backgroundColor: successColor,
        ),
      );

      if (mounted) {
        context.go('/');
      }
    } on _DownloadCanceled {
      if (downloadedFile != null) {
        await _deleteIfExists(downloadedFile);
      }
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('Download canceled'),
          backgroundColor: colorScheme.surface,
        ),
      );
    } on EpubError catch (error, stackTrace) {
      reportError(error, stackTrace, context: 'create_screen.download');
      if (downloadedFile != null) {
        await _deleteIfExists(downloadedFile);
      }
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Download failed: ${error.message}'),
          backgroundColor: colorScheme.error,
        ),
      );
    } catch (error, stackTrace) {
      reportError(error, stackTrace, context: 'create_screen.download');
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Download failed: $error'),
          backgroundColor: colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadsInProgress.remove(book.iaId);
          _downloadProgress.remove(book.iaId);
          _downloadControllers.remove(book.iaId);
        });
      }
    }
  }

  Future<Directory> _bookStorageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final libraryDir = Directory('${appDir.path}/library');
    if (!await libraryDir.exists()) {
      await libraryDir.create(recursive: true);
    }
    return libraryDir;
  }

  Future<File> _copyEpubToLibrary({
    required String sourcePath,
    required String title,
  }) async {
    final libraryDir = await _bookStorageDirectory();
    final safeTitle = title.trim().isEmpty ? 'book' : title.trim();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = _sanitizeFileName('$safeTitle-$timestamp');
    final destPath = '${libraryDir.path}/$fileName.epub';
    return File(sourcePath).copy(destPath);
  }

  Future<File> _downloadEpubToFile(
    PublicBook book, {
    ValueChanged<double>? onProgress,
    required _DownloadController controller,
  }) async {
    final client = http.Client();
    controller.client = client;
    try {
      final downloadDir = await _bookStorageDirectory();

      final fileName = _sanitizeFileName('${book.title}-${book.iaId}.epub');
      final file = File('${downloadDir.path}/$fileName');
      if (await file.exists()) {
        if (await _isValidEpub(file)) {
          onProgress?.call(1.0);
          return file;
        }
        await _deleteIfExists(file);
      }

      final uri = await _resolveEpubUri(client, book);

      const maxAttempts = 3;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        try {
          if (controller.isCanceled) {
            throw const _DownloadCanceled();
          }
          final response = await client
              .send(http.Request('GET', uri))
              .timeout(_requestTimeout);
          if (response.statusCode != 200) {
            throw Exception('HTTP ${response.statusCode}');
          }

          final contentLength = response.contentLength ?? 0;
          final sink = file.openWrite();
          final completer = Completer<File>();
          Timer? idleTimer;
          var received = 0;

          Future<void> completeWithError(
            Object error, [
            StackTrace? stackTrace,
          ]) async {
            if (completer.isCompleted) return;
            idleTimer?.cancel();
            try {
              await sink.close();
            } catch (_) {}
            await _deleteIfExists(file);
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          }

          void resetIdleTimer() {
            idleTimer?.cancel();
            idleTimer = Timer(_downloadIdleTimeout, () {
              controller.cancel();
              unawaited(
                completeWithError(
                  TimeoutException('Download stalled.'),
                ),
              );
            });
          }

          controller.setCancelHandler(() {
            return completeWithError(const _DownloadCanceled());
          });

          resetIdleTimer();
          controller.subscription = response.stream.listen(
            (chunk) {
              if (controller.isCanceled) {
                unawaited(completeWithError(const _DownloadCanceled()));
                return;
              }
              resetIdleTimer();
              received += chunk.length;
              sink.add(chunk);
              if (contentLength > 0) {
                onProgress?.call(received / contentLength);
              }
            },
            onError: (error, stackTrace) async {
              if (controller.isCanceled) {
                await completeWithError(const _DownloadCanceled());
                return;
              }
              await completeWithError(error, stackTrace);
            },
            onDone: () async {
              if (controller.isCanceled) {
                await completeWithError(const _DownloadCanceled());
                return;
              }
              idleTimer?.cancel();
              try {
                await sink.close();
              } catch (_) {}
              if (!completer.isCompleted) {
                if (contentLength > 0) {
                  onProgress?.call(1.0);
                } else {
                  onProgress?.call(-1);
                }
                completer.complete(file);
              }
            },
            cancelOnError: true,
          );

          return await completer.future;
        } on _DownloadCanceled {
          await _deleteIfExists(file);
          rethrow;
        } on TimeoutException catch (error) {
          await _deleteIfExists(file);
          if (attempt == maxAttempts - 1) {
            throw error;
          }
        } catch (error) {
          await _deleteIfExists(file);
          if (attempt == maxAttempts - 1) {
            rethrow;
          }
          final backoffMs = 300 * (attempt + 1);
          await Future<void>.delayed(Duration(milliseconds: backoffMs));
        }
      }

      throw const EpubError(message: 'Download failed after retries.');
    } finally {
      client.close();
    }
  }

  Future<Uri> _resolveEpubUri(http.Client client, PublicBook book) async {
    final metadataUri = Uri.parse('https://archive.org/metadata/${book.iaId}');
    try {
      final response =
          await client.get(metadataUri).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        return Uri.parse(book.epubUrl);
      }
      final body = json.decode(response.body);
      if (body is! Map<String, dynamic>) {
        return Uri.parse(book.epubUrl);
      }
      final fileName = _extractEpubFileName(body);
      if (fileName == null || fileName.isEmpty) {
        return Uri.parse(book.epubUrl);
      }
      final encoded = Uri.encodeComponent(fileName);
      return Uri.parse('https://archive.org/download/${book.iaId}/$encoded');
    } catch (_) {
      return Uri.parse(book.epubUrl);
    }
  }

  String? _extractEpubFileName(Map<String, dynamic> metadata) {
    final files = metadata['files'];
    if (files is! List) return null;
    for (final entry in files) {
      if (entry is! Map) continue;
      final name = entry['name'];
      if (name is! String || name.trim().isEmpty) continue;
      final formats = entry['format'];
      if (_hasEpubFormat(formats) || name.toLowerCase().endsWith('.epub')) {
        return name.trim();
      }
    }
    return null;
  }

  bool _hasEpubFormat(dynamic value) {
    if (value is String) {
      return value.toLowerCase().contains('epub');
    }
    if (value is List) {
      for (final entry in value) {
        if (entry is String && entry.toLowerCase().contains('epub')) {
          return true;
        }
      }
    }
    return false;
  }

  Future<bool> _isValidEpub(File file) async {
    return compute(_isValidEpubInIsolate, file.path);
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  String _sanitizeFileName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'untitled.epub';
    final sanitized = trimmed.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _openBookDetails(PublicBook book) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Book details',
      barrierColor: Colors.black.withAlpha(140),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _PublicBookDetailsSheet(
          book: book,
          onDownload: () => _downloadAndImport(book, closeDetails: true),
          onCancel: () => _cancelDownload(book),
          isDownloading: _isDownloading(book),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extras = Theme.of(context).extension<AppThemeExtras>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const _CreateBackdrop(),
          SafeArea(
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
                    )
                  else
                    _buildDiscoverSection(
                      context: context,
                      ref: ref,
                      textTheme: textTheme,
                      colorScheme: colorScheme,
                    ),
                ],
              ),
            ),
          ),
        ],
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
  }) {
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final glassBackground = extras?.glassBackground ?? colorScheme.surface;
    final glassBorder = extras?.glassBorder ?? colorScheme.outlineVariant;
    final glassShadow =
        extras?.glassShadow ?? Theme.of(context).shadowColor.withAlpha(25);
    final baseColor = _loadedBook != null
        ? colorScheme.primary.withAlpha(18)
        : glassBackground;
    return Column(
      children: [
        // Main upload area - now tappable
        Pressable(
          onTap: _isLoading ? null : _pickAndLoadEpub,
          pressedOpacity: 0.96,
          pressedScale: 0.98,
          haptic: PressableHaptic.medium,
          child: Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor,
                  colorScheme.surfaceVariant.withAlpha(130),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _loadedBook != null ? colorScheme.primary : glassBorder,
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: glassShadow,
                  blurRadius: 16,
                  offset: const Offset(0, 6),
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
        const SizedBox(height: 16),
        _buildDiscoverCta(context, textTheme, colorScheme),
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
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final glassBackground = extras?.glassBackground ?? colorScheme.surface;
    final glassBorder = extras?.glassBorder ?? colorScheme.outlineVariant;
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
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
        fillColor: glassBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildExploreSection(TextTheme textTheme, ColorScheme colorScheme) {
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final accentPalette = extras?.accentPalette ??
        const [
          AppColors.rose600,
          AppColors.amber600,
          AppColors.blue600,
          AppColors.emerald600,
        ];
    final accentSoftPalette = extras?.accentSoftPalette ??
        const [
          AppColors.rose100,
          AppColors.amber100,
          AppColors.blue100,
          AppColors.emerald100,
        ];
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
          children: _exploreSuggestions.asMap().entries.map((entry) {
            final index = entry.key;
            final label = entry.value;
            final accent = accentPalette[index % accentPalette.length];
            final accentSoft =
                accentSoftPalette[index % accentSoftPalette.length];
            return ActionChip(
              label: Text(label),
              onPressed: () => _setSearchQuery(label),
              backgroundColor: accentSoft,
              labelStyle: textTheme.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: accent.withAlpha(80)),
              ),
            );
          }).toList(),
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
            return _StaggeredFadeIn(
              delay: _staggerDelayForIndex(index),
              child: _PublicBookCard(
                book: book,
                onTap: () => _openBookDetails(book),
                onDownload: () => _downloadAndImport(book),
                onCancel: () => _cancelDownload(book),
                isDownloading: _isDownloading(book),
                downloadProgress: _downloadProgressFor(book),
              ),
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

  Duration _staggerDelayForIndex(int index) {
    final jitter = (index * 37) % 120;
    return Duration(milliseconds: 40 + jitter);
  }

  Widget _buildDiscoverCta(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final glassBackground = extras?.glassBackground ?? colorScheme.surface;
    final glassBorder = extras?.glassBorder ?? colorScheme.outlineVariant;
    final glassShadow =
        extras?.glassShadow ?? Theme.of(context).shadowColor.withAlpha(25);
    final accent = extras?.accentPalette.first ?? colorScheme.primary;
    final accentSoft = extras?.accentSoftPalette.first ??
        colorScheme.primary.withAlpha(20);
    return Pressable(
      onTap: () => _selectMode(_CreateMode.discover),
      pressedOpacity: 0.95,
      pressedScale: 0.98,
      haptic: PressableHaptic.selection,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: glassBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: glassBorder),
          boxShadow: [
            BoxShadow(
              color: glassShadow,
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                LucideIcons.search,
                color: accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover public-domain books',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Search Open Library and download free EPUBs.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.arrowRight,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
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
            color: colorScheme.onSurface,
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
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (_loadedBook == null ||
                                _loadedFilePath == null) {
                              return;
                            }
                            setState(() {
                              _isLoading = true;
                              _errorMessage = null;
                            });
                            try {
                              final storedFile = await _copyEpubToLibrary(
                                sourcePath: _loadedFilePath!,
                                title: _loadedBook!.metadata.title ?? 'Book',
                              );
                              if (!mounted) return;
                              final savedBook = ref
                                  .read(bookServiceProvider)
                                  .saveBook(_loadedBook!, storedFile.path);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Added "${savedBook.title}" to library',
                                  ),
                                  backgroundColor: successColor,
                                ),
                              );

                              context.go('/');
                            } catch (error) {
                              if (!mounted) return;
                              setState(() {
                                _errorMessage =
                                    'Failed to save the book. Try again.';
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Save failed: $error',
                                  ),
                                  backgroundColor: colorScheme.error,
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isLoading = false);
                              }
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

class _PublicBookCard extends StatelessWidget {
  final PublicBook book;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final bool isDownloading;
  final double? downloadProgress;

  const _PublicBookCard({
    required this.book,
    required this.onTap,
    required this.onDownload,
    required this.onCancel,
    required this.isDownloading,
    required this.downloadProgress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final glassBackground = extras?.glassBackground ?? colorScheme.surface;
    final glassBorder = extras?.glassBorder ?? colorScheme.outlineVariant;
    final glassShadow =
        extras?.glassShadow ?? Theme.of(context).shadowColor.withAlpha(20);
    final accent = extras?.accentPalette.first ?? colorScheme.primary;

    return Pressable(
      onTap: onTap,
      pressedOpacity: 0.96,
      pressedScale: 0.98,
      haptic: PressableHaptic.selection,
      child: Container(
        decoration: BoxDecoration(
          color: glassBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: glassBorder),
          boxShadow: [
            BoxShadow(
              color: glassShadow,
              blurRadius: 16,
              offset: const Offset(0, 6),
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
                        ? const _CoverPlaceholder()
                        : Stack(
                            children: [
                              const Positioned.fill(
                                child: _CoverPlaceholder(),
                              ),
                              Positioned.fill(
                                child: _FadingNetworkImage(
                                  url: book.coverUrl!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(120),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 6,
                    child: Container(color: Colors.black.withAlpha(40)),
                  ),
                  Positioned(
                    left: 6,
                    top: 0,
                    bottom: 0,
                    width: 1,
                    child: Container(color: Colors.white.withAlpha(70)),
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
                  color: colorScheme.onSurface,
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
                  child: Pressable(
                    onTap: isDownloading ? onCancel : onDownload,
                    pressedOpacity: 0.9,
                    pressedScale: 0.98,
                    haptic: PressableHaptic.selection,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(isDownloading ? 8 : 14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withAlpha(150)),
                    ),
                    child: _DownloadLabel(
                      isDownloading: isDownloading,
                      progress: downloadProgress,
                      accent: accent,
                      textTheme: textTheme,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadLabel extends StatelessWidget {
  final bool isDownloading;
  final double? progress;
  final Color accent;
  final TextTheme textTheme;

  const _DownloadLabel({
    required this.isDownloading,
    required this.progress,
    required this.accent,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final progressValue =
        progress == null ? null : progress!.clamp(0.0, 1.0);
    final progressPercent = progressValue == null
        ? null
        : (progressValue * 100).round();
    final label = isDownloading
        ? (progressPercent != null
            ? 'Cancel ($progressPercent%)'
            : 'Cancel Download')
        : 'Download EPUB';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isDownloading && progressPercent == null) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              textAlign: TextAlign.center,
              style: textTheme.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (isDownloading && progressValue != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 4,
              backgroundColor: accent.withAlpha(40),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ],
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

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

class _FadingNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const _FadingNetworkImage({
    required this.url,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const SizedBox.shrink();
      },
    );
  }
}

class _PublicBookDetailsSheet extends ConsumerStatefulWidget {
  final PublicBook book;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final bool isDownloading;

  const _PublicBookDetailsSheet({
    required this.book,
    required this.onDownload,
    required this.onCancel,
    required this.isDownloading,
  });

  @override
  ConsumerState<_PublicBookDetailsSheet> createState() =>
      _PublicBookDetailsSheetState();
}

class _PublicBookDetailsSheetState
    extends ConsumerState<_PublicBookDetailsSheet> {
  late final Future<OpenLibraryWork?> _workFuture;

  @override
  void initState() {
    super.initState();
    _workFuture = ref
        .read(openLibraryServiceProvider)
        .fetchWorkDetails(widget.book.key);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final glassBackground = extras?.glassBackground ?? colorScheme.surface;
    final glassBorder = extras?.glassBorder ?? colorScheme.outlineVariant;
    final glassShadow =
        extras?.glassShadow ?? Theme.of(context).shadowColor.withAlpha(25);
    final accent = extras?.accentPalette.first ?? colorScheme.primary;
    final debugEnabled = ref.watch(debugModeProvider);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Material(
              color: Colors.transparent,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: glassBackground,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: glassBorder),
                        boxShadow: [
                          BoxShadow(
                            color: glassShadow,
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Book details',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Pressable(
                                  onTap: () => Navigator.of(context).pop(),
                                  pressedOpacity: 0.85,
                                  pressedScale: 0.96,
                                  haptic: PressableHaptic.selection,
                                  child: Icon(
                                    LucideIcons.x,
                                    size: 20,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 96,
                                  height: 136,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: colorScheme.surfaceVariant,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: widget.book.coverUrl == null
                                      ? const _CoverPlaceholder()
                                      : _FadingNetworkImage(
                                          url: widget.book.coverUrl!,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.book.title,
                                        style: textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        widget.book.primaryAuthor,
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _MetadataChip(
                                            label: widget.book.yearLabel,
                                          ),
                                          const _MetadataChip(
                                            label: 'Public Domain',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            FutureBuilder<OpenLibraryWork?>(
                              future: _workFuture,
                              builder: (context, snapshot) {
                                final work = snapshot.data;
                                final description = work?.description;
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'About this book',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting)
                                      Text(
                                        'Loading details...',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color:
                                              colorScheme.onSurfaceVariant,
                                        ),
                                      )
                                    else if (description == null ||
                                        description.isEmpty)
                                      Text(
                                        'No description available yet.',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color:
                                              colorScheme.onSurfaceVariant,
                                        ),
                                      )
                                    else
                                      Text(
                                        description,
                                        style: textTheme.bodyMedium?.copyWith(
                                          color:
                                              colorScheme.onSurfaceVariant,
                                          height: 1.4,
                                        ),
                                      ),
                                    if (work != null &&
                                        work.subjects.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: work.subjects
                                            .take(8)
                                            .map((subject) => _MetadataChip(
                                                  label: subject,
                                                ))
                                            .toList(),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            if (debugEnabled) ...[
                              Text(
                                'Download link (debug)',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      colorScheme.surfaceVariant.withAlpha(160),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                                child: SelectableText(
                                  widget.book.epubUrl,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Pressable(
                              onTap: widget.isDownloading
                                  ? widget.onCancel
                                  : widget.onDownload,
                              pressedOpacity: 0.92,
                              pressedScale: 0.98,
                              haptic: PressableHaptic.medium,
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: widget.isDownloading
                                      ? accent.withAlpha(120)
                                      : accent,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withAlpha(60),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (widget.isDownloading) ...[
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.onPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    Text(
                                      widget.isDownloading
                                          ? 'Cancel Download'
                                          : 'Download EPUB',
                                      textAlign: TextAlign.center,
                                      style: textTheme.labelLarge?.copyWith(
                                        color: colorScheme.onPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final String label;

  const _MetadataChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withAlpha(180),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _StaggeredFadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  const _StaggeredFadeIn({
    required this.child,
    required this.delay,
    this.duration = const Duration(milliseconds: 220),
    this.offset = const Offset(0, 0.04),
  });

  @override
  State<_StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<_StaggeredFadeIn> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: widget.duration,
      curve: Curves.easeInOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : widget.offset,
        duration: widget.duration,
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}

class _CreateBackdrop extends StatelessWidget {
  const _CreateBackdrop();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<AppThemeExtras>();
    final palette = extras?.accentPalette ??
        const [
          AppColors.rose600,
          AppColors.amber600,
          AppColors.blue600,
          AppColors.emerald600,
        ];

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: colorScheme.background),
        ),
        Positioned(
          top: -140,
          right: -80,
          child: _GlowOrb(
            size: 260,
            color: palette[1].withAlpha(50),
          ),
        ),
        Positioned(
          bottom: -160,
          left: -80,
          child: _GlowOrb(
            size: 280,
            color: palette[3].withAlpha(40),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface.withAlpha(50),
                colorScheme.background.withAlpha(240),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

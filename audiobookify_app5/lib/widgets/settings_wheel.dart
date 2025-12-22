import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../core/app_theme.dart';
import '../core/providers.dart';
import '../models/backdrop_image.dart';
import '../models/player_settings.dart';
import '../models/player_theme_settings.dart';
import '../widgets/shared/pressable.dart';

/// Audio settings modal with interactive sliders for speed and pitch
class SettingsWheel extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const SettingsWheel({super.key, required this.onClose});

  @override
  ConsumerState<SettingsWheel> createState() => _SettingsWheelState();
}

FontWeight _resolveFontWeight(int weight) {
  final normalized = ((weight / 100).round() * 100).clamp(100, 900);
  switch (normalized) {
    case 100:
      return FontWeight.w100;
    case 200:
      return FontWeight.w200;
    case 300:
      return FontWeight.w300;
    case 400:
      return FontWeight.w400;
    case 500:
      return FontWeight.w500;
    case 600:
      return FontWeight.w600;
    case 700:
      return FontWeight.w700;
    case 800:
      return FontWeight.w800;
    case 900:
      return FontWeight.w900;
  }
  return FontWeight.w400;
}

void _setStateSafely(State state, VoidCallback update) {
  if (!state.mounted) return;
  final phase = SchedulerBinding.instance.schedulerPhase;
  if (phase == SchedulerPhase.persistentCallbacks ||
      phase == SchedulerPhase.midFrameMicrotasks) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!state.mounted) return;
      state.setState(update);
    });
    return;
  }
  state.setState(update);
}

class _SettingsWheelState extends ConsumerState<SettingsWheel> {
  String? _activeSliderId;
  bool _isSliderDragging = false;

  void _handleSliderDragStart(String sliderId) {
    if (_activeSliderId == sliderId && _isSliderDragging) return;
    _setStateSafely(this, () {
      _activeSliderId = sliderId;
      _isSliderDragging = true;
    });
  }

  void _handleSliderDragEnd(String sliderId) {
    if (!_isSliderDragging) return;
    _setStateSafely(this, () {
      _isSliderDragging = false;
      _activeSliderId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
    final modalHeight =
        (MediaQuery.of(context).size.height * 0.82).clamp(0.0, 620.0);

    return GestureDetector(
      onTap: widget.onClose,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        color:
            colorScheme.scrim.withAlpha(_isSliderDragging ? 0 : 120),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent tap-through
            child: DefaultTabController(
              length: 2,
              child: SizedBox(
                width: 340,
                height: modalHeight.toDouble(),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FadeOnSliderDrag(
                        isDragging: _isSliderDragging,
                        activeSliderId: _activeSliderId,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).shadowColor.withAlpha(
                                      _isSliderDragging ? 204 : 50,
                                    ),
                                blurRadius: _isSliderDragging ? 20 : 40,
                                offset: Offset(
                                  0,
                                  _isSliderDragging ? 18 : 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
                        child: Column(
                          children: [
                    // Header
                    FadeOnSliderDrag(
                      isDragging: _isSliderDragging,
                      activeSliderId: _activeSliderId,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Settings',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onClose,
                            child: Icon(
                              LucideIcons.x,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeOnSliderDrag(
                      isDragging: _isSliderDragging,
                      activeSliderId: _activeSliderId,
                      child: TabBar(
                        labelColor: colorScheme.onSurface,
                        unselectedLabelColor: colorScheme.onSurfaceVariant,
                        indicatorColor: colorScheme.primary,
                        tabs: const [
                          Tab(text: 'Speech'),
                          Tab(text: 'Visual'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const tabGutter = 24.0;
                          const shadowInset = 6.0;
                          return ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.center,
                              maxWidth: constraints.maxWidth + tabGutter,
                              child: SizedBox(
                                width: constraints.maxWidth + tabGutter,
                                child: TabBarView(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: tabGutter / 2 + shadowInset,
                                      ),
                                      child: _AudioSettingsTab(
                                        isDragging: _isSliderDragging,
                                        activeSliderId: _activeSliderId,
                                        onSliderDragStart:
                                            _handleSliderDragStart,
                                        onSliderDragEnd: _handleSliderDragEnd,
                                        accentPalette: accentPalette,
                                        accentSoftPalette: accentSoftPalette,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: tabGutter / 2 + shadowInset,
                                      ),
                                      child: _ReaderSettingsTab(
                                        isDragging: _isSliderDragging,
                                        activeSliderId: _activeSliderId,
                                        onSliderDragStart:
                                            _handleSliderDragStart,
                                        onSliderDragEnd: _handleSliderDragEnd,
                                        accentPalette: accentPalette,
                                        accentSoftPalette: accentSoftPalette,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
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
    );
  }
}

class _AudioSettingsTab extends ConsumerStatefulWidget {
  final bool isDragging;
  final String? activeSliderId;
  final ValueChanged<String> onSliderDragStart;
  final ValueChanged<String> onSliderDragEnd;
  final List<Color> accentPalette;
  final List<Color> accentSoftPalette;

  const _AudioSettingsTab({
    required this.isDragging,
    required this.activeSliderId,
    required this.onSliderDragStart,
    required this.onSliderDragEnd,
    required this.accentPalette,
    required this.accentSoftPalette,
  });

  @override
  ConsumerState<_AudioSettingsTab> createState() => _AudioSettingsTabState();
}

class _AudioSettingsTabState extends ConsumerState<_AudioSettingsTab> {
  late double _speedValue;
  late double _pitchValue;
  bool _editingSpeed = false;
  bool _editingPitch = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(playerSettingsProvider);
    _speedValue = settings.speed;
    _pitchValue = settings.pitch;
  }

  void _syncFromSettings(PlayerSettings settings) {
    if (!_editingSpeed && settings.speed != _speedValue) {
      _setStateSafely(this, () => _speedValue = settings.speed);
    }
    if (!_editingPitch && settings.pitch != _pitchValue) {
      _setStateSafely(this, () => _pitchValue = settings.pitch);
    }
  }

  void _scheduleProviderUpdate(VoidCallback update) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => update());
      return;
    }
    update();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(playerSettingsProvider);
    ref.listen<PlayerSettings>(playerSettingsProvider, (previous, next) {
      _syncFromSettings(next);
    });
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accentPalette = widget.accentPalette;
    final accentSoftPalette = widget.accentSoftPalette;
    final onSliderDragStart = widget.onSliderDragStart;
    final onSliderDragEnd = widget.onSliderDragEnd;
    Widget fade(Widget child, {String? sliderId}) {
      return FadeOnSliderDrag(
        isDragging: widget.isDragging,
        activeSliderId: widget.activeSliderId,
        sliderId: sliderId,
        child: child,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fade(_SettingsSectionTitle(title: 'Playback')),
          const SizedBox(height: 12),
          // Audio sliders intentionally do not toggle the modal fade/scrim.
          // We leave onSliderDragStart/End unset so _isSliderDragging stays false.
          fade(
            _SettingSlider(
              icon: LucideIcons.gauge,
              label: 'Speed',
              value: _speedValue,
              min: 0.5,
              max: 2.0,
              displayValue: '${_speedValue.toStringAsFixed(1)}x',
              bgColor: accentSoftPalette[0],
              fgColor: accentPalette[0],
              onChanged: (value) {
                if (!mounted) return;
                setState(() => _speedValue = value);
              },
              onChangeStart: (_) {
                _editingSpeed = true;
              },
              onChangeEnd: (_) {
                _editingSpeed = false;
                final notifier = ref.read(playerSettingsProvider.notifier);
                _scheduleProviderUpdate(
                  () => notifier.setSpeed(_speedValue),
                );
              },
            ),
            sliderId: 'audio_speed',
          ),
          const SizedBox(height: 16),
          fade(
            _SettingSlider(
              icon: LucideIcons.music,
              label: 'Pitch',
              value: _pitchValue,
              min: 0.5,
              max: 2.0,
              displayValue: _pitchValue.toStringAsFixed(1),
              bgColor: accentSoftPalette[1],
              fgColor: accentPalette[1],
              onChanged: (value) {
                if (!mounted) return;
                setState(() => _pitchValue = value);
              },
              onChangeStart: (_) {
                _editingPitch = true;
              },
              onChangeEnd: (_) {
                _editingPitch = false;
                final notifier = ref.read(playerSettingsProvider.notifier);
                _scheduleProviderUpdate(
                  () => notifier.setPitch(_pitchValue),
                );
              },
            ),
            sliderId: 'audio_pitch',
          ),
          const SizedBox(height: 20),
          fade(_SettingsSectionTitle(title: 'Voice')),
          const SizedBox(height: 12),
          fade(
            Row(
              children: [
                Expanded(
                  child: _SettingCard(
                    icon: LucideIcons.mic2,
                    label: 'Style',
                    value: settings.voiceName?.split('.').last ?? 'Default',
                    bgColor: accentSoftPalette[2],
                    fgColor: accentPalette[2],
                    onTap: () => _showVoiceSelector(context, ref),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SettingCard(
                    icon: LucideIcons.languages,
                    label: 'Accent',
                    value: 'British',
                    bgColor: accentSoftPalette[3],
                    fgColor: accentPalette[3],
                    onTap: () {}, // No-op
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          fade(
            Center(
              child: TextButton(
                onPressed: () {
                  ref.read(playerSettingsProvider.notifier).reset();
                },
                child: Text(
                  'Reset Audio Defaults',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          fade(
            Center(
              child: SizedBox(
                width: 64,
                height: 64,
                child: CustomPaint(
                  painter: _WheelPainter(
                    colors: accentPalette,
                    borderColor: colorScheme.outlineVariant,
                  ),
                  child: Center(
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderSettingsTab extends ConsumerStatefulWidget {
  final bool isDragging;
  final String? activeSliderId;
  final ValueChanged<String> onSliderDragStart;
  final ValueChanged<String> onSliderDragEnd;
  final List<Color> accentPalette;
  final List<Color> accentSoftPalette;

  const _ReaderSettingsTab({
    required this.isDragging,
    required this.activeSliderId,
    required this.onSliderDragStart,
    required this.onSliderDragEnd,
    required this.accentPalette,
    required this.accentSoftPalette,
  });

  @override
  ConsumerState<_ReaderSettingsTab> createState() =>
      _ReaderSettingsTabState();
}

class _ReaderSettingsTabState extends ConsumerState<_ReaderSettingsTab> {
  Timer? _backdropPeekTimer;
  static const int _maxBackdropFileSizeBytes = 15 * 1024 * 1024;
  static const int _thumbnailTargetWidth = 220;
  static const Duration _thumbnailFetchTimeout = Duration(seconds: 8);
  final Map<String, Future<File?>> _thumbnailFutures = {};

  @override
  void dispose() {
    _backdropPeekTimer?.cancel();
    super.dispose();
  }

  void _triggerBackdropPeek() {
    _backdropPeekTimer?.cancel();
    widget.onSliderDragStart('backdrop_gallery');
    _backdropPeekTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      widget.onSliderDragEnd('backdrop_gallery');
    });
  }

  void _startBackdropHold() {
    _backdropPeekTimer?.cancel();
    widget.onSliderDragStart('backdrop_gallery');
  }

  void _endBackdropHold() {
    widget.onSliderDragEnd('backdrop_gallery');
  }

  void _setBackdropSelection(String id) {
    ref.read(backdropSettingsProvider.notifier).setBackdropId(id);
  }

  void _setBrightness(double value) {
    ref.read(backdropSettingsProvider.notifier).setBrightness(value);
  }

  Future<File?> _thumbnailFutureFor(BackdropImage image) {
    return _thumbnailFutures.putIfAbsent(
      image.id,
      () => _ensureThumbnail(image),
    );
  }

  Future<File?> _ensureThumbnail(BackdropImage image) async {
    final directory = await _thumbnailDirectory();
    final file = File('${directory.path}/${image.id}.png');
    if (await file.exists()) return file;

    final sourceBytes = await _loadImageBytes(image);
    if (sourceBytes == null) return null;

    final thumbnailBytes =
        await _createThumbnailBytes(sourceBytes, _thumbnailTargetWidth);
    if (thumbnailBytes == null) return null;

    await file.writeAsBytes(thumbnailBytes, flush: true);
    return file;
  }

  Future<Uint8List?> _loadImageBytes(BackdropImage image) async {
    try {
      final uri = image.uri.trim();
      if (uri.isEmpty) return null;
      if (image.sourceType == BackdropSourceType.upload) {
        final file = File(uri);
        if (!await file.exists()) return null;
        return await file.readAsBytes();
      }
      if (uri.startsWith('http://') || uri.startsWith('https://')) {
        final response = await http
            .get(Uri.parse(uri))
            .timeout(_thumbnailFetchTimeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response.bodyBytes;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<Uint8List?> _createThumbnailBytes(
    Uint8List bytes,
    int targetWidth,
  ) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image
          .toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _thumbnailDirectory() async {
    final baseDir = await getApplicationSupportDirectory();
    final dir = Directory('${baseDir.path}/backdrops/thumbnails');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _handleUploadTap() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      if (picked.size > _maxBackdropFileSizeBytes) {
        if (!mounted) return;
        _showBackdropMessage(
          context,
          'Image is too large. Please pick one under 15 MB.',
        );
        return;
      }

      final sourcePath = picked.path;
      if (sourcePath == null || sourcePath.trim().isEmpty) {
        if (!mounted) return;
        _showBackdropMessage(context, 'Unable to read the image.');
        return;
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        if (!mounted) return;
        _showBackdropMessage(context, 'Image file not found.');
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final backdropDir = Directory('${appDir.path}/backdrops');
      if (!await backdropDir.exists()) {
        await backdropDir.create(recursive: true);
      }

      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final extension = _resolveFileExtension(sourcePath);
      final destPath = '${backdropDir.path}/$id$extension';
      await sourceFile.copy(destPath);

      final image = BackdropImage(
        id: id,
        sourceType: BackdropSourceType.upload,
        uri: destPath,
      );

      if (!mounted) return;
      ref.read(backdropLibraryProvider.notifier).addImage(image);
      _thumbnailFutureFor(image);
      _setBackdropSelection(image.id);
      _triggerBackdropPeek();
    } catch (_) {
      if (!mounted) return;
      _showBackdropMessage(context, 'Upload failed. Try again.');
    }
  }

  String _resolveFileExtension(String path) {
    final separator = Platform.pathSeparator;
    final lastSeparator = path.lastIndexOf(separator);
    final lastDot = path.lastIndexOf('.');
    if (lastDot > lastSeparator) {
      return path.substring(lastDot);
    }
    return '.jpg';
  }

  void _showBackdropMessage(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  BackdropImage? _findBackdrop(List<BackdropImage> images, String id) {
    for (final image in images) {
      if (image.id == id) return image;
    }
    return null;
  }

  Widget _buildBackdropPreview(BackdropImage image) {
    return FutureBuilder<File?>(
      future: _thumbnailFutureFor(image),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          );
        }
        return _buildBackdropPreviewFallback(image);
      },
    );
  }

  Widget _buildBackdropPreviewFallback(BackdropImage image) {
    final uri = image.uri.trim();
    if (uri.isEmpty) {
      return const _BackdropImageFallback();
    }
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      return Image.network(
        uri,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (_, __, ___) => const _BackdropImageFallback(),
      );
    }
    if (uri.startsWith('assets/') || uri.startsWith('packages/')) {
      return Image.asset(
        uri,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (_, __, ___) => const _BackdropImageFallback(),
      );
    }
    if (image.sourceType == BackdropSourceType.upload) {
      return Image.file(
        File(uri),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (_, __, ___) => const _BackdropImageFallback(),
      );
    }
    return const _BackdropImageFallback();
  }

  @override
  Widget build(BuildContext context) {
    final readerTheme = ref.watch(playerThemeProvider);
    final backdropSettings = ref.watch(backdropSettingsProvider);
    final backdrops = ref.watch(backdropLibraryProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accentPalette = widget.accentPalette;
    final accentSoftPalette = widget.accentSoftPalette;
    final onSliderDragStart = widget.onSliderDragStart;
    final onSliderDragEnd = widget.onSliderDragEnd;
    Widget fade(Widget child, {String? sliderId}) {
      return FadeOnSliderDrag(
        isDragging: widget.isDragging,
        activeSliderId: widget.activeSliderId,
        sliderId: sliderId,
        child: child,
      );
    }

    void updateTheme(PlayerThemeSettings settings) {
      ref.read(playerThemeProvider.notifier).setTheme(settings);
    }

    final selectedBackdrop =
        _findBackdrop(backdrops, backdropSettings.id);
    final selectedMetadata =
        BackdropImage.decodeMetadata(selectedBackdrop?.metadata);
    final selectedAuthor = selectedMetadata['author'];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fade(_SettingsSectionTitle(title: 'Presets')),
          const SizedBox(height: 10),
          fade(
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PresetChip(
                  label: 'Ambient',
                  onTap: () => updateTheme(_ambientPreset(readerTheme)),
                ),
                _PresetChip(
                  label: 'Focus',
                  onTap: () => updateTheme(_focusPreset(readerTheme)),
                ),
                _PresetChip(
                  label: 'Paper',
                  onTap: () => updateTheme(_paperPreset(readerTheme)),
                ),
                _PresetChip(
                  label: 'Modern',
                  onTap: () => updateTheme(_modernPreset(readerTheme)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          fade(_SettingsSectionTitle(title: 'Typography')),
          const SizedBox(height: 12),
          fade(
            _FontFamilyPicker(
              value: readerTheme.fontFamily,
              fontWeight: readerTheme.fontWeight,
              onChanged: (value) {
                updateTheme(readerTheme.copyWith(fontFamily: value));
              },
            ),
          ),
          const SizedBox(height: 12),
          fade(
            _SettingSlider(
              icon: LucideIcons.type,
              label: 'Font Size',
              value: readerTheme.fontSize,
              min: 14,
              max: 26,
              displayValue: readerTheme.fontSize.toStringAsFixed(0),
              bgColor: accentSoftPalette[0],
              fgColor: accentPalette[0],
              onChanged: (value) {
                updateTheme(readerTheme.copyWith(fontSize: value));
              },
              onChangeStart: (_) => onSliderDragStart('reader_font_size'),
              onChangeEnd: (_) => onSliderDragEnd('reader_font_size'),
            ),
            sliderId: 'reader_font_size',
          ),
          const SizedBox(height: 12),
          fade(
            _SettingSlider(
              icon: LucideIcons.alignJustify,
              label: 'Line Height',
              value: readerTheme.lineHeight,
              min: 1.3,
              max: 2.2,
              displayValue: readerTheme.lineHeight.toStringAsFixed(2),
              bgColor: accentSoftPalette[1],
              fgColor: accentPalette[1],
              onChanged: (value) {
                updateTheme(readerTheme.copyWith(lineHeight: value));
              },
              onChangeStart: (_) => onSliderDragStart('reader_line_height'),
              onChangeEnd: (_) => onSliderDragEnd('reader_line_height'),
            ),
            sliderId: 'reader_line_height',
          ),
          const SizedBox(height: 12),
          fade(
            _SettingSlider(
              icon: LucideIcons.bold,
              label: 'Font Weight',
              value: readerTheme.fontWeight.clamp(300, 700).toDouble(),
              min: 300,
              max: 700,
              divisions: 4,
              displayValue: _fontWeightLabel(readerTheme.fontWeight),
              bgColor: accentSoftPalette[2],
              fgColor: accentPalette[2],
              onChanged: (value) {
                updateTheme(readerTheme.copyWith(fontWeight: value.round()));
              },
              onChangeStart: (_) => onSliderDragStart('reader_font_weight'),
              onChangeEnd: (_) => onSliderDragEnd('reader_font_weight'),
            ),
            sliderId: 'reader_font_weight',
          ),
          const SizedBox(height: 16),
          fade(_SettingsSectionTitle(title: 'Layout')),
          const SizedBox(height: 12),
          fade(
            _SettingSlider(
              icon: LucideIcons.rows,
              label: 'Paragraph Spacing',
              value: readerTheme.paragraphSpacing,
              min: 0,
              max: 16,
              displayValue: readerTheme.paragraphSpacing.toStringAsFixed(0),
              bgColor: accentSoftPalette[2],
              fgColor: accentPalette[2],
              onChanged: (value) {
                updateTheme(readerTheme.copyWith(paragraphSpacing: value));
              },
              onChangeStart: (_) =>
                  onSliderDragStart('reader_paragraph_spacing'),
              onChangeEnd: (_) => onSliderDragEnd('reader_paragraph_spacing'),
            ),
            sliderId: 'reader_paragraph_spacing',
          ),
          const SizedBox(height: 12),
          fade(
            _SettingSlider(
              icon: LucideIcons.indent,
              label: 'Paragraph Indent',
              value: readerTheme.paragraphIndent,
              min: 0,
              max: 28,
              displayValue: readerTheme.paragraphIndent.toStringAsFixed(0),
              bgColor: accentSoftPalette[3],
              fgColor: accentPalette[3],
              onChanged: (value) {
                updateTheme(readerTheme.copyWith(paragraphIndent: value));
              },
              onChangeStart: (_) =>
                  onSliderDragStart('reader_paragraph_indent'),
              onChangeEnd: (_) => onSliderDragEnd('reader_paragraph_indent'),
            ),
            sliderId: 'reader_paragraph_indent',
          ),
          const SizedBox(height: 12),
          fade(
            _SettingSlider(
              icon: LucideIcons.arrowLeftRight,
              label: 'Page Padding (H)',
              value: readerTheme.pagePaddingHorizontal,
              min: 12,
              max: 48,
              displayValue: readerTheme.pagePaddingHorizontal.toStringAsFixed(0),
              bgColor: accentSoftPalette[0],
              fgColor: accentPalette[0],
              onChanged: (value) {
                updateTheme(readerTheme.copyWith(pagePaddingHorizontal: value));
              },
              onChangeStart: (_) => onSliderDragStart('reader_padding_horizontal'),
              onChangeEnd: (_) => onSliderDragEnd('reader_padding_horizontal'),
            ),
            sliderId: 'reader_padding_horizontal',
          ),
          const SizedBox(height: 12),
          fade(
            _SettingSlider(
              icon: LucideIcons.arrowUpDown,
              label: 'Page Padding (V)',
              value: readerTheme.pagePaddingVertical,
              min: 8,
              max: 32,
              displayValue: readerTheme.pagePaddingVertical.toStringAsFixed(0),
              bgColor: accentSoftPalette[1],
              fgColor: accentPalette[1],
              onChanged: (value) {
                updateTheme(readerTheme.copyWith(pagePaddingVertical: value));
              },
              onChangeStart: (_) => onSliderDragStart('reader_padding_vertical'),
              onChangeEnd: (_) => onSliderDragEnd('reader_padding_vertical'),
            ),
            sliderId: 'reader_padding_vertical',
          ),
          const SizedBox(height: 16),
          fade(_SettingsSectionTitle(title: 'Paragraph Highlight')),
          const SizedBox(height: 10),
          fade(
            _ChoiceChipGroup<PlayerThemeActiveParagraphStyle>(
              value: readerTheme.activeParagraphStyle,
              onChanged: (value) {
                updateTheme(readerTheme.copyWith(activeParagraphStyle: value));
              },
              options: const [
                _ChoiceOption(
                  label: 'Highlight',
                  value: PlayerThemeActiveParagraphStyle.highlight,
                ),
                _ChoiceOption(
                  label: 'Highlight + Bar',
                  value: PlayerThemeActiveParagraphStyle.highlightBar,
                ),
                _ChoiceOption(
                  label: 'Underline',
                  value: PlayerThemeActiveParagraphStyle.underline,
                ),
                _ChoiceOption(
                  label: 'Left Bar',
                  value: PlayerThemeActiveParagraphStyle.leftBar,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          fade(
            _SettingSlider(
              icon: LucideIcons.highlighter,
              label: 'Highlight Opacity',
              value: readerTheme.activeParagraphOpacity,
              min: 0.05,
              max: 0.4,
              displayValue:
                  readerTheme.activeParagraphOpacity.toStringAsFixed(2),
              bgColor: accentSoftPalette[2],
              fgColor: accentPalette[2],
              onChanged: (value) {
                updateTheme(readerTheme.copyWith(activeParagraphOpacity: value));
              },
              onChangeStart: (_) =>
                  onSliderDragStart('reader_highlight_opacity'),
              onChangeEnd: (_) => onSliderDragEnd('reader_highlight_opacity'),
            ),
            sliderId: 'reader_highlight_opacity',
          ),
          const SizedBox(height: 16),
          fade(_SettingsSectionTitle(title: 'Sentence Highlight')),
          const SizedBox(height: 10),
          fade(
            _ChoiceChipGroup<PlayerThemeSentenceHighlightStyle>(
              value: readerTheme.sentenceHighlightStyle,
              onChanged: (value) {
                updateTheme(
                  readerTheme.copyWith(sentenceHighlightStyle: value),
                );
              },
              options: const [
                _ChoiceOption(
                  label: 'Background',
                  value: PlayerThemeSentenceHighlightStyle.background,
                ),
                _ChoiceOption(
                  label: 'Underline',
                  value: PlayerThemeSentenceHighlightStyle.underline,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          fade(_SettingsSectionTitle(title: 'Background')),
          const SizedBox(height: 10),
          fade(
            _ChoiceChipGroup<PlayerThemeBackgroundMode>(
              value: readerTheme.backgroundMode,
              onChanged: (value) {
                updateTheme(readerTheme.copyWith(backgroundMode: value));
              },
              options: const [
                _ChoiceOption(
                  label: 'Cover',
                  value: PlayerThemeBackgroundMode.coverAmbient,
                ),
                _ChoiceOption(
                  label: 'Gradient',
                  value: PlayerThemeBackgroundMode.gradient,
                ),
                _ChoiceOption(
                  label: 'Solid',
                  value: PlayerThemeBackgroundMode.solid,
                ),
                _ChoiceOption(
                  label: 'Image',
                  value: PlayerThemeBackgroundMode.customImage,
                ),
              ],
            ),
          ),
          if (readerTheme.backgroundMode ==
              PlayerThemeBackgroundMode.customImage) ...[
            const SizedBox(height: 12),
            fade(
              Text(
                'Choose a backdrop',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            fade(
              SizedBox(
                height: 128,
                child: Builder(builder: (context) {
                  const showUnsplashButton = false; // Don't delete.
                  return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: backdrops.length + 1 + (showUnsplashButton ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    if (index < backdrops.length) {
                      final image = backdrops[index];
                      final selected = image.id == backdropSettings.id;
                      return _BackdropTile(
                        selected: selected,
                        child: _buildBackdropPreview(image),
                        onTap: () {
                          _setBackdropSelection(image.id);
                          _triggerBackdropPeek();
                        },
                        onLongPressStart: () {
                          _setBackdropSelection(image.id);
                          _startBackdropHold();
                        },
                        onLongPressEnd: _endBackdropHold,
                      );
                    }
                    final unsplashIndex = backdrops.length;
                    final uploadIndex =
                        backdrops.length + (showUnsplashButton ? 1 : 0);
                    if (showUnsplashButton && index == unsplashIndex) {
                      return _BackdropAddTile(
                        label: 'Unsplash',
                        icon: LucideIcons.search,
                        onTap: () {
                          _showBackdropMessage(
                            context,
                            'Unsplash search coming soon.',
                          );
                        },
                      );
                    }
                    if (index == uploadIndex) {
                      return _BackdropAddTile(
                        label: 'Upload',
                        icon: LucideIcons.upload,
                        onTap: _handleUploadTap,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                );
                }),
              ),
              sliderId: 'backdrop_gallery',
            ),
            const SizedBox(height: 12),
            fade(
              _SettingSlider(
                icon: LucideIcons.sun,
                label: 'Brightness',
                value: backdropSettings.brightness,
                min: -1,
                max: 1,
                displayValue: backdropSettings.brightness.toStringAsFixed(2),
                bgColor: accentSoftPalette[3],
                fgColor: accentPalette[3],
                onChanged: _setBrightness,
                onChangeStart: (_) =>
                    widget.onSliderDragStart('backdrop_brightness'),
                onChangeEnd: (_) =>
                    widget.onSliderDragEnd('backdrop_brightness'),
              ),
              sliderId: 'backdrop_brightness',
            ),
            const SizedBox(height: 8),
            fade(
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PresetChip(
                    label: 'Dim',
                    onTap: () => _setBrightness(-0.25),
                  ),
                  _PresetChip(
                    label: 'Neutral',
                    onTap: () => _setBrightness(0.0),
                  ),
                  _PresetChip(
                    label: 'Bright',
                    onTap: () => _setBrightness(0.25),
                  ),
                ],
              ),
            ),
            if (selectedBackdrop != null &&
                selectedBackdrop.sourceType ==
                    BackdropSourceType.unsplash &&
                selectedAuthor != null) ...[
              const SizedBox(height: 8),
              fade(
                Text(
                  'Photo by $selectedAuthor on Unsplash',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          fade(
            _SettingSlider(
              icon: LucideIcons.slidersHorizontal,
              label: 'Background Blur',
              value: readerTheme.backgroundBlur,
              min: 0,
              max: 40,
              displayValue: readerTheme.backgroundBlur.toStringAsFixed(0),
              bgColor: accentSoftPalette[3],
              fgColor: accentPalette[3],
              onChanged: (value) {
                updateTheme(readerTheme.copyWith(backgroundBlur: value));
              },
              onChangeStart: (_) => onSliderDragStart('reader_background_blur'),
              onChangeEnd: (_) => onSliderDragEnd('reader_background_blur'),
            ),
            sliderId: 'reader_background_blur',
          ),
          const SizedBox(height: 12),
          fade(
            _SettingSlider(
              icon: LucideIcons.droplet,
              label: 'Background Opacity',
              value: readerTheme.backgroundOpacity,
              min: 0,
              max: 1,
              displayValue: readerTheme.backgroundOpacity.toStringAsFixed(2),
              bgColor: accentSoftPalette[0],
              fgColor: accentPalette[0],
              onChanged: (value) {
                updateTheme(readerTheme.copyWith(backgroundOpacity: value));
              },
              onChangeStart: (_) =>
                  onSliderDragStart('reader_background_opacity'),
              onChangeEnd: (_) => onSliderDragEnd('reader_background_opacity'),
            ),
            sliderId: 'reader_background_opacity',
          ),
          const SizedBox(height: 16),
          fade(_SettingsSectionTitle(title: 'Text Color')),
          const SizedBox(height: 10),
          fade(
            _ChoiceChipGroup<PlayerThemeTextColorMode>(
              value: readerTheme.textColorMode,
              onChanged: (value) {
                updateTheme(
                  readerTheme.copyWith(
                    textColorMode: value,
                    textColor: value == PlayerThemeTextColorMode.fixed
                        ? (readerTheme.textColor ?? colorScheme.onSurface)
                        : readerTheme.textColor,
                  ),
                );
              },
              options: const [
                _ChoiceOption(
                  label: 'Auto',
                  value: PlayerThemeTextColorMode.auto,
                ),
                _ChoiceOption(
                  label: 'Fixed',
                  value: PlayerThemeTextColorMode.fixed,
                ),
              ],
            ),
          ),
          if (readerTheme.textColorMode == PlayerThemeTextColorMode.fixed) ...[
            const SizedBox(height: 12),
            fade(
              _ColorSwatchRow(
                colors: [
                  colorScheme.onSurface,
                  colorScheme.onSurfaceVariant,
                  colorScheme.primary,
                  Colors.white,
                  Colors.black,
                ],
                selected: readerTheme.textColor,
                onChanged: (value) {
                  updateTheme(readerTheme.copyWith(textColor: value));
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          fade(
            Center(
              child: TextButton(
                onPressed: () {
                  ref.read(playerThemeProvider.notifier).reset();
                },
                child: Text(
                  'Reset Reader Defaults',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PlayerThemeSettings _ambientPreset(PlayerThemeSettings base) {
    return base.copyWith(
      fontFamily: 'Lora',
      fontSize: 18,
      fontWeight: 400,
      lineHeight: 1.8,
      paragraphSpacing: 4,
      paragraphIndent: 0,
      pagePaddingHorizontal: 28,
      pagePaddingVertical: 12,
      backgroundMode: PlayerThemeBackgroundMode.coverAmbient,
      backgroundImagePath: null,
      backgroundBlur: 20,
      backgroundOpacity: 0.5,
      activeParagraphStyle: PlayerThemeActiveParagraphStyle.highlightBar,
      activeParagraphOpacity: 0.12,
      textColorMode: PlayerThemeTextColorMode.auto,
      textColor: null,
      sentenceHighlightStyle: PlayerThemeSentenceHighlightStyle.background,
    );
  }

  PlayerThemeSettings _focusPreset(PlayerThemeSettings base) {
    return base.copyWith(
      fontFamily: base.fontFamily ?? 'Source Sans 3',
      fontSize: 17,
      fontWeight: 500,
      lineHeight: 1.65,
      paragraphSpacing: 2,
      pagePaddingHorizontal: 24,
      pagePaddingVertical: 10,
      backgroundMode: PlayerThemeBackgroundMode.gradient,
      backgroundBlur: 12,
      backgroundOpacity: 0.3,
      activeParagraphStyle: PlayerThemeActiveParagraphStyle.leftBar,
      activeParagraphOpacity: 0.2,
      textColorMode: PlayerThemeTextColorMode.auto,
      sentenceHighlightStyle: PlayerThemeSentenceHighlightStyle.background,
    );
  }

  PlayerThemeSettings _paperPreset(PlayerThemeSettings base) {
    return base.copyWith(
      fontFamily: 'Lora',
      fontSize: 18,
      fontWeight: 400,
      lineHeight: 1.75,
      paragraphSpacing: 6,
      pagePaddingHorizontal: 30,
      pagePaddingVertical: 14,
      backgroundMode: PlayerThemeBackgroundMode.solid,
      backgroundBlur: 0,
      backgroundOpacity: 0,
      activeParagraphStyle: PlayerThemeActiveParagraphStyle.underline,
      activeParagraphOpacity: 0.18,
      textColorMode: PlayerThemeTextColorMode.fixed,
      textColor: const Color(0xFF2C2A24),
      sentenceHighlightStyle: PlayerThemeSentenceHighlightStyle.underline,
    );
  }

  PlayerThemeSettings _modernPreset(PlayerThemeSettings base) {
    return base.copyWith(
      fontFamily: 'Inter',
      fontSize: 18,
      fontWeight: 500,
      lineHeight: 1.75,
      paragraphSpacing: 6,
      pagePaddingHorizontal: 30,
      pagePaddingVertical: 14,
      backgroundMode: PlayerThemeBackgroundMode.solid,
      backgroundBlur: 0,
      backgroundOpacity: 0,
      activeParagraphStyle: PlayerThemeActiveParagraphStyle.underline,
      activeParagraphOpacity: 0.18,
      textColorMode: PlayerThemeTextColorMode.fixed,
      textColor: const Color(0xFF2C2A24),
      sentenceHighlightStyle: PlayerThemeSentenceHighlightStyle.underline,
    );
  }


  String _fontWeightLabel(int weight) {
    final normalized = ((weight / 100).round() * 100).clamp(300, 700);
    switch (normalized) {
      case 300:
        return 'Light 300';
      case 400:
        return 'Regular 400';
      case 500:
        return 'Medium 500';
      case 600:
        return 'Semibold 600';
      case 700:
        return 'Bold 700';
    }
    return '$normalized';
  }
}

/// Interactive slider for a single setting
class _SettingSlider extends StatefulWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String displayValue;
  final Color bgColor;
  final Color fgColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;

  const _SettingSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.displayValue,
    required this.bgColor,
    required this.fgColor,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

  @override
  State<_SettingSlider> createState() => _SettingSliderState();
}

class _SettingSliderState extends State<_SettingSlider> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final step = _resolveStep();
    final canDecrease = widget.value > widget.min + 0.0001;
    final canIncrease = widget.value < widget.max - 0.0001;

    void updateByStep(int direction) {
      final target =
          (widget.value + step * direction).clamp(widget.min, widget.max);
      final snapped =
          widget.min + (((target - widget.min) / step).round()) * step;
      widget.onChanged(snapped.clamp(widget.min, widget.max).toDouble());
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.bgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context)
                .shadowColor
                .withAlpha(_isDragging ? 160 : 12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 20, color: widget.fgColor),
              const SizedBox(width: 14),
              Text(
                widget.label.toUpperCase(),
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                widget.displayValue,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          // const SizedBox(height: 4),
          Row(
            children: [
              _SliderStepButton(
                icon: LucideIcons.minus,
                enabled: canDecrease,
                onTap: () => updateByStep(-1),
                color: widget.fgColor,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: widget.fgColor,
                    inactiveTrackColor: widget.fgColor.withAlpha(50),
                    thumbColor: widget.fgColor,
                    overlayColor: widget.fgColor.withAlpha(30),
                    trackHeight: 2.5,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: widget.value,
                    min: widget.min,
                    max: widget.max,
                    divisions: widget.divisions,
                    onChanged: widget.onChanged,
                    onChangeStart: (value) {
                      setState(() => _isDragging = true);
                      widget.onChangeStart?.call(value);
                    },
                    onChangeEnd: (value) {
                      setState(() => _isDragging = false);
                      widget.onChangeEnd?.call(value);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _SliderStepButton(
                icon: LucideIcons.plus,
                enabled: canIncrease,
                onTap: () => updateByStep(1),
                color: widget.fgColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _resolveStep() {
    final range = (widget.max - widget.min).abs();
    if (widget.divisions != null && widget.divisions! > 0) {
      return range / widget.divisions!;
    }
    if (range <= 1) return 0.05;
    if (range <= 2) return 0.1;
    if (range <= 5) return 0.2;
    if (range <= 10) return 0.5;
    if (range <= 25) return 1;
    if (range <= 50) return 2;
    return 5;
  }
}

class _SliderStepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color color;

  const _SliderStepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 16, color: color),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        splashRadius: 18,
        tooltip: icon == LucideIcons.minus ? 'Decrease' : 'Increase',
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final String title;

  const _SettingsSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      title.toUpperCase(),
      style: textTheme.labelMedium?.copyWith(
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class FadeOnSliderDrag extends StatelessWidget {
  final bool isDragging;
  final String? activeSliderId;
  final String? sliderId;
  final Widget child;
  final Duration fadeOutDuration;
  final Duration fadeInDuration;
  final Curve curve;
  final bool disableWhenActiveAudio;

  const FadeOnSliderDrag({
    super.key,
    required this.isDragging,
    required this.activeSliderId,
    required this.child,
    this.sliderId,
    this.fadeOutDuration = const Duration(milliseconds: 220),
    this.fadeInDuration = const Duration(milliseconds: 120),
    this.curve = Curves.easeInOutCubic,
    this.disableWhenActiveAudio = true,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = sliderId != null && sliderId == activeSliderId;
    if (disableWhenActiveAudio &&
        activeSliderId != null &&
        activeSliderId!.startsWith('audio_')) {
      return child;
    }
    final shouldFade = isDragging && !isActive;
    final duration = shouldFade ? fadeOutDuration : fadeInDuration;
    return IgnorePointer(
      ignoring: shouldFade,
      child: AnimatedOpacity(
        opacity: shouldFade ? 0.0 : 1.0,
        duration: duration,
        curve: curve,
        child: child,
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: colorScheme.surfaceVariant.withAlpha(140),
      labelStyle: TextStyle(color: colorScheme.onSurface),
      shape: StadiumBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    );
  }
}

class _ChoiceOption<T> {
  final String label;
  final T value;

  const _ChoiceOption({required this.label, required this.value});
}

class _ChoiceChipGroup<T> extends StatelessWidget {
  final T value;
  final ValueChanged<T> onChanged;
  final List<_ChoiceOption<T>> options;

  const _ChoiceChipGroup({
    required this.value,
    required this.onChanged,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final selected = option.value == value;
        return ChoiceChip(
          label: Text(option.label),
          selected: selected,
          selectedColor: colorScheme.primary.withAlpha(32),
          labelStyle: TextStyle(
            color: selected ? colorScheme.primary : colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
          onSelected: (_) => onChanged(option.value),
        );
      }).toList(),
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  final List<Color> colors;
  final Color? selected;
  final ValueChanged<Color> onChanged;

  const _ColorSwatchRow({
    required this.colors,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((color) {
        final isSelected = selected?.value == color.value;
        return GestureDetector(
          onTap: () => onChanged(color),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? colorScheme.primary : Colors.white24,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: isSelected
                ? Icon(
                    LucideIcons.check,
                    size: 14,
                    color: colorScheme.primary,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _BackdropTile extends StatelessWidget {
  final bool selected;
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;

  const _BackdropTile({
    required this.selected,
    required this.child,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const width = 88.0;
    const height = 120.0;
    final borderColor =
        selected ? colorScheme.primary : colorScheme.outlineVariant;
    return GestureDetector(
      onLongPressStart: (_) => onLongPressStart(),
      onLongPressEnd: (_) => onLongPressEnd(),
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.97,
        haptic: PressableHaptic.selection,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: width,
          height: height,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                if (selected)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.check,
                        size: 12,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackdropAddTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _BackdropAddTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const width = 88.0;
    const height = 120.0;
    return Pressable(
      onTap: onTap,
      haptic: PressableHaptic.light,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withAlpha(140),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackdropImageFallback extends StatelessWidget {
  const _BackdropImageFallback();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceVariant.withAlpha(140),
      child: Center(
        child: Icon(
          LucideIcons.imageOff,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _FontFamilyPicker extends StatelessWidget {
  final String? value;
  final int fontWeight;
  final ValueChanged<String?> onChanged;

  const _FontFamilyPicker({
    required this.value,
    required this.fontWeight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const options = [
      _FontOption('System Default', null),
      _FontOption('Lora', 'Lora'),
      _FontOption('Literata', 'Literata'),
      _FontOption('Merriweather', 'Merriweather'),
      _FontOption('Source Serif 4', 'Source Serif 4'),
      _FontOption('Source Sans 3', 'Source Sans 3'),
      _FontOption('Inter', 'Inter'),
    ];
    final normalizedValue =
        (value == null || value!.trim().isEmpty) ? null : value;
    final selectedLabel = options
        .firstWhere(
          (option) => option.value == normalizedValue,
          orElse: () => const _FontOption('System Default', null),
        )
        .label;

    return Material(
      color: colorScheme.surfaceVariant.withAlpha(140),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          _showFontPicker(
            context,
            options: options,
            selected: normalizedValue,
            fontWeight: fontWeight,
            onChanged: onChanged,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Font Family',
                      style: textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.6,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedLabel,
                      style: _fontLabelStyle(
                        selectedLabel,
                        fontWeight: fontWeight,
                        textTheme: textTheme,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronsUpDown,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static TextStyle _fontLabelStyle(
    String? family, {
    required int fontWeight,
    required TextTheme textTheme,
    required Color color,
  }) {
    final baseStyle = textTheme.bodyMedium?.copyWith(
          fontWeight: _resolveFontWeight(fontWeight),
          color: color,
        ) ??
        TextStyle(fontWeight: _resolveFontWeight(fontWeight), color: color);
    if (family == null || family.trim().isEmpty || family == 'System Default') {
      return baseStyle;
    }
    try {
      return GoogleFonts.getFont(family, textStyle: baseStyle);
    } catch (_) {
      return baseStyle.copyWith(fontFamily: family);
    }
  }


  static void _showFontPicker(
    BuildContext context, {
    required List<_FontOption> options,
    required String? selected,
    required int fontWeight,
    required ValueChanged<String?> onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _FontPickerSheet(
          options: options,
          selected: selected,
          fontWeight: fontWeight,
          onChanged: onChanged,
        );
      },
    );
  }
}

class _FontPickerSheet extends StatelessWidget {
  final List<_FontOption> options;
  final String? selected;
  final int fontWeight;
  final ValueChanged<String?> onChanged;

  const _FontPickerSheet({
    required this.options,
    required this.selected,
    required this.fontWeight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Choose Font',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    LucideIcons.x,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => Divider(
                  color: colorScheme.outlineVariant,
                  height: 16,
                ),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option.value == selected;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      option.label,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'The quick brown fox jumps over the lazy dog.',
                      style: _previewStyle(
                        option.value,
                        textTheme,
                        colorScheme.onSurfaceVariant,
                        fontWeight,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            LucideIcons.check,
                            color: colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      onChanged(option.value);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _previewStyle(
    String? family,
    TextTheme textTheme,
    Color color,
    int fontWeight,
  ) {
    final baseStyle = textTheme.bodySmall?.copyWith(
          fontWeight: _resolveFontWeight(fontWeight),
          color: color,
        ) ??
        TextStyle(
          fontWeight: _resolveFontWeight(fontWeight),
          color: color,
        );
    if (family == null || family.trim().isEmpty) {
      return baseStyle;
    }
    try {
      return GoogleFonts.getFont(family, textStyle: baseStyle);
    } catch (_) {
      return baseStyle.copyWith(fontFamily: family);
    }
  }
}

class _FontOption {
  final String label;
  final String? value;

  const _FontOption(this.label, this.value);
}

/// Static card for tap-based settings (Style, Accent)
class _SettingCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color bgColor;
  final Color fgColor;
  final VoidCallback onTap;

  const _SettingCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.bgColor,
    required this.fgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: fgColor),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Show voice selection bottom sheet
void _showVoiceSelector(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _VoiceSelectorSheet(ref: ref),
  );
}

class _VoiceSelectorSheet extends StatefulWidget {
  final WidgetRef ref;

  const _VoiceSelectorSheet({required this.ref});

  @override
  State<_VoiceSelectorSheet> createState() => _VoiceSelectorSheetState();
}

class _VoiceSelectorSheetState extends State<_VoiceSelectorSheet> {
  List<Map<String, String>> _voices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    try {
      final voices = await _getSystemVoices();
      setState(() {
        _voices = voices
            .where((v) => v['locale']?.contains('en') ?? false)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, String>>> _getSystemVoices() async {
    final FlutterTts flutterTts = FlutterTts();
    final voices = await flutterTts.getVoices;
    return (voices as List)
        .map((v) => Map<String, String>.from(v as Map))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.ref.watch(playerSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Voice',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            )
          else if (_voices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Using system default voice',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _voices.length,
                itemBuilder: (context, index) {
                  final voice = _voices[index];
                  final isSelected = voice['name'] == settings.voiceName;
                  return ListTile(
                    title: Text(voice['name'] ?? 'Unknown'),
                    subtitle: Text(voice['locale'] ?? ''),
                    trailing: isSelected
                        ? Icon(
                            LucideIcons.check,
                            color: colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      widget.ref
                          .read(playerSettingsProvider.notifier)
                          .setVoice(voice['name']!, voice['locale']!);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<Color> colors;
  final Color borderColor;

  _WheelPainter({
    required this.colors,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    for (int i = 0; i < 4; i++) {
      paint.color = colors[i];
      final startAngle = (i * 90 - 45) * 3.14159 / 180;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        startAngle,
        90 * 3.14159 / 180,
        false,
        paint,
      );
    }

    // Border circle
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = borderColor;
    canvas.drawCircle(center, radius - 10, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

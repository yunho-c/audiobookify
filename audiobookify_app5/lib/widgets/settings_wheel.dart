import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';
import '../core/providers.dart';
import '../models/player_settings.dart';
import '../models/player_theme_settings.dart';

/// Audio settings modal with interactive sliders for speed and pitch
class SettingsWheel extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const SettingsWheel({super.key, required this.onClose});

  @override
  ConsumerState<SettingsWheel> createState() => _SettingsWheelState();
}

class _SettingsWheelState extends ConsumerState<SettingsWheel> {
  String? _activeSliderId;
  bool _isSliderDragging = false;

  void _handleSliderDragStart(String sliderId) {
    if (_activeSliderId == sliderId && _isSliderDragging) return;
    _setStateSafely(() {
      _activeSliderId = sliderId;
      _isSliderDragging = true;
    });
  }

  void _handleSliderDragEnd(String sliderId) {
    if (!_isSliderDragging) return;
    _setStateSafely(() {
      _isSliderDragging = false;
      _activeSliderId = null;
    });
  }

  void _setStateSafely(VoidCallback update) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(update);
      });
      return;
    }
    setState(update);
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
      child: Container(
        color: colorScheme.scrim.withAlpha(120),
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
                                color:
                                    Theme.of(context).shadowColor.withAlpha(50),
                                blurRadius: 40,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                                        horizontal: tabGutter / 2,
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
                                        horizontal: tabGutter / 2,
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
      _setStateSafely(() => _speedValue = settings.speed);
    }
    if (!_editingPitch && settings.pitch != _pitchValue) {
      _setStateSafely(() => _pitchValue = settings.pitch);
    }
  }

  void _setStateSafely(VoidCallback update) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(update);
      });
      return;
    }
    setState(update);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fade(_SettingsSectionTitle(title: 'Playback')),
          const SizedBox(height: 12),
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

class _ReaderSettingsTab extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final readerTheme = ref.watch(playerThemeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    Widget fade(Widget child, {String? sliderId}) {
      return FadeOnSliderDrag(
        isDragging: isDragging,
        activeSliderId: activeSliderId,
        sliderId: sliderId,
        child: child,
      );
    }

    void updateTheme(PlayerThemeSettings settings) {
      ref.read(playerThemeProvider.notifier).setTheme(settings);
    }

    final previewText = '“We were somewhere around Barstow...”';
    final previewStyle = _buildPreviewStyle(
      readerTheme,
      textTheme.bodyLarge,
      colorScheme,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
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
                  label: 'Custom',
                  value: PlayerThemeBackgroundMode.customImage,
                ),
              ],
            ),
          ),
          if (readerTheme.backgroundMode ==
              PlayerThemeBackgroundMode.customImage) ...[
            const SizedBox(height: 12),
            fade(
              TextFormField(
                key: ValueKey(readerTheme.backgroundImagePath ?? ''),
                decoration: InputDecoration(
                  labelText: 'Asset image path',
                  hintText: 'assets/backgrounds/paper.png',
                  labelStyle: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceVariant.withAlpha(140),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                initialValue: readerTheme.backgroundImagePath ?? '',
                onChanged: (value) {
                  updateTheme(readerTheme.copyWith(backgroundImagePath: value));
                },
              ),
            ),
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
          fade(_SettingsSectionTitle(title: 'Preview')),
          const SizedBox(height: 10),
          fade(
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withAlpha(120),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                previewText,
                style: previewStyle,
              ),
            ),
          ),
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

  TextStyle _buildPreviewStyle(
    PlayerThemeSettings theme,
    TextStyle? baseStyle,
    ColorScheme colorScheme,
  ) {
    final color = theme.textColorMode == PlayerThemeTextColorMode.fixed &&
            theme.textColor != null
        ? theme.textColor!
        : colorScheme.onSurface;
    final style = (baseStyle ?? const TextStyle()).copyWith(
      fontSize: theme.fontSize,
      fontWeight: _resolveFontWeight(theme.fontWeight),
      height: theme.lineHeight,
      color: color,
    );
    final family = theme.fontFamily;
    if (family == null || family.trim().isEmpty) {
      return style;
    }
    try {
      return GoogleFonts.getFont(family, textStyle: style);
    } catch (_) {
      return style.copyWith(fontFamily: family);
    }
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
class _SettingSlider extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final step = _resolveStep();
    final canDecrease = value > min + 0.0001;
    final canIncrease = value < max - 0.0001;

    void updateByStep(int direction) {
      final target = (value + step * direction).clamp(min, max);
      final snapped = min + (((target - min) / step).round()) * step;
      onChanged(snapped.clamp(min, max).toDouble());
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(12),
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
              Icon(icon, size: 20, color: fgColor),
              const SizedBox(width: 14),
              Text(
                label.toUpperCase(),
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                displayValue,
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
                color: fgColor,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: fgColor,
                    inactiveTrackColor: fgColor.withAlpha(50),
                    thumbColor: fgColor,
                    overlayColor: fgColor.withAlpha(30),
                    trackHeight: 2.5,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                    onChangeStart: onChangeStart,
                    onChangeEnd: onChangeEnd,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _SliderStepButton(
                icon: LucideIcons.plus,
                enabled: canIncrease,
                onTap: () => updateByStep(1),
                color: fgColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _resolveStep() {
    final range = (max - min).abs();
    if (divisions != null && divisions! > 0) {
      return range / divisions!;
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

  static FontWeight _resolveFontWeight(int weight) {
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
          fontWeight: _FontFamilyPicker._resolveFontWeight(fontWeight),
          color: color,
        ) ??
        TextStyle(
          fontWeight: _FontFamilyPicker._resolveFontWeight(fontWeight),
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

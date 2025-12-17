import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/book.dart';
import '../theme.dart';
import '../widgets/book_cover_3d.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/chapters_panel.dart';

/// Full-screen player screen
class PlayerScreen extends StatelessWidget {
  final Book book;
  final bool isPlaying;
  final int currentTime;
  final int duration;
  final int volume;
  final bool showChapters;
  final VoidCallback onBack;
  final VoidCallback onTogglePlay;
  final VoidCallback onSkipForward;
  final VoidCallback onSkipBack;
  final VoidCallback onToggleChapters;
  final ValueChanged<int> onSeek;

  const PlayerScreen({
    super.key,
    required this.book,
    required this.isPlaying,
    required this.currentTime,
    required this.duration,
    required this.volume,
    required this.showChapters,
    required this.onBack,
    required this.onTogglePlay,
    required this.onSkipForward,
    required this.onSkipBack,
    required this.onToggleChapters,
    required this.onSeek,
  });

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;

    return Stack(
      children: [
        // Ambient gradient blobs
        Positioned(
          top: -100,
          left: -50,
          child: Container(
            width: screenWidth * 0.5,
            height: screenWidth * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [book.accentColor.withOpacity(0.2), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          right: -50,
          child: Container(
            width: screenWidth * 0.4,
            height: screenWidth * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.blue.shade900.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Main content
        SafeArea(
          child: isDesktop
              ? _buildDesktopLayout(context)
              : _buildMobileLayout(context),
        ),

        // Chapters panel overlay
        ChaptersPanel(
          book: book,
          isVisible: showChapters,
          onClose: onToggleChapters,
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Left: Book cover
        Expanded(
          child: Center(
            child: BookCover3D(
              gradientColors: book.gradientColors,
              title: book.title,
              author: book.author,
              isLarge: true,
              onTap: onTogglePlay,
            ),
          ),
        ),

        // Right: Controls
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(),
                const SizedBox(height: 32),
                _buildBookInfo(),
                const SizedBox(height: 32),
                AudioVisualizer(isPlaying: isPlaying),
                const SizedBox(height: 32),
                _buildProgressSlider(),
                const SizedBox(height: 32),
                _buildMainControls(),
                const SizedBox(height: 24),
                _buildSecondaryControls(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Book cover
          Center(
            child: BookCover3D(
              gradientColors: book.gradientColors,
              title: book.title,
              author: book.author,
              isLarge: true,
              onTap: onTogglePlay,
            ),
          ),
          const SizedBox(height: 32),
          _buildBookInfo(centered: true),
          const SizedBox(height: 24),
          AudioVisualizer(isPlaying: isPlaying),
          const SizedBox(height: 24),
          _buildProgressSlider(),
          const SizedBox(height: 24),
          _buildMainControls(),
          const SizedBox(height: 24),
          _buildSecondaryControls(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: onBack,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: 1.5708, // 90 degrees
            child: const Icon(
              LucideIcons.chevronDown,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Back to Library',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBookInfo({bool centered = false}) {
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          book.title,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
          textAlign: centered ? TextAlign.center : TextAlign.start,
        ),
        const SizedBox(height: 8),
        Text(
          book.author,
          style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Fiction',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.clock, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  book.duration,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressSlider() {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.indigo,
            inactiveTrackColor: AppColors.surfaceLight,
            thumbColor: Colors.white,
            overlayColor: AppColors.indigo.withOpacity(0.2),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: currentTime.toDouble(),
            min: 0,
            max: duration.toDouble(),
            onChanged: (value) => onSeek(value.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTime(currentTime),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                '-${_formatTime(duration - currentTime)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onSkipBack,
          icon: const Icon(LucideIcons.skipBack),
          iconSize: 28,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: onTogglePlay,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: book.gradientColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: book.accentColor.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              isPlaying ? LucideIcons.pause : LucideIcons.play,
              size: 32,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 24),
        IconButton(
          onPressed: onSkipForward,
          icon: const Icon(LucideIcons.skipForward),
          iconSize: 28,
          color: AppColors.textSecondary,
        ),
      ],
    );
  }

  Widget _buildSecondaryControls() {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.surface, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Chapters button
          GestureDetector(
            onTap: onToggleChapters,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.list,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Chapters',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Volume indicator
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                volume == 0 ? LucideIcons.volumeX : LucideIcons.volume2,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Container(
                width: 80,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: AppColors.surfaceLight,
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: volume / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Share button
          IconButton(
            onPressed: () {},
            icon: const Icon(LucideIcons.share2),
            iconSize: 18,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

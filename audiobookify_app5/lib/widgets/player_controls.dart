import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Audio player controls with progress bar and playback buttons
class PlayerControls extends StatelessWidget {
  final bool isPlaying;
  final double progress;
  final String currentTime;
  final String duration;
  final VoidCallback onPlayPause;
  final VoidCallback? onSkipBack;
  final VoidCallback? onSkipForward;

  const PlayerControls({
    super.key,
    required this.isPlaying,
    required this.progress,
    this.currentTime = '0:00',
    this.duration = '0:00',
    required this.onPlayPause,
    this.onSkipBack,
    this.onSkipForward,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withAlpha(230),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(25),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar section
          Column(
            children: [
              // Time labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currentTime,
                    style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    duration,
                    style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Progress bar
              SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    // Background
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    // Progress
                    FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Shuffle
              IconButton(
                onPressed: () {},
                icon: const Icon(LucideIcons.shuffle, size: 20),
                color: colorScheme.onSurfaceVariant,
              ),
              // Skip back
              IconButton(
                onPressed: onSkipBack,
                icon: const Icon(LucideIcons.skipBack, size: 28),
                color: colorScheme.onSurface,
              ),
              // Play/Pause
              GestureDetector(
                onTap: onPlayPause,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withAlpha(50),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isPlaying ? LucideIcons.pause : LucideIcons.play,
                      color: colorScheme.onPrimary,
                      size: 32,
                    ),
                  ),
                ),
              ),
              // Skip forward
              IconButton(
                onPressed: onSkipForward,
                icon: const Icon(LucideIcons.skipForward, size: 28),
                color: colorScheme.onSurface,
              ),
              // Repeat
              IconButton(
                onPressed: () {},
                icon: const Icon(LucideIcons.repeat, size: 20),
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

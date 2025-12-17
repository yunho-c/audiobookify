import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';
import '../widgets/player_controls.dart';
import '../widgets/settings_wheel.dart';

/// Player screen with text reader, audio controls, and settings modal
class PlayerScreen extends StatefulWidget {
  final String bookId;

  const PlayerScreen({super.key, required this.bookId});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isPlaying = true;
  bool _showSettings = false;
  int _currentParagraph = 1;

  final List<String> _content = [
    "I was born in the year 1632, in the city of York, of a good family, though not of that country, my father being a foreigner of Bremen, who settled first at Hull.",
    "He got a good estate by merchandise, and leaving off his trade, lived afterwards at York, from whence he had married my mother, whose relations were named Robinson, a very good family in that country, and from whom I was called Robinson Kreutznaer; but, by the usual corruption of words in England, we are now called - nay we call ourselves and write our name - Crusoe; and so my companions always called me.",
    "I had two elder brothers, one of whom was lieutenant-colonel to an English regiment of foot in Flanders, formerly commanded by the famous Col. Lockhart, and was killed at the battle near Dunkirk against the Spaniards.",
    "What became of my second brother I never knew, any more than my father or mother knew what became of me.",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.orange50,
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Header
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/book/${widget.bookId}'),
                        child: const Icon(
                          LucideIcons.arrowLeft,
                          color: AppColors.stone600,
                          size: 24,
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '2. Fireman',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.stone800,
                            ),
                          ),
                          Text(
                            'CHAPTER 2',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w500,
                              color: AppColors.stone500,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showSettings = true),
                        child: const Icon(
                          LucideIcons.settings2,
                          color: AppColors.stone600,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Text content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 16, 32, 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _content.asMap().entries.map((entry) {
                      final isHighlighted = entry.key == _currentParagraph;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: isHighlighted
                            ? const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              )
                            : EdgeInsets.zero,
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? AppColors.orange200.withAlpha(125)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          entry.value,
                          style: GoogleFonts.lora(
                            fontSize: 18,
                            height: 1.8,
                            color: isHighlighted
                                ? AppColors.stone800
                                : AppColors.stone600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          // Player controls at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PlayerControls(
              isPlaying: _isPlaying,
              progress: 0.72,
              currentTime: '17:06',
              duration: '23:56',
              onPlayPause: () => setState(() => _isPlaying = !_isPlaying),
            ),
          ),
          // Settings modal
          if (_showSettings)
            Positioned.fill(
              child: SettingsWheel(
                onClose: () => setState(() => _showSettings = false),
              ),
            ),
        ],
      ),
    );
  }
}

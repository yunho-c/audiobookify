import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'theme.dart';
import 'models/book.dart';
import 'screens/library_screen.dart';
import 'screens/player_screen.dart';

void main() {
  runApp(const AudiobookifyApp());
}

/// Root application widget
class AudiobookifyApp extends StatelessWidget {
  const AudiobookifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audiobookify',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}

/// Main home screen with navigation and state management
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // View state
  String _currentView = 'library'; // 'library' or 'player'
  Book? _currentBook;

  // Playback state
  bool _isPlaying = false;
  int _currentTime = 0;
  final int _duration = 300; // 5 minutes mock duration
  int _volume = 80;
  bool _showChapters = false;

  Timer? _playbackTimer;

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _selectBook(Book book) {
    setState(() {
      _currentBook = book;
      _currentView = 'player';
      _isPlaying = true;
      _currentTime = 0;
      _showChapters = false;
    });
    _startPlaybackTimer();
  }

  void _goToLibrary() {
    setState(() {
      _currentView = 'library';
      _showChapters = false;
    });
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      _startPlaybackTimer();
    } else {
      _playbackTimer?.cancel();
    }
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPlaying && mounted) {
        setState(() {
          if (_currentTime >= _duration) {
            _isPlaying = false;
            _currentTime = 0;
            timer.cancel();
          } else {
            _currentTime++;
          }
        });
      }
    });
  }

  void _seek(int time) {
    setState(() {
      _currentTime = time;
    });
  }

  void _toggleChapters() {
    setState(() {
      _showChapters = !_showChapters;
    });
  }

  void _skipForward() {
    setState(() {
      _currentTime = (_currentTime + 15).clamp(0, _duration);
    });
  }

  void _skipBack() {
    setState(() {
      _currentTime = (_currentTime - 15).clamp(0, _duration);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Desktop sidebar
          if (isDesktop) _buildSidebar(),

          // Main content area
          Expanded(
            child: Column(
              children: [
                // Mobile header
                if (!isDesktop) _buildMobileHeader(),

                // Content
                Expanded(
                  child: Stack(
                    children: [
                      // Library view
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 500),
                        opacity: _currentView == 'library' ? 1 : 0,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 500),
                          offset: _currentView == 'library'
                              ? Offset.zero
                              : const Offset(0, -0.1),
                          child: IgnorePointer(
                            ignoring: _currentView != 'library',
                            child: LibraryScreen(onBookSelect: _selectBook),
                          ),
                        ),
                      ),

                      // Player view
                      if (_currentBook != null)
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 700),
                          opacity: _currentView == 'player' ? 1 : 0,
                          child: AnimatedSlide(
                            duration: const Duration(milliseconds: 700),
                            offset: _currentView == 'player'
                                ? Offset.zero
                                : const Offset(0, 1),
                            child: IgnorePointer(
                              ignoring: _currentView != 'player',
                              child: PlayerScreen(
                                book: _currentBook!,
                                isPlaying: _isPlaying,
                                currentTime: _currentTime,
                                duration: _duration,
                                volume: _volume,
                                showChapters: _showChapters,
                                onBack: _goToLibrary,
                                onTogglePlay: _togglePlay,
                                onSkipForward: _skipForward,
                                onSkipBack: _skipBack,
                                onToggleChapters: _toggleChapters,
                                onSeek: _seek,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 80,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(right: BorderSide(color: AppColors.surface, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Logo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.indigo,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.indigo.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              LucideIcons.bookOpen,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 48),
          // Nav buttons
          _buildNavButton(
            icon: LucideIcons.list,
            isActive: _currentView == 'library',
            onTap: _goToLibrary,
          ),
          const SizedBox(height: 24),
          _buildNavButton(
            icon: LucideIcons.heart,
            isActive: false,
            onTap: () {},
          ),
          const SizedBox(height: 24),
          _buildNavButton(
            icon: LucideIcons.settings,
            isActive: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 24,
          color: isActive ? AppColors.indigoLight : AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.indigo,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.indigo.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.bookOpen,
                color: Colors.white,
                size: 20,
              ),
            ),
            // Back button (only in player view)
            if (_currentView == 'player')
              GestureDetector(
                onTap: _goToLibrary,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.chevronDown,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

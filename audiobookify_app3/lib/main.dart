import 'package:flutter/material.dart';
import 'theme/theme.dart';
import 'models/book.dart';
import 'views/home_view.dart';
import 'views/library_view.dart';
import 'views/search_view.dart';
import 'widgets/nav_bar.dart';
import 'widgets/mini_player.dart';
import 'widgets/full_player.dart';

void main() {
  runApp(const AudiobookifyApp());
}

class AudiobookifyApp extends StatelessWidget {
  const AudiobookifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audiobookify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AudiobookifyHome(),
    );
  }
}

class AudiobookifyHome extends StatefulWidget {
  const AudiobookifyHome({super.key});

  @override
  State<AudiobookifyHome> createState() => _AudiobookifyHomeState();
}

class _AudiobookifyHomeState extends State<AudiobookifyHome> {
  NavTab _activeTab = NavTab.home;
  Book? _activeBook = Book.mockBooks[0];
  bool _isPlaying = false;
  bool _showFullPlayer = false;

  void _handlePlayBook(Book book) {
    setState(() {
      if (_activeBook?.id == book.id) {
        _showFullPlayer = true;
      } else {
        _activeBook = book;
        _isPlaying = true;
        _showFullPlayer = true;
      }
    });
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Main content
          Positioned.fill(child: _buildCurrentView()),

          // Mini player
          if (!_showFullPlayer && _activeBook != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(
                book: _activeBook!,
                isPlaying: _isPlaying,
                onTogglePlay: _togglePlay,
                onExpand: () => setState(() => _showFullPlayer = true),
              ),
            ),

          // Navigation bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: NavBar(
              activeTab: _activeTab,
              onTabChanged: (tab) => setState(() => _activeTab = tab),
            ),
          ),

          // Full player - only included when showing
          if (_showFullPlayer)
            FullPlayer(
              book: _activeBook,
              isPlaying: _isPlaying,
              onTogglePlay: _togglePlay,
              onClose: () => setState(() => _showFullPlayer = false),
              show: _showFullPlayer,
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_activeTab) {
      case NavTab.home:
        return HomeView(onPlayBook: _handlePlayBook);
      case NavTab.search:
        return const SearchView();
      case NavTab.library:
        return LibraryView(onPlayBook: _handlePlayBook);
    }
  }
}

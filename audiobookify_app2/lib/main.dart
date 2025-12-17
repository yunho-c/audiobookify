import 'package:flutter/material.dart';
import 'data/book_data.dart';
import 'theme/app_theme.dart';
import 'widgets/book_3d.dart';
import 'widgets/creator_disk.dart';
import 'widgets/chapter_list.dart';
import 'widgets/navigation_dock.dart';
import 'screens/shelf_screen.dart';
import 'screens/reader_screen.dart';

void main() {
  runApp(const AudiobookifyApp());
}

/// View states matching the React reference
enum ViewState { shelf, isoPreview, openEmpty, creator, ready, reading }

class AudiobookifyApp extends StatelessWidget {
  const AudiobookifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audiobookify',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AudiobookifyHome(),
    );
  }
}

class AudiobookifyHome extends StatefulWidget {
  const AudiobookifyHome({super.key});

  @override
  State<AudiobookifyHome> createState() => _AudiobookifyHomeState();
}

class _AudiobookifyHomeState extends State<AudiobookifyHome>
    with TickerProviderStateMixin {
  // Data
  late List<Book> _books;
  late List<List<Book>> _shelves;

  // State
  ViewState _viewState = ViewState.shelf;
  Book? _selectedBook;
  Chapter? _playingChapter;
  Rect? _animRect;

  // Animation
  late AnimationController _positionController;
  late Animation<Rect?> _rectAnimation;

  @override
  void initState() {
    super.initState();
    _books = generateBooks();
    _shelves = organizeBooksIntoShelves(_books);

    _positionController = AnimationController(
      duration: AppAnimations.bookTransformDuration,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _positionController.dispose();
    super.dispose();
  }

  // --- Interaction Handlers ---

  void _handleBookTap(Book book, Rect rect) {
    setState(() {
      _selectedBook = book;
      _animRect = rect;
      _viewState = ViewState.isoPreview;
    });

    // Animate to center
    final screenSize = MediaQuery.of(context).size;
    final targetRect = Rect.fromCenter(
      center: Offset(screenSize.width / 2 - 80, screenSize.height / 2),
      width: 280,
      height: 420,
    );

    _rectAnimation = RectTween(begin: rect, end: targetRect).animate(
      CurvedAnimation(
        parent: _positionController,
        curve: AppAnimations.bookTransformCurve,
      ),
    );

    _positionController.forward(from: 0);
  }

  void _handleIsoClick() {
    setState(() {
      _viewState = ViewState.openEmpty;
    });
  }

  void _handleEmptyClick() {
    setState(() {
      _viewState = ViewState.creator;
    });
  }

  void _handleGenerate() {
    setState(() {
      _viewState = ViewState.ready;
    });
  }

  void _handlePlayChapter(Chapter chapter) {
    setState(() {
      _playingChapter = chapter;
      _viewState = ViewState.reading;
    });
  }

  void _handleClose() {
    if (_viewState == ViewState.reading) {
      setState(() {
        _viewState = ViewState.ready;
        _playingChapter = null;
      });
    } else {
      // Animate back to shelf
      _positionController.reverse().then((_) {
        setState(() {
          _viewState = ViewState.shelf;
          _selectedBook = null;
          _animRect = null;
          _playingChapter = null;
        });
      });
    }
  }

  void _handleCloseReader() {
    setState(() {
      _viewState = ViewState.ready;
      _playingChapter = null;
    });
  }

  // --- Helpers ---

  BookViewState _getBookViewState() {
    switch (_viewState) {
      case ViewState.shelf:
        return BookViewState.spine;
      case ViewState.isoPreview:
        return BookViewState.isometric;
      case ViewState.openEmpty:
      case ViewState.creator:
      case ViewState.ready:
      case ViewState.reading:
        return BookViewState.open;
    }
  }

  Widget? _getInteriorContent() {
    switch (_viewState) {
      case ViewState.openEmpty:
        return _EmptyState(onTap: _handleEmptyClick);
      case ViewState.creator:
        return CreatorDisk(onGenerate: _handleGenerate);
      case ViewState.ready:
      case ViewState.reading:
        return ChapterList(
          chapters: _selectedBook?.chapters ?? [],
          onChapterTap: _handlePlayChapter,
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Layer 0: Background texture
          _buildBackground(),

          // Layer 1: Shelf view
          ShelfScreen(
            shelves: _shelves,
            onBookTap: _handleBookTap,
            isBlurred: _viewState != ViewState.shelf,
          ),

          // Layer 2: Backdrop overlay
          if (_viewState != ViewState.shelf)
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              color: Colors.black.withOpacity(0.8),
            ),

          // Layer 3: 3D Book
          if (_selectedBook != null && _animRect != null)
            AnimatedBuilder(
              animation: _positionController,
              builder: (context, child) {
                final rect = _rectAnimation.value ?? _animRect!;
                return Positioned(
                  left: rect.left,
                  top: rect.top,
                  width: rect.width,
                  height: rect.height,
                  child: GestureDetector(
                    onTap: _viewState == ViewState.isoPreview
                        ? _handleIsoClick
                        : null,
                    child: Book3D(
                      book: _selectedBook!,
                      viewState: _getBookViewState(),
                      interiorContent: _getInteriorContent(),
                    ),
                  ),
                );
              },
            ),

          // Layer 4: Isometric text overlay
          if (_viewState == ViewState.isoPreview && _selectedBook != null)
            _buildIsoTextOverlay(),

          // Layer 5: Close button
          if (_viewState != ViewState.shelf && _viewState != ViewState.reading)
            Positioned(
              top: 24,
              right: 24,
              child: _CloseButton(onTap: _handleClose),
            ),

          // Layer 6: Reader view
          if (_viewState == ViewState.reading &&
              _selectedBook != null &&
              _playingChapter != null)
            Positioned.fill(
              child: ReaderScreen(
                book: _selectedBook!,
                chapter: _playingChapter!,
                onClose: _handleCloseReader,
              ),
            ),

          // Layer 7: Navigation dock
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: NavigationDock(
                visible: _viewState == ViewState.shelf,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
        color: AppColors.backgroundLight,
        child: Stack(
          children: [
            // Diagonal stripe pattern
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: CustomPaint(
                  painter: _StripePainter(),
                ),
              ),
            ),

            // Vignette
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIsoTextOverlay() {
    return Positioned(
      top: MediaQuery.of(context).size.height / 2 - 100,
      left: MediaQuery.of(context).size.width / 2 + 100,
      child: IgnorePointer(
        child: Transform(
          alignment: Alignment.topLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(20 * 3.14159 / 180)
            ..rotateY(-30 * 3.14159 / 180)
            ..rotateZ(-5 * 3.14159 / 180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedBook!.title,
                style: AppTextStyles.goldStamp.copyWith(
                  fontSize: 32,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedBook!.author,
                style: TextStyle(
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                  color: AppColors.warmStone,
                ),
              ),
              const SizedBox(height: 24),

              // Metadata
              _MetadataRow(
                icon: Icons.album,
                label: 'NOT GENERATED',
              ),
              const SizedBox(height: 12),
              _MetadataRow(
                icon: Icons.description,
                label: '${_selectedBook!.pages} PAGES',
              ),
              const SizedBox(height: 12),
              _MetadataRow(
                icon: Icons.access_time,
                label: '${_selectedBook!.duration} EST',
              ),

              const SizedBox(height: 32),

              // Hint
              _PulsingText(text: 'Click Book to Open'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state with dashed circle and plus icon
class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey.shade400,
                width: 4,
                style: BorderStyle.solid,
              ),
            ),
            child: CustomPaint(
              painter: _DashedCirclePainter(),
              child: Center(
                child: Icon(
                  Icons.add,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'NO AUDIO GENERATED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to Create',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed circle painter
class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    const dashCount = 24;
    const dashAngle = 3.14159 * 2 / dashCount;
    const gapAngle = dashAngle * 0.4;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle - gapAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Close button
class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.close,
          size: 24,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Metadata row with icon and label
class _MetadataRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetadataRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white.withOpacity(0.8)),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            letterSpacing: 2,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

/// Pulsing hint text
class _PulsingText extends StatefulWidget {
  final String text;

  const _PulsingText({required this.text});

  @override
  State<_PulsingText> createState() => _PulsingTextState();
}

class _PulsingTextState extends State<_PulsingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (_controller.value * 0.4),
          child: Text(
            widget.text.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 4,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

/// Stripe pattern painter for background
class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;

    const spacing = 8.0;
    var x = 0.0;

    while (x < size.width + size.height) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height, size.height),
        paint,
      );
      x += spacing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

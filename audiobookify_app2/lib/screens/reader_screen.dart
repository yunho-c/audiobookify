import 'package:flutter/material.dart';
import '../data/book_data.dart';
import '../theme/app_theme.dart';

/// Full-screen reading view with playback controls
class ReaderScreen extends StatelessWidget {
  final Book book;
  final Chapter chapter;
  final VoidCallback onClose;

  const ReaderScreen({
    super.key,
    required this.book,
    required this.chapter,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: AppColors.readerBg,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Content
            Expanded(
              child: _buildContent(),
            ),

            // Playback controls
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.readerHeader,
        border: Border(
          bottom: BorderSide(
            color: Color(0x1A3e2723),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 28),
            color: AppColors.darkBrown,
          ),

          // Chapter title badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.readerAccent,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFeec55d),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${chapter.id}. ${chapter.title}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: AppColors.darkBrown,
              ),
            ),
          ),

          // Spacer for balance
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _DropCapText(text: chapter.text),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 48),
      decoration: BoxDecoration(
        color: AppColors.readerBg.withOpacity(0.95),
        border: const Border(
          top: BorderSide(
            color: Color(0x0D3e2723),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Skip back
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.skip_previous, size: 32),
            color: AppColors.darkBrown,
          ),

          const SizedBox(width: 24),

          // Play/Pause button
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryBrown,
              border: Border.all(
                color: AppColors.darkBrown,
                width: 4,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.pause, size: 32),
              color: AppColors.cream,
            ),
          ),

          const SizedBox(width: 24),

          // Skip forward
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.skip_next, size: 32),
            color: AppColors.darkBrown,
          ),
        ],
      ),
    );
  }
}

/// Text widget with drop cap styling
class _DropCapText extends StatelessWidget {
  final String text;

  const _DropCapText({required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final firstLetter = text[0];
    final restOfText = text.substring(1);

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'serif',
          fontSize: 20,
          height: 1.8,
          color: AppColors.readerText,
        ),
        children: [
          // Drop cap
          WidgetSpan(
            child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 4),
              child: Text(
                firstLetter,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkBrown,
                  height: 0.8,
                ),
              ),
            ),
          ),
          TextSpan(text: restOfText),
        ],
      ),
    );
  }
}

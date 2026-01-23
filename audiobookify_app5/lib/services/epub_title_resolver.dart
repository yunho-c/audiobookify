import 'package:html/parser.dart' as html_parser;
import '../src/rust/api/epub.dart';

const int _maxInferredTitleLength = 80;

Map<String, String> buildTocTitleByHref(List<TocEntry> toc) {
  final tocTitleByHref = <String, String>{};
  for (final entry in toc) {
    final key = normalizeHref(entry.href);
    final title = entry.title.trim();
    if (key.isNotEmpty && title.isNotEmpty) {
      tocTitleByHref[key] = title;
    }
  }
  return tocTitleByHref;
}

String resolveChapterTitle({
  required ChapterInfo chapter,
  required int chapterIndex,
  required int displayIndex,
  required Map<String, String> tocTitleByHref,
  required List<String> chapterContents,
  bool preferTocTitle = true,
}) {
  if (preferTocTitle) {
    final tocTitle = tocTitleByHref[normalizeHref(chapter.href)];
    if (_isMeaningfulTitle(tocTitle)) {
      return tocTitle!.trim();
    }
  }

  if (chapterIndex >= 0 && chapterIndex < chapterContents.length) {
    final inferred = _inferTitleFromContent(chapterContents[chapterIndex]);
    if (_isMeaningfulTitle(inferred)) {
      return inferred!;
    }
  }

  final hrefTitle = _titleFromHref(chapter.href);
  if (_isMeaningfulTitle(hrefTitle)) {
    return hrefTitle!;
  }

  final fallback = chapter.id.trim();
  if (fallback.isNotEmpty && !_looksLikeGeneratedId(fallback)) {
    return fallback;
  }

  return 'Chapter $displayIndex';
}

String normalizeHref(String href) {
  final trimmed = href.trim();
  if (trimmed.isEmpty) return '';
  final withoutFragment = trimmed.split('#').first;
  if (withoutFragment.startsWith('./')) {
    return withoutFragment.substring(2);
  }
  return withoutFragment;
}

String? _inferTitleFromContent(String html) {
  if (html.trim().isEmpty) return null;
  final document = html_parser.parse(html);
  final heading =
      document.querySelector('h1, h2, h3, h4, h5, h6');
  final headingText = _cleanTitle(heading?.text);
  if (_isMeaningfulTitle(headingText)) return headingText;

  final titleTag = document.querySelector('title');
  final titleText = _cleanTitle(titleTag?.text);
  if (_isMeaningfulTitle(titleText)) return titleText;

  final body = document.body;
  if (body == null) return null;
  final text = body.text.trim();
  if (text.isEmpty) return null;
  final firstLine = text
      .split(RegExp(r'\n+'))
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  final cleaned = _cleanTitle(firstLine);
  if (_isMeaningfulTitle(cleaned)) return cleaned;
  return null;
}

String? _titleFromHref(String href) {
  final normalized = normalizeHref(href);
  if (normalized.isEmpty) return null;
  final fileName = normalized.split('/').last;
  if (fileName.isEmpty) return null;
  final baseName = fileName.split('.').first;
  final cleaned = _cleanTitle(
    baseName.replaceAll(RegExp(r'[_-]+'), ' '),
  );
  if (_isMeaningfulTitle(cleaned)) return cleaned;
  return null;
}

String? _cleanTitle(String? title) {
  if (title == null) return null;
  final collapsed = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.isEmpty) return null;
  if (collapsed.length <= _maxInferredTitleLength) return collapsed;
  return '${collapsed.substring(0, _maxInferredTitleLength).trimRight()}...';
}

bool _looksLikeGeneratedId(String value) {
  return RegExp(r'^id\d+$', caseSensitive: false).hasMatch(value);
}

bool _isMeaningfulTitle(String? title) {
  if (title == null) return false;
  final trimmed = title.trim();
  if (trimmed.isEmpty || trimmed.length < 2) return false;
  if (RegExp(r'^[\d\W]+$').hasMatch(trimmed)) return false;
  return true;
}

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

String formatDescriptionForDisplay(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  final fragment = html_parser.parseFragment(trimmed);
  final buffer = StringBuffer();

  for (final node in fragment.nodes) {
    _appendDescriptionNode(buffer, node);
  }

  var output = buffer.toString().replaceAll('\u00A0', ' ');
  output = output.replaceAll(RegExp(r'[ \t\r\f\v]+'), ' ');
  output = output.replaceAll(RegExp(r' *\n *'), '\n');
  output = output.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return output.trim();
}

const Set<String> _descriptionBlockTags = {
  'article',
  'aside',
  'blockquote',
  'div',
  'figcaption',
  'figure',
  'footer',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'header',
  'main',
  'nav',
  'p',
  'section',
  'ul',
  'ol',
};

const Set<String> _descriptionIgnoredTags = {'script', 'style', 'template'};

void _appendDescriptionNode(StringBuffer buffer, dom.Node node) {
  if (node is dom.Comment) {
    return;
  }

  if (node is dom.Text) {
    buffer.write(node.text);
    return;
  }

  if (node is! dom.Element) {
    return;
  }

  final tag = node.localName?.toLowerCase();
  if (tag == null || _descriptionIgnoredTags.contains(tag)) {
    return;
  }

  if (tag == 'br') {
    _appendLineBreak(buffer);
    return;
  }

  if (tag == 'li') {
    final text = buffer.toString();
    if (text.isNotEmpty && !text.endsWith('\n')) {
      buffer.write('\n');
    }
    buffer.write('• ');
    for (final child in node.nodes) {
      _appendDescriptionNode(buffer, child);
    }
    _appendLineBreak(buffer);
    return;
  }

  final isBlock = _descriptionBlockTags.contains(tag);
  if (isBlock) {
    _appendBlockBreak(buffer);
  }

  for (final child in node.nodes) {
    _appendDescriptionNode(buffer, child);
  }

  if (isBlock) {
    _appendBlockBreak(buffer);
  }
}

void _appendLineBreak(StringBuffer buffer) {
  final text = buffer.toString();
  if (text.endsWith('\n')) return;
  buffer.write('\n');
}

void _appendBlockBreak(StringBuffer buffer) {
  final text = buffer.toString();
  if (text.isEmpty) return;
  if (text.endsWith('\n\n')) return;
  if (text.endsWith('\n')) {
    buffer.write('\n');
    return;
  }
  buffer.write('\n\n');
}

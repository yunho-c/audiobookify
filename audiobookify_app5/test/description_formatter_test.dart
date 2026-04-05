import 'package:flutter_test/flutter_test.dart';

import 'package:audiobookify/core/description_formatter.dart';

void main() {
  group('formatDescriptionForDisplay', () {
    test('leaves plain text unchanged', () {
      expect(
        formatDescriptionForDisplay('Already clean text.'),
        'Already clean text.',
      );
    });

    test('preserves paragraph and line breaks while stripping tags', () {
      expect(
        formatDescriptionForDisplay(
          '<p>Hello <em>world</em></p><div>Line<br>break</div>',
        ),
        'Hello world\n\nLine\nbreak',
      );
    });

    test('decodes entities and formats list items as bullets', () {
      expect(
        formatDescriptionForDisplay(
          '<p>Tom &amp; Jerry&nbsp;forever</p><ul><li>One</li><li>Two</li></ul>',
        ),
        'Tom & Jerry forever\n\n• One\n• Two',
      );
    });

    test('removes ignored tags and malformed markup safely', () {
      expect(
        formatDescriptionForDisplay(
          '<script>alert(1)</script><p>Start <strong>here</strong><p>Next',
        ),
        'Start here\n\nNext',
      );
    });

    test('keeps link text and collapses doubled inline whitespace', () {
      expect(
        formatDescriptionForDisplay(
          '<p>Read <a href="https://example.com">more</a>   now</p>',
        ),
        'Read more now',
      );
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:audiobookify_app5/services/open_library_service.dart';

void main() {
  test('searchPublicDomain filters and maps results', () async {
    final responseBody = json.encode({
      'docs': [
        {
          'title': 'Public Book',
          'author_name': ['Author One'],
          'first_publish_year': 1910,
          'cover_i': 123,
          'ia': ['publicbookid'],
          'ebook_access': 'public',
          'key': '/works/OL1W',
        },
        {
          'title': 'Borrowable Book',
          'author_name': ['Author Two'],
          'ia': ['borrowableid'],
          'ebook_access': 'borrowable',
          'key': '/works/OL2W',
        },
        {
          'title': 'Missing IA',
          'author_name': ['Author Three'],
          'ebook_access': 'public',
          'key': '/works/OL3W',
        },
        {
          'title': 'Public Book 2',
          'author_name': 'Solo Author',
          'first_publish_year': '1905',
          'cover_i': '456',
          'ia': 'publicbookid2',
          'ebook_access': 'public',
          'key': '/works/OL4W',
        },
      ],
    });

    final client = MockClient((request) async {
      return http.Response(responseBody, 200);
    });

    final service = OpenLibraryService(client: client);
    final results = await service.searchPublicDomain(query: 'classics');

    expect(results.length, 2);

    final first = results.first;
    expect(first.title, 'Public Book');
    expect(first.primaryAuthor, 'Author One');
    expect(first.firstPublishYear, 1910);
    expect(
      first.coverUrl,
      'https://covers.openlibrary.org/b/id/123-M.jpg',
    );
    expect(
      first.epubUrl,
      'https://archive.org/download/publicbookid/publicbookid.epub',
    );
    expect(first.key, '/works/OL1W');
    expect(first.iaId, 'publicbookid');

    final second = results.last;
    expect(second.title, 'Public Book 2');
    expect(second.primaryAuthor, 'Solo Author');
    expect(second.firstPublishYear, 1905);
    expect(
      second.coverUrl,
      'https://covers.openlibrary.org/b/id/456-M.jpg',
    );
    expect(
      second.epubUrl,
      'https://archive.org/download/publicbookid2/publicbookid2.epub',
    );
  });

  test('searchPublicDomain sends expected params and headers', () async {
    const userAgent = 'TestAgent/1.0 (test@example.com)';

    final client = MockClient((request) async {
      expect(request.headers['User-Agent'], userAgent);

      final params = request.url.queryParameters;
      expect(params['q'], 'Sherlock Holmes');
      expect(params['has_fulltext'], 'true');
      expect(params['fields'],
          'key,title,author_name,cover_i,ia,ebook_access,first_publish_year,language');
      expect(params['limit'], '10');
      expect(params['page'], '2');
      expect(params['mode'], 'everything');
      expect(params['lang'], 'en');

      return http.Response(json.encode({'docs': []}), 200);
    });

    final service = OpenLibraryService(client: client, userAgent: userAgent);
    final results = await service.searchPublicDomain(
      query: 'Sherlock Holmes',
      page: 2,
      limit: 10,
      language: 'en',
    );

    expect(results, isEmpty);
  });

  test('searchPublicDomain returns empty for blank query', () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response(json.encode({'docs': []}), 200);
    });

    final service = OpenLibraryService(client: client);
    final results = await service.searchPublicDomain(query: '   ');

    expect(results, isEmpty);
    expect(called, isFalse);
  });
}

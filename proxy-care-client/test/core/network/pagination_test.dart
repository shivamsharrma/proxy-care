import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/network/pagination.dart';
import 'package:proxy_care_client/core/network/response_parser.dart';

import '../../helpers/decoding_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/network_harness.dart';

/// A backend `PageResponse` body (`com.proxycare.common.api.PageResponse`):
/// [page] is 0-based, as Spring Data sends it.
Map<String, Object?> _pageBody(
  List<Map<String, Object?>> items, {
  required int page,
  required int size,
  required int totalElements,
  required int totalPages,
}) => {
  'items': items,
  'page': page,
  'size': size,
  'totalElements': totalElements,
  'totalPages': totalPages,
};

/// Mirrors the backend's paging: Spring Data `Pageable` request parameters
/// `page` (0-based) and `size` (`application.yml`
/// `spring.data.web.pageable`: default 20, max 100), and the response
/// `com.proxycare.common.api.PageResponse{items, page, size, totalElements,
/// totalPages}` built from a Spring `Page`.
void main() {
  group('PageRequest', () {
    test('the first page is page 0 with the default size', () {
      const request = PageRequest();

      expect(request.page, 0);
      expect(request.size, 20);
      expect(PageRequest.defaultSize, 20);
      expect(PageRequest.maxSize, 100);
    });

    test('becomes page and size query parameters', () {
      expect(const PageRequest().toQuery(), {'page': 0, 'size': 20});
      expect(const PageRequest(page: 2, size: 50).toQuery(), {
        'page': 2,
        'size': 50,
      });
      expect(PageRequest.pageParameter, 'page');
      expect(PageRequest.sizeParameter, 'size');
    });

    test('rejects a negative page and a size outside 1 to 100', () {
      PageRequest request({int page = 0, int size = 20}) =>
          PageRequest(page: page, size: size);

      expect(() => request(page: -1), throwsA(isA<AssertionError>()));
      expect(() => request(size: 0), throwsA(isA<AssertionError>()));
      expect(() => request(size: 101), throwsA(isA<AssertionError>()));
      expect(const PageRequest(size: 100).size, 100);
    });

    test('asks for the following page while one exists', () {
      const request = PageRequest(size: 10);
      const first = PageResponse<int>(
        items: [1],
        page: 0,
        size: 10,
        totalElements: 25,
        totalPages: 3,
      );
      const last = PageResponse<int>(
        items: [1],
        page: 2,
        size: 10,
        totalElements: 25,
        totalPages: 3,
      );

      final next = request.next(first)!;
      expect(next.page, 1);
      expect(next.size, 10);
      expect(request.next(last), isNull);
    });
  });

  group('PageResponse', () {
    test('has a next page when it is not the last one', () {
      const page = PageResponse<int>(
        items: [1, 2],
        page: 0,
        size: 2,
        totalElements: 5,
        totalPages: 3,
      );

      expect(page.hasNext, isTrue);
    });

    test('the last page has no next page', () {
      const page = PageResponse<int>(
        items: [5],
        page: 2,
        size: 2,
        totalElements: 5,
        totalPages: 3,
      );

      expect(page.hasNext, isFalse);
    });

    test('an empty collection is one empty page with no next page', () {
      const page = PageResponse<int>(
        items: [],
        page: 0,
        size: 20,
        totalElements: 0,
        totalPages: 0,
      );

      expect(page.items, isEmpty);
      expect(page.hasNext, isFalse);
    });

    test('a page past the end has no next page', () {
      const page = PageResponse<int>(
        items: [],
        page: 7,
        size: 20,
        totalElements: 25,
        totalPages: 2,
      );

      expect(page.hasNext, isFalse);
    });
  });

  group('pageDecoder', () {
    const parser = ResponseParser();

    test('decodes a PageResponse body into a page', () {
      final response = parser.parse(
        _pageBody(
          [
            {'id': 'a1', 'label': 'First'},
            {'id': 'a2', 'label': 'Second'},
          ],
          page: 0,
          size: 2,
          totalElements: 5,
          totalPages: 3,
        ),
        pageDecoder(TestItem.fromJson),
        statusCode: 200,
      );

      final page = response.data;
      expect(page, isA<PageResponse<TestItem>>());
      expect(page.items.map((item) => item.id), ['a1', 'a2']);
      expect(page.page, 0);
      expect(page.size, 2);
      expect(page.totalElements, 5);
      expect(page.totalPages, 3);
      expect(page.hasNext, isTrue);
      expect(() => page.items.add(page.items.first), throwsUnsupportedError);
    });

    test('decodes an empty page', () {
      final page = parser
          .parse(
            _pageBody(
              const [],
              page: 0,
              size: 20,
              totalElements: 0,
              totalPages: 0,
            ),
            pageDecoder(TestItem.fromJson),
            statusCode: 200,
          )
          .data;

      expect(page.items, isEmpty);
      expect(page.hasNext, isFalse);
    });

    test('a malformed PageResponse body is an invalid response', () {
      for (final body in <Object?>[
        {'page': 0, 'size': 20, 'totalElements': 0, 'totalPages': 0},
        {
          'items': 'a1',
          'page': 0,
          'size': 20,
          'totalElements': 1,
          'totalPages': 1,
        },
        {
          'items': const <Object?>[],
          'page': '0',
          'size': 20,
          'totalElements': 0,
          'totalPages': 0,
        },
        {'items': const <Object?>[], 'page': 0, 'size': 20},
        [
          {'id': 'a1', 'label': 'First'},
        ],
        {
          'items': [
            {'id': 1},
          ],
          'page': 0,
          'size': 20,
          'totalElements': 1,
          'totalPages': 1,
        },
      ]) {
        expect(
          () => parser.parse(
            body,
            pageDecoder(TestItem.fromJson),
            statusCode: 200,
          ),
          throwsInvalidResponse,
          reason: '$body',
        );
      }
    });
  });

  group('paging through the client', () {
    test('reads pages by number and stops after the last one', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson(
            _pageBody(
              [
                {'id': 'a1', 'label': 'First'},
              ],
              page: 0,
              size: 1,
              totalElements: 2,
              totalPages: 2,
            ),
          ),
          respondJson(
            _pageBody(
              [
                {'id': 'a2', 'label': 'Second'},
              ],
              page: 1,
              size: 1,
              totalElements: 2,
              totalPages: 2,
            ),
          ),
        ],
      );
      const first = PageRequest(size: 1);

      final page1 = (await harness.client.get(
        '/items',
        query: first.toQuery(),
        decode: pageDecoder(TestItem.fromJson),
      )).data;
      final second = first.next(page1)!;
      final page2 = (await harness.client.get(
        '/items',
        query: second.toQuery(),
        decode: pageDecoder(TestItem.fromJson),
      )).data;

      expect(page1.items.single.id, 'a1');
      expect(page1.hasNext, isTrue);
      expect(page2.items.single.id, 'a2');
      expect(page2.hasNext, isFalse);
      expect(first.next(page2), isNull);
      expect(harness.adapter.requests.first.uri.queryParameters, {
        'page': '0',
        'size': '1',
      });
      expect(harness.adapter.requests.last.uri.queryParameters, {
        'page': '1',
        'size': '1',
      });
    });

    test('a malformed page from the server is an invalid response', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson({'items': 'oops'}),
        ],
      );

      await expectLater(
        harness.client.get(
          '/items',
          query: const PageRequest().toQuery(),
          decode: pageDecoder(TestItem.fromJson),
        ),
        throwsInvalidResponse,
      );
    });
  });
}

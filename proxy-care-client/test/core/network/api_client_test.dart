import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/network/api_client.dart';
import 'package:proxy_care_client/core/network/api_response.dart';
import 'package:proxy_care_client/core/network/idempotency_key.dart';
import 'package:proxy_care_client/core/network/pagination.dart';
import 'package:proxy_care_client/core/network/request_options.dart';
import 'package:proxy_care_client/core/network/response_parser.dart';
import 'package:proxy_care_client/core/network/transfer.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/network_harness.dart';

/// A feature-agnostic DTO for decoding tests.
final class _Item {
  const _Item(this.id, this.label);

  factory _Item.fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    return _Item(map['id']! as String, map['label']! as String);
  }

  final String id;
  final String label;
}

Matcher get _invalidResponse => throwsA(
  isA<ServerException>().having(
    (e) => e.invalidResponse,
    'invalidResponse',
    isTrue,
  ),
);

void main() {
  group('ResponseParser', () {
    const parser = ResponseParser();

    test('decodes a single resource from data', () {
      final response = parser.parse(
        dataBody({'id': 'a1', 'label': 'First'}),
        _Item.fromJson,
        statusCode: 200,
      );

      expect(response, isA<ApiResponse<_Item>>());
      expect(response.data.label, 'First');
      expect(response.statusCode, 200);
      expect(response.page, isNull);
    });

    test('decodes a collection and its page metadata', () {
      final response = parser.parse(
        dataBody(
          [
            {'id': 'a1', 'label': 'First'},
            {'id': 'a2', 'label': 'Second'},
          ],
          page: pageMeta(nextCursor: 'c2', size: 2),
        ),
        listDecoder(_Item.fromJson),
        statusCode: 200,
      );

      expect(response.data.map((i) => i.id), ['a1', 'a2']);
      final page = response.page!;
      expect(page.nextCursor, 'c2');
      expect(page.hasMore, isTrue);
      expect(page.size, 2);
    });

    test('the last page has a null cursor', () {
      final response = parser.parse(
        dataBody(const <Object?>[], page: pageMeta()),
        listDecoder(_Item.fromJson),
        statusCode: 200,
      );

      expect(response.page!.nextCursor, isNull);
      expect(response.page!.hasMore, isFalse);
    });

    test('passes null data to a nullable decoder', () {
      final response = parser.parse<_Item?>(
        dataBody(null),
        (json) => json == null ? null : _Item.fromJson(json),
        statusCode: 200,
      );

      expect(response.data, isNull);
    });

    test('an empty body (204) decodes as null', () {
      for (final body in <Object?>[null, '', '  ']) {
        final response = parser.parse(body, ignoreBody, statusCode: 204);
        expect(response.statusCode, 204);
        expect(response.page, isNull);
      }
    });

    test('an empty body with a non-null decoder is an invalid response', () {
      expect(
        () => parser.parse(null, _Item.fromJson, statusCode: 204),
        _invalidResponse,
      );
    });

    test('a raw body goes to the decoder whole', () {
      final response = parser.parse(
        [
          {'id': 'a1', 'label': 'First'},
          {'id': 'a2', 'label': 'Second'},
        ],
        listDecoder(_Item.fromJson),
        statusCode: 200,
        format: ResponseFormat.raw,
      );

      expect(response.data.map((i) => i.id), ['a1', 'a2']);
      expect(response.page, isNull);
    });

    test('a body sent as text is still read', () {
      final response = parser.parse(
        jsonEncode(dataBody({'id': 'a1', 'label': 'First'})),
        _Item.fromJson,
        statusCode: 200,
      );

      expect(response.data.id, 'a1');
    });

    test('no longer requires or reads the old success envelope', () {
      final response = parser.parse(
        {
          'data': {'id': 'a1', 'label': 'First'},
        },
        _Item.fromJson,
        statusCode: 201,
      );

      expect(response.data.id, 'a1');
      expect(response.statusCode, 201);
    });

    test('a body without data is an invalid response', () {
      for (final body in <Object?>[
        {'id': 'a1'},
        {'success': true},
        [1, 2],
        'plain text',
      ]) {
        expect(
          () => parser.parse(body, _Item.fromJson, statusCode: 200),
          throwsA(isA<ServerException>()),
          reason: '$body',
        );
      }
    });

    test('a malformed page object is an invalid response', () {
      for (final page in <Object?>[
        'c2',
        {'nextCursor': 'c2'},
        {'nextCursor': 2, 'hasMore': true, 'size': 20},
        {'nextCursor': null, 'hasMore': 'no', 'size': 20},
      ]) {
        expect(
          () => parser.parse(
            {'data': const <Object?>[], 'page': page},
            listDecoder(_Item.fromJson),
            statusCode: 200,
          ),
          _invalidResponse,
          reason: '$page',
        );
      }
    });

    test('a data shape mismatch is a serialization failure', () {
      expect(
        () => parser.parse(
          dataBody({'id': 1}),
          _Item.fromJson,
          statusCode: 200,
        ),
        _invalidResponse,
      );
    });

    test('keeps headers by lower-case name and exposes ETag', () {
      final response = parser.parse(
        dataBody({'id': 'a1', 'label': 'First'}),
        _Item.fromJson,
        statusCode: 201,
        headers: {
          'ETag': ['"3"'],
          'Location': ['/api/v1/items/a1'],
        },
      );

      expect(response.etag, '"3"');
      expect(response.location, '/api/v1/items/a1');
      expect(response.header('etag'), '"3"');
      expect(response.header('X-Missing'), isNull);
      expect(
        () => response.headers['etag'] = const [],
        throwsUnsupportedError,
      );
    });
  });

  group('DioApiClient', () {
    test('GET with query parameters decodes the typed payload', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson(dataBody({'id': 'a1', 'label': 'First'})),
        ],
      );

      final response = await harness.client.get(
        '/items/a1',
        query: {'expand': 'details'},
        decode: _Item.fromJson,
      );

      expect(response.data.label, 'First');
      final sent = harness.adapter.requests.single;
      expect(sent.method, 'GET');
      expect(
        sent.uri.toString(),
        'https://api.proxycare.test/api/v1/items/a1?expand=details',
      );
      expect(
        sent.headers['Accept'],
        'application/json, application/problem+json',
      );
    });

    test('POST, PUT, PATCH and DELETE send JSON bodies', () async {
      final harness = NetworkHarness()
        ..adapter.fallback = respondJson(dataBody(null));
      const body = {'label': 'Updated'};

      await harness.client.post('/items', body: body, decode: ignoreBody);
      await harness.client.put('/items/a1', body: body, decode: ignoreBody);
      await harness.client.patch(
        '/items/a1',
        body: body,
        decode: ignoreBody,
      );
      await harness.client.delete('/items/a1', decode: ignoreBody);

      final requests = harness.adapter.requests;
      expect(requests.map((r) => r.method), [
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
      ]);
      for (final request in requests.take(3)) {
        expect(request.headers['content-type'], Headers.jsonContentType);
        expect(jsonDecode(utf8.decode(request.body!)), body);
      }
      expect(requests.last.body, isNull);
    });

    test('a 204 No Content succeeds with an ignored body', () async {
      final harness = NetworkHarness(
        responses: [(_) => ResponseBody.fromString('', 204)],
      );

      final response = await harness.client.delete(
        '/items/a1',
        decode: ignoreBody,
      );

      expect(response.statusCode, 204);
    });

    test('sends custom headers, idempotency keys and timeouts', () async {
      final harness = NetworkHarness(
        responses: [respondJson(dataBody(null))],
      );
      final key = IdempotencyKey.generate();

      await harness.client.post(
        '/bookings',
        body: const {'patientId': 'p1'},
        decode: ignoreBody,
        options: ApiRequestOptions(
          headers: const {'X-App-Version': '0.1.0'},
          idempotencyKey: key,
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 7),
        ),
      );

      final sent = harness.adapter.requests.single;
      expect(sent.headers['X-App-Version'], '0.1.0');
      expect(sent.headers['Idempotency-Key'], key);
      expect(sent.receiveTimeout, const Duration(seconds: 5));
      expect(sent.sendTimeout, const Duration(seconds: 7));
      expect(IdempotencyKey.generate(), isNot(key));
    });

    test('returns the ETag and sends it back as If-Match', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson(
            dataBody({'id': 'a1', 'label': 'First'}),
            headers: {
              'etag': ['"3"'],
            },
          ),
          respondJson(
            dataBody({'id': 'a1', 'label': 'Renamed'}),
            headers: {
              'etag': ['"4"'],
            },
          ),
        ],
      );

      final read = await harness.client.get(
        '/items/a1',
        decode: _Item.fromJson,
      );
      final updated = await harness.client.put(
        '/items/a1',
        body: const {'label': 'Renamed'},
        decode: _Item.fromJson,
        options: ApiRequestOptions(ifMatch: read.etag),
      );

      expect(read.etag, '"3"');
      expect(updated.etag, '"4"');
      final requests = harness.adapter.requests;
      expect(requests.first.headers.containsKey('If-Match'), isFalse);
      expect(requests.last.headers['If-Match'], '"3"');
    });

    test('a stale or missing If-Match maps to 412 / 428', () async {
      final harness = NetworkHarness(
        responses: [
          respondProblem('PRECONDITION_FAILED', status: 412),
          respondProblem('PRECONDITION_REQUIRED', status: 428),
        ],
      );

      await expectLater(
        harness.client.put(
          '/items/a1',
          decode: ignoreBody,
          options: const ApiRequestOptions(ifMatch: '"2"'),
        ),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 412)
              .having((e) => e.code, 'code', 'PRECONDITION_FAILED'),
        ),
      );
      await expectLater(
        harness.client.put('/items/a1', decode: ignoreBody),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 428),
        ),
      );
    });

    test(
      'problem details throw mapped AppExceptions, never Dio types',
      () async {
        final harness = NetworkHarness(
          responses: [
            respondProblem(
              'VALIDATION_ERROR',
              status: 422,
              errors: [fieldError('mobile', 'Enter 10 digits')],
              traceId: '4bf92f35',
            ),
          ],
        );

        await expectLater(
          harness.client.post('/users', body: const {}, decode: ignoreBody),
          throwsA(
            isA<ValidationException>()
                .having((e) => e.fieldErrors['mobile'], 'mobile', [
                  'Enter 10 digits',
                ])
                .having((e) => e.traceId, 'traceId', '4bf92f35')
                .having((e) => e.cause, 'cause', isA<DioException>()),
          ),
        );
      },
    );

    test('a 503 after every retry becomes a ServerException', () async {
      final harness = NetworkHarness()
        ..adapter.fallback = respondProblem(
          'SERVICE_UNAVAILABLE',
          status: 503,
        );

      await expectLater(
        harness.client.get('/items', decode: ignoreBody),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 503),
        ),
      );
      expect(harness.adapter.requests, hasLength(4));
    });

    test('a 429 exposes its Retry-After', () async {
      final harness = NetworkHarness(
        responses: [
          respondProblem(
            'RATE_LIMITED',
            status: 429,
            headers: {
              'Retry-After': ['30'],
            },
          ),
        ],
      );

      await expectLater(
        harness.client.post('/otp', decode: ignoreBody),
        throwsA(
          isA<ServerException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 30),
          ),
        ),
      );
    });

    test('cancellation stops the request with CancelledException', () async {
      final harness = NetworkHarness(
        responses: [respondJson(dataBody(null))],
      );
      final cancellation = RequestCancellation()..cancel();

      await expectLater(
        harness.client.get(
          '/items',
          decode: ignoreBody,
          options: ApiRequestOptions(cancellation: cancellation),
        ),
        throwsA(isA<CancelledException>()),
      );
      expect(cancellation.isCancelled, isTrue);
      expect(harness.adapter.requests, isEmpty);
      expect(harness.delays, isEmpty);
    });

    test('uploads files and fields as multipart/form-data', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson(dataBody({'id': 'f1', 'label': 'x'})),
        ],
      );
      final progress = <int>[];

      final response = await harness.client.upload(
        '/files',
        files: [
          UploadFile(
            field: 'file',
            bytes: Uint8List.fromList(utf8.encode('%PDF-1.7')),
            filename: 'bill.pdf',
            contentType: 'application/pdf',
          ),
        ],
        fields: const {'kind': 'HOSPITAL_BILL'},
        decode: _Item.fromJson,
        onProgress: (done, _) => progress.add(done),
      );

      expect(response.data.id, 'f1');
      final sent = harness.adapter.requests.single;
      expect(sent.method, 'POST');
      expect(
        sent.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      final form = sent.data! as FormData;
      expect(form.fields.single, isA<MapEntry<String, String>>());
      expect(form.fields.single.key, 'kind');
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'bill.pdf');
      expect(
        form.files.single.value.contentType.toString(),
        'application/pdf',
      );
      final text = utf8.decode(sent.body!, allowMalformed: true);
      expect(text, contains('name="kind"'));
      expect(text, contains('HOSPITAL_BILL'));
      expect(text, contains('filename="bill.pdf"'));
      expect(progress, isNotEmpty);
    });

    test('downloads bytes with content type and file name', () async {
      final harness = NetworkHarness(
        responses: [
          respondBytes(
            [37, 80, 68, 70],
            headers: {
              'content-type': ['application/pdf'],
              'content-disposition': ['attachment; filename="receipt.pdf"'],
            },
          ),
        ],
      );

      final file = await harness.client.download('/receipts/r1');

      expect(file.bytes, [37, 80, 68, 70]);
      expect(file.contentType, 'application/pdf');
      expect(file.filename, 'receipt.pdf');
    });
  });

  group('pagination', () {
    test('a page request becomes cursor and size query parameters', () {
      expect(const PageRequest().toQuery(), {'size': 20});
      expect(const PageRequest(cursor: 'c2', size: 50).toQuery(), {
        'size': 50,
        'cursor': 'c2',
      });
      expect(PageRequest.defaultSize, 20);
      expect(PageRequest.maxSize, 100);
    });

    test('reads a page from data and page.nextCursor / hasMore', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson(
            dataBody(
              [
                {'id': 'a1', 'label': 'First'},
              ],
              page: pageMeta(nextCursor: 'c2', size: 1),
            ),
          ),
          respondJson(
            dataBody(
              [
                {'id': 'a2', 'label': 'Second'},
              ],
              page: pageMeta(size: 1),
            ),
          ),
        ],
      );
      const first = PageRequest(size: 1);

      final page1 = CursorPage.fromResponse(
        await harness.client.get(
          '/items',
          query: first.toQuery(),
          decode: listDecoder(_Item.fromJson),
        ),
      );
      final second = first.next(page1)!;
      final page2 = CursorPage.fromResponse(
        await harness.client.get(
          '/items',
          query: second.toQuery(),
          decode: listDecoder(_Item.fromJson),
        ),
      );

      expect(page1.items.single.id, 'a1');
      expect(page1.hasMore, isTrue);
      expect(page1.nextCursor, 'c2');
      expect(harness.adapter.requests.first.uri.queryParameters, {
        'size': '1',
      });
      expect(harness.adapter.requests.last.uri.queryParameters, {
        'size': '1',
        'cursor': 'c2',
      });
      expect(page2.items.single.id, 'a2');
      expect(page2.hasMore, isFalse);
      expect(first.next(page2), isNull);
      expect(() => page1.items.add(page2.items.single), throwsUnsupportedError);
    });

    test('hasMore without a cursor is the last page', () {
      final page = CursorPage.fromResponse(
        const ApiResponse<List<int>>(
          data: [1],
          statusCode: 200,
          page: PageMetadata(hasMore: true, size: 20),
        ),
      );

      expect(page.hasMore, isFalse);
      expect(const PageRequest().next(page), isNull);
    });

    test('a collection response without page is an invalid response', () {
      expect(
        () => CursorPage.fromResponse(
          const ApiResponse<List<int>>(data: [1], statusCode: 200),
        ),
        _invalidResponse,
      );
    });
  });
}

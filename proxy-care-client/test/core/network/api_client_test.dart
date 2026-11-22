import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/error/backend_error_code.dart';
import 'package:proxy_care_client/core/network/api_client.dart';
import 'package:proxy_care_client/core/network/idempotency_key.dart';
import 'package:proxy_care_client/core/network/pagination.dart';
import 'package:proxy_care_client/core/network/request_options.dart';
import 'package:proxy_care_client/core/network/transfer.dart';

import '../../helpers/backend_api_error.dart';
import '../../helpers/decoding_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/network_harness.dart';

void main() {
  group('DioApiClient', () {
    test('GET with query parameters decodes the typed payload', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson({'id': 'a1', 'label': 'First'}),
        ],
      );

      final response = await harness.client.get(
        '/items/a1',
        query: {'expand': 'details'},
        decode: TestItem.fromJson,
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
        'application/json',
      );
    });

    test('GET decodes a bare JSON list body', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson([
            {'id': 'a1', 'label': 'First'},
            {'id': 'a2', 'label': 'Second'},
          ]),
        ],
      );

      final response = await harness.client.get(
        '/items',
        decode: listDecoder(TestItem.fromJson),
      );

      expect(response.data.map((item) => item.id), ['a1', 'a2']);
    });

    test('POST decodes a bare 201 body', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson({'id': 'a1', 'label': 'Created'}, status: 201),
        ],
      );

      final response = await harness.client.post(
        '/items',
        body: const {'label': 'Created'},
        decode: TestItem.fromJson,
      );

      expect(response.statusCode, 201);
      expect(response.data.label, 'Created');
    });

    test('a 401 ApiError from the filter chain is unauthorized', () async {
      final harness = NetworkHarness(
        responses: [
          respondApiError(
            'UNAUTHENTICATED',
            status: 401,
            message: 'Authentication required',
            headers: {
              'WWW-Authenticate': ['Bearer'],
            },
          ),
        ],
      );

      await expectLater(
        harness.client.get('/profile/me', decode: ignoreBody),
        throwsA(
          isA<UnauthorizedException>()
              .having(
                (e) => e.errorCode,
                'errorCode',
                BackendErrorCode.unauthenticated,
              )
              .having((e) => e.traceId, 'traceId', testTraceId),
        ),
      );
    });

    test('POST, PUT, PATCH and DELETE send JSON bodies', () async {
      final harness = NetworkHarness()
        ..adapter.fallback = respondJson(const <String, Object?>{});
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
        responses: [respondJson(const <String, Object?>{})],
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
            {'id': 'a1', 'label': 'First'},
            headers: {
              'etag': ['"3"'],
            },
          ),
          respondJson(
            {'id': 'a1', 'label': 'Renamed'},
            headers: {
              'etag': ['"4"'],
            },
          ),
        ],
      );

      final read = await harness.client.get(
        '/items/a1',
        decode: TestItem.fromJson,
      );
      final updated = await harness.client.put(
        '/items/a1',
        body: const {'label': 'Renamed'},
        decode: TestItem.fromJson,
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
          respondApiError(null, status: 412),
          respondApiError(null, status: 428),
        ],
      );

      await expectLater(
        harness.client.put(
          '/items/a1',
          decode: ignoreBody,
          options: const ApiRequestOptions(ifMatch: '"2"'),
        ),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 412),
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
      'an ApiError throws a mapped AppException, never a Dio type',
      () async {
        final harness = NetworkHarness(
          responses: [
            respondApiError(
              'VALIDATION_FAILED',
              status: 400,
              message: 'Validation failed',
              fieldErrors: {'mobile': 'Enter 10 digits'},
              traceId: '4bf92f35',
            ),
          ],
        );

        await expectLater(
          harness.client.post('/users', body: const {}, decode: ignoreBody),
          throwsA(
            isA<ValidationException>()
                .having(
                  (e) => e.errorCode,
                  'errorCode',
                  BackendErrorCode.validationFailed,
                )
                .having((e) => e.fieldErrors, 'fieldErrors', {
                  'mobile': 'Enter 10 digits',
                })
                .having((e) => e.traceId, 'traceId', '4bf92f35')
                .having((e) => e.cause, 'cause', isA<DioException>()),
          ),
        );
      },
    );

    test('a 503 after every retry becomes a ServerException', () async {
      final harness = NetworkHarness()
        ..adapter.fallback = respondApiError(
          'EXTERNAL_SERVICE_UNAVAILABLE',
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
          respondApiError(
            null,
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
        responses: [respondJson(const <String, Object?>{})],
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
          respondJson({'id': 'f1', 'label': 'x'}),
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
        decode: TestItem.fromJson,
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
}

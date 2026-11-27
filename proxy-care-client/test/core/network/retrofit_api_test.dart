import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/error/backend_error_code.dart';
import 'package:proxy_care_client/core/error/error_mapper.dart';
import 'package:proxy_care_client/core/error/repository_guard.dart';
import 'package:proxy_care_client/core/network/idempotency_key.dart';
import 'package:proxy_care_client/shared/models/result.dart';

import '../../fixtures/sample_api.dart';
import '../../helpers/backend_api_error.dart';
import '../../helpers/decoding_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/network_harness.dart';

/// The backend's controllers return their DTOs as bare JSON bodies (Spring
/// MVC `@RestController` return values; no success envelope), always as
/// `application/json`. These tests run a Retrofit API class
/// (`test/fixtures/sample_api.dart`) through the real Dio chain.
void main() {
  /// The `AppException` a repository's `guardResult` would make of the
  /// failure of [call].
  Future<AppException> failureOf(Future<Object?> Function() call) async {
    try {
      await call();
    } on DioException catch (error) {
      return const ErrorMapper().map(error);
    } on AppException catch (error) {
      return error;
    }
    fail('the call did not fail');
  }

  group('Retrofit API over the Dio chain', () {
    test('GET resolves under /api/v1 and decodes a bare JSON object', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson({'id': 'a1', 'name': 'First'}),
        ],
      );

      final response = await harness.api.get('a1');

      expect(response.data.name, 'First');
      final sent = harness.adapter.requests.single;
      expect(sent.method, 'GET');
      expect(sent.uri.toString(), 'https://api.proxycare.test/api/v1/items/a1');
      expect(sent.headers['Accept'], 'application/json');
    });

    test('GET decodes a bare JSON list body', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson([
            {'id': 'a1', 'name': 'First'},
            {'id': 'a2', 'name': 'Second'},
          ]),
        ],
      );

      final items = await harness.api.list();

      expect(items.map((item) => item.id), ['a1', 'a2']);
    });

    test('POST sends a JSON body and reads status and Location', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson(
            {'id': 'a1', 'name': 'Created'},
            status: 201,
            headers: {
              'location': ['/api/v1/items/a1'],
            },
          ),
        ],
      );

      final response = await harness.api.create(const {
        'name': 'Created',
      }, 'key-1');

      expect(response.response.statusCode, 201);
      expect(response.data.name, 'Created');
      expect(response.response.headers.value('location'), '/api/v1/items/a1');
      final sent = harness.adapter.requests.single;
      expect(sent.headers['content-type'], Headers.jsonContentType);
      expect(jsonDecode(utf8.decode(sent.body!)), {'name': 'Created'});
    });

    test('a 204 No Content succeeds for a void method', () async {
      final harness = NetworkHarness(
        responses: [(_) => ResponseBody.fromString('', 204)],
      );

      await harness.api.remove('a1');

      final sent = harness.adapter.requests.single;
      expect(sent.method, 'DELETE');
      expect(sent.body, isNull);
    });

    test('sends an idempotency key, one per logical operation', () async {
      final harness = NetworkHarness()
        ..adapter.fallback = respondJson({'id': 'a1', 'name': 'x'});
      final key = IdempotencyKey.generate();

      await harness.api.create(const {}, key);

      expect(harness.adapter.requests.single.headers['Idempotency-Key'], key);
      expect(IdempotencyKey.generate(), isNot(key));
    });

    test('returns the ETag and sends it back as If-Match', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson(
            {'id': 'a1', 'name': 'First'},
            headers: {
              'etag': ['"3"'],
            },
          ),
          respondJson({'id': 'a1', 'name': 'Renamed'}),
        ],
      );

      final read = await harness.api.get('a1');
      final etag = read.response.headers.value('etag')!;
      await harness.api.replace('a1', const {'name': 'Renamed'}, etag);

      expect(etag, '"3"');
      expect(read.response.headers.value('x-missing'), isNull);
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

      for (final status in [412, 428]) {
        final failure = await failureOf(
          () => harness.api.replace('a1', const {}, '"2"'),
        );
        expect(failure, isA<ServerException>());
        expect(failure.statusCode, status);
      }
    });
  });

  group('errors', () {
    test('a 401 ApiError is unauthorized', () async {
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

      final failure = await failureOf(harness.api.list);

      expect(
        failure,
        isA<UnauthorizedException>()
            .having(
              (e) => e.errorCode,
              'errorCode',
              BackendErrorCode.unauthenticated,
            )
            .having((e) => e.traceId, 'traceId', testTraceId),
      );
    });

    test('an ApiError maps with its field errors and trace ID', () async {
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

      final failure = await failureOf(
        () => harness.api.create(const {}, 'key-1'),
      );

      expect(
        failure,
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
      );
    });

    test('guardResult turns an ApiError into a Failure result', () async {
      final harness = NetworkHarness(
        responses: [respondApiError('VALIDATION_FAILED', status: 400)],
      );

      final result = await guardResult(() => harness.api.list());

      expect(result, isA<Failure<List<ItemDto>>>());
    });

    test('a 503 after every retry becomes a ServerException', () async {
      final harness = NetworkHarness()
        ..adapter.fallback = respondApiError(
          'EXTERNAL_SERVICE_UNAVAILABLE',
          status: 503,
        );

      final failure = await failureOf(harness.api.list);

      expect(failure, isA<ServerException>());
      expect(failure.statusCode, 503);
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

      final failure = await failureOf(
        () => harness.api.create(const {}, 'key-1'),
      );

      expect(
        failure,
        isA<ServerException>().having(
          (e) => e.retryAfter,
          'retryAfter',
          const Duration(seconds: 30),
        ),
      );
    });
  });

  group('response bodies that do not match their DTO', () {
    test('a field of the wrong type is an invalid response', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson({'id': 1}),
        ],
      );

      await expectLater(harness.api.get('a1'), throwsInvalidResponse);
    });

    test('an object where a list is expected is an invalid response', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson({'id': 'a1', 'name': 'x'}),
        ],
      );

      final failure = await failureOf(harness.api.list);

      expect((failure as ServerException).invalidResponse, isTrue);
    });

    test('a non-JSON text body is an invalid response', () async {
      for (final body in ['<html><body>OK</body></html>', 'OK']) {
        final harness = NetworkHarness(
          responses: [respondText(body, contentType: 'text/html')],
        );

        final failure = await failureOf(() => harness.api.get('a1'));

        expect(
          (failure as ServerException).invalidResponse,
          isTrue,
          reason: body,
        );
      }
    });

    test('an empty body where a DTO is expected is an invalid response', () {
      final harness = NetworkHarness(
        responses: [(_) => ResponseBody.fromString('', 204)],
      );

      return expectLater(harness.api.get('a1'), throwsInvalidResponse);
    });

    test('a JSON content type with a broken body is an invalid one', () async {
      final harness = NetworkHarness(
        responses: [
          respondText('{"id":', contentType: Headers.jsonContentType),
        ],
      );

      final failure = await failureOf(() => harness.api.get('a1'));

      expect(failure, isA<ServerException>());
      expect((failure as ServerException).invalidResponse, isTrue);
    });

    test('guardResult returns a Failure instead of throwing', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson({'id': 1}),
        ],
      );

      final result = await guardResult(() => harness.api.get('a1'));

      expect(result, isA<Failure<Object?>>());
    });

    test('a TypeError outside decoding stays a programming error', () {
      expect(
        () => guardResult<void>(() => throw TypeError()),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('per-request switches and retry', () {
    test('a failed GET is retried, a failed POST is not', () async {
      final harness = NetworkHarness(
        responses: [
          respondApiError('EXTERNAL_SERVICE_UNAVAILABLE', status: 503),
          respondJson(const <Object?>[]),
          respondApiError('EXTERNAL_SERVICE_UNAVAILABLE', status: 503),
        ],
      );

      expect(await harness.api.list(), isEmpty);
      expect(harness.adapter.requests, hasLength(2));

      await expectLater(
        harness.api.create(const {}, 'key-1'),
        throwsA(isA<DioException>()),
      );
      expect(harness.adapter.requests, hasLength(3));
    });

    test('skipAuth sends no token', () async {
      final harness = NetworkHarness(
        responses: [respondJson(const <String, Object?>{})],
        tokens: FakeTokens(token: 'access-1'),
      );

      await harness.api.signIn(const {});

      expect(
        harness.adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('a cancelled request fails with CancelledException', () async {
      final harness = NetworkHarness(
        responses: [respondJson(const <String, Object?>{})],
      );
      final token = CancelToken()..cancel();

      final failure = await failureOf(() => harness.api.slow(token));

      expect(failure, isA<CancelledException>());
      expect(harness.adapter.requests, isEmpty);
    });
  });

  group('transfers', () {
    test('uploads a file and fields as multipart/form-data', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson({'id': 'f1', 'name': 'x'}),
        ],
      );
      final progress = <int>[];

      final item = await harness.api.uploadPhoto(
        'a1',
        MultipartFile.fromBytes(
          utf8.encode('%PDF-1.7'),
          filename: 'bill.pdf',
          contentType: DioMediaType.parse('application/pdf'),
        ),
        'HOSPITAL_BILL',
        (done, _) => progress.add(done),
        null,
      );

      expect(item.id, 'f1');
      final sent = harness.adapter.requests.single;
      expect(sent.method, 'POST');
      expect(sent.uri.path, '/api/v1/items/a1/photo');
      expect(
        sent.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      final text = utf8.decode(sent.body!, allowMalformed: true);
      expect(text, contains('name="caption"'));
      expect(text, contains('HOSPITAL_BILL'));
      expect(text, contains('filename="bill.pdf"'));
      expect(progress, isNotEmpty);
    });

    test('downloads bytes with their headers', () async {
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

      final file = await harness.api.report('r1', null);

      expect(file.data, [37, 80, 68, 70]);
      expect(file.response.headers.value('content-type'), 'application/pdf');
      expect(
        file.response.headers.value('content-disposition'),
        'attachment; filename="receipt.pdf"',
      );
    });
  });
}

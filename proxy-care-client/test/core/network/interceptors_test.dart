import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/network/api_client.dart';
import 'package:proxy_care_client/core/network/interceptors/logging_interceptor.dart';
import 'package:proxy_care_client/core/network/public_endpoints.dart';
import 'package:proxy_care_client/core/network/request_options.dart';
import 'package:proxy_care_client/core/network/request_replay.dart';
import 'package:proxy_care_client/core/network/transfer.dart';
import 'package:proxy_care_client/core/security/redactor.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/network_harness.dart';

FakeResponder _ok() => respondJson(dataBody(null));

FakeResponder _status(int status) =>
    respondProblem('INTERNAL_ERROR', status: status);

void main() {
  group('AuthInterceptor', () {
    test('attaches the bearer token', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'access-1'),
        responses: [_ok()],
      );

      await harness.client.get('/me', decode: ignoreBody);

      expect(
        harness.adapter.requests.single.headers['Authorization'],
        'Bearer access-1',
      );
    });

    test('sends no header when there is no token', () async {
      final harness = NetworkHarness(responses: [_ok()]);

      await harness.client.get('/me', decode: ignoreBody);

      expect(
        harness.adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('skipAuth sends no token, even a caller-supplied one', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'access-1'),
        responses: [_ok()],
      );

      await harness.client.post(
        '/anything',
        decode: ignoreBody,
        options: const ApiRequestOptions(
          skipAuth: true,
          headers: {'Authorization': 'Bearer leaked'},
        ),
      );

      expect(
        harness.adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('configured public endpoints get no token', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'access-1'),
        publicEndpoints: const PublicEndpoints([
          '/api/v1/status',
          '/api/v1/public/',
        ]),
        responses: [_ok(), _ok(), _ok()],
      );

      await harness.client.get('/status', decode: ignoreBody);
      await harness.client.get('/public/config', decode: ignoreBody);
      await harness.client.get('/status/details', decode: ignoreBody);

      final auth = [
        for (final r in harness.adapter.requests) r.headers['Authorization'],
      ];
      expect(auth, [null, null, 'Bearer access-1']);
    });

    test('a token is never sent to another origin', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'access-1'),
        responses: [_ok()],
      );

      await harness.client.get(
        'https://third-party.example/v1/x',
        decode: ignoreBody,
      );

      expect(
        harness.adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('a 401 recovers a token and replays once with the newest', () async {
      final tokens = FakeTokens(token: 'old', recovered: 'new');
      final harness = NetworkHarness(
        tokens: tokens,
        responses: [_status(401), _ok()],
      );

      await harness.client.get(
        '/me',
        query: {'expand': 'roles'},
        decode: ignoreBody,
        options: const ApiRequestOptions(headers: {'X-App-Version': '1'}),
      );

      expect(tokens.recoveries, ['old']);
      final requests = harness.adapter.requests;
      expect(requests, hasLength(2));
      expect(requests.last.headers['Authorization'], 'Bearer new');
      expect(requests.last.headers['X-App-Version'], '1');
      expect(requests.last.uri.queryParameters, {'expand': 'roles'});
      expect(
        requests.last.headers['X-Correlation-Id'],
        requests.first.headers['X-Correlation-Id'],
      );
    });

    test('a newer token already held by the provider is reused', () async {
      // The provider refreshed meanwhile; recovery hands back that token.
      final tokens = FakeTokens(token: 'old', recovered: 'already-new');
      final harness = NetworkHarness(
        tokens: tokens,
        responses: [_status(401), _ok()],
      );

      await harness.client.get('/me', decode: ignoreBody);

      expect(
        harness.adapter.requests.last.headers['Authorization'],
        'Bearer already-new',
      );
      expect(tokens.recoveries, hasLength(1));
    });

    test('no better token: the 401 becomes UnauthorizedException', () async {
      final tokens = FakeTokens(token: 'old');
      final harness = NetworkHarness(
        tokens: tokens,
        responses: [_status(401)],
      );

      await expectLater(
        harness.client.get('/me', decode: ignoreBody),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(tokens.recoveries, hasLength(1));
      expect(harness.adapter.requests, hasLength(1));
    });

    test('a recovery that returns the same token does not replay', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'old', recovered: 'old'),
        responses: [_status(401)],
      );

      await expectLater(
        harness.client.get('/me', decode: ignoreBody),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(harness.adapter.requests, hasLength(1));
    });

    test('a failing recovery keeps the original 401', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'old', recoveryError: StateError('x')),
        responses: [_status(401)],
      );

      await expectLater(
        harness.client.get('/me', decode: ignoreBody),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('a second 401 after replaying is final (no loop)', () async {
      final tokens = FakeTokens(token: 'old', recovered: 'new');
      final harness = NetworkHarness(
        tokens: tokens,
        responses: [_status(401), _status(401)],
      );

      await expectLater(
        harness.client.get('/me', decode: ignoreBody),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(tokens.recoveries, hasLength(1));
      expect(harness.adapter.requests, hasLength(2));
    });

    test('a 401 without a token, or with skipAuth, is not recovered', () async {
      final tokens = FakeTokens(recovered: 'new');
      final harness = NetworkHarness(
        tokens: tokens,
        responses: [_status(401), _status(401)],
      );

      await expectLater(
        harness.client.get('/me', decode: ignoreBody),
        throwsA(isA<UnauthorizedException>()),
      );
      tokens.token = 'old';
      await expectLater(
        harness.client.post(
          '/anything',
          decode: ignoreBody,
          options: const ApiRequestOptions(skipAuth: true),
        ),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(tokens.recoveries, isEmpty);
    });

    test('a 403 is neither recovered nor retried', () async {
      final tokens = FakeTokens(token: 'old', recovered: 'new');
      final harness = NetworkHarness(
        tokens: tokens,
        responses: [_status(403)],
      );

      await expectLater(
        harness.client.get('/me', decode: ignoreBody),
        throwsA(isA<ForbiddenException>()),
      );
      expect(tokens.recoveries, isEmpty);
      expect(harness.adapter.requests, hasLength(1));
      expect(harness.delays, isEmpty);
    });

    test('a JSON body and idempotency key are replayed as sent', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'old', recovered: 'new'),
        responses: [_status(401), _ok()],
      );

      await harness.client.post(
        '/items',
        body: const {'label': 'x'},
        decode: ignoreBody,
        options: const ApiRequestOptions(idempotencyKey: 'key-1'),
      );

      final requests = harness.adapter.requests;
      expect(requests, hasLength(2));
      expect(requests.last.body, requests.first.body);
      expect(requests.last.headers['Idempotency-Key'], 'key-1');
    });

    test('a multipart body is recreated for the replay', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'old', recovered: 'new'),
        responses: [_status(401), _ok()],
      );

      await harness.client.upload(
        '/files',
        files: [
          UploadFile(
            field: 'file',
            bytes: Uint8List.fromList([1, 2, 3]),
            filename: 'a.bin',
          ),
        ],
        decode: ignoreBody,
      );

      final requests = harness.adapter.requests;
      expect(requests, hasLength(2));
      expect(requests.last.data, isNot(same(requests.first.data)));
      expect(requests.last.body!.length, requests.first.body!.length);
    });

    test('a consumed stream body is not replayed', () async {
      final tokens = FakeTokens(token: 'old', recovered: 'new');
      final harness = NetworkHarness(
        tokens: tokens,
        responses: [_status(401)],
      );

      await expectLater(
        harness.client.post(
          '/stream',
          body: Stream<List<int>>.value([1, 2, 3]),
          decode: ignoreBody,
          options: const ApiRequestOptions(
            headers: {'content-length': '3'},
          ),
        ),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(harness.adapter.requests, hasLength(1));
    });
  });

  group('prepareForReplay', () {
    test('accepts JSON values and bytes, rejects streams', () {
      for (final data in <Object?>[
        null,
        const {'a': 1},
        const [1],
        'text',
        3,
        true,
        Uint8List(2),
      ]) {
        expect(
          prepareForReplay(RequestOptions(path: '/', data: data)),
          isTrue,
          reason: '$data',
        );
      }
      expect(
        prepareForReplay(
          RequestOptions(path: '/', data: Stream<List<int>>.value([1])),
        ),
        isFalse,
      );
    });

    test('clones multipart bodies', () {
      final form = FormData.fromMap({'a': 'b'});
      final options = RequestOptions(path: '/', data: form);

      expect(prepareForReplay(options), isTrue);
      expect(options.data, isA<FormData>());
      expect(options.data, isNot(same(form)));
    });
  });

  group('RetryInterceptor', () {
    test('retries a GET up to three times with exponential backoff', () async {
      final harness = NetworkHarness(
        responses: [
          for (var i = 0; i < 4; i++)
            failWith(DioExceptionType.connectionError),
        ],
      );

      await expectLater(
        harness.client.get('/visits', decode: ignoreBody),
        throwsA(isA<NetworkException>()),
      );

      expect(harness.adapter.requests, hasLength(4), reason: '1 + 3 retries');
      expect(harness.delays, const [
        Duration(milliseconds: 500),
        Duration(seconds: 1),
        Duration(seconds: 2),
      ]);
    });

    for (final status in [502, 503, 504]) {
      test('retries a GET on $status and stops once it succeeds', () async {
        final harness = NetworkHarness(
          responses: [_status(status), _status(status), _ok()],
        );

        await harness.client.get('/visits', decode: ignoreBody);

        expect(harness.adapter.requests, hasLength(3));
      });
    }

    test('retries a connection timeout', () async {
      final harness = NetworkHarness(
        responses: [failWith(DioExceptionType.connectionTimeout), _ok()],
      );

      await harness.client.get('/visits', decode: ignoreBody);

      expect(harness.adapter.requests, hasLength(2));
    });

    for (final (status, code) in [
      (429, 'RATE_LIMITED'),
      (503, 'SERVICE_UNAVAILABLE'),
    ]) {
      test('waits out Retry-After on a $status before retrying', () async {
        final harness = NetworkHarness(
          responses: [
            respondProblem(
              code,
              status: status,
              headers: {
                'Retry-After': ['3'],
              },
            ),
            _ok(),
          ],
        );

        await harness.client.get('/visits', decode: ignoreBody);

        expect(harness.adapter.requests, hasLength(2));
        expect(harness.delays, const [Duration(seconds: 3)]);
      });
    }

    test('a Retry-After shorter than the backoff keeps the backoff', () async {
      final harness = NetworkHarness(
        responses: [
          respondProblem(
            'SERVICE_UNAVAILABLE',
            status: 503,
            headers: {
              'Retry-After': ['0'],
            },
          ),
          _ok(),
        ],
      );

      await harness.client.get('/visits', decode: ignoreBody);

      expect(harness.delays, const [Duration(milliseconds: 500)]);
    });

    test('a Retry-After beyond the limit is returned, not waited', () async {
      final harness = NetworkHarness(
        responses: [
          respondProblem(
            'RATE_LIMITED',
            status: 429,
            headers: {
              'Retry-After': ['120'],
            },
          ),
        ],
      );

      await expectLater(
        harness.client.get('/visits', decode: ignoreBody),
        throwsA(
          isA<ServerException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(minutes: 2),
          ),
        ),
      );
      expect(harness.adapter.requests, hasLength(1));
      expect(harness.delays, isEmpty);
    });

    test('Retry-After does not make a write retryable', () async {
      final harness = NetworkHarness(
        responses: [
          respondProblem(
            'SERVICE_UNAVAILABLE',
            status: 503,
            headers: {
              'Retry-After': ['1'],
            },
          ),
        ],
      );

      await expectLater(
        harness.client.post('/payments', decode: ignoreBody),
        throwsA(isA<ServerException>()),
      );
      expect(harness.adapter.requests, hasLength(1));
    });

    for (final status in [400, 401, 404, 409, 412, 428, 429, 500]) {
      test('does not retry HTTP $status', () async {
        final harness = NetworkHarness(responses: [_status(status)]);

        await expectLater(
          harness.client.get('/visits', decode: ignoreBody),
          throwsA(isA<AppException>()),
        );
        expect(harness.adapter.requests, hasLength(1));
      });
    }

    test('does not retry a receive timeout', () async {
      final harness = NetworkHarness(
        responses: [failWith(DioExceptionType.receiveTimeout)],
      );

      await expectLater(
        harness.client.get('/visits', decode: ignoreBody),
        throwsA(isA<TimeoutException>()),
      );
      expect(harness.adapter.requests, hasLength(1));
    });

    for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
      test('does not retry $method by default', () async {
        final harness = NetworkHarness(responses: [_status(503)]);

        final call = switch (method) {
          'POST' => harness.client.post('/x', decode: ignoreBody),
          'PUT' => harness.client.put('/x', decode: ignoreBody),
          'PATCH' => harness.client.patch('/x', decode: ignoreBody),
          _ => harness.client.delete('/x', decode: ignoreBody),
        };
        await expectLater(call, throwsA(isA<ServerException>()));
        expect(harness.adapter.requests, hasLength(1));
      });
    }

    test('retries a write when the request opts in', () async {
      final harness = NetworkHarness(responses: [_status(503), _ok()]);

      await harness.client.post(
        '/payments',
        decode: ignoreBody,
        options: const ApiRequestOptions(
          retry: RetryPolicy.always,
          idempotencyKey: 'key-1',
        ),
      );

      final requests = harness.adapter.requests;
      expect(requests, hasLength(2));
      expect(requests.last.headers['Idempotency-Key'], 'key-1');
    });

    test('respects a request that disables retries', () async {
      final harness = NetworkHarness(responses: [_status(503)]);

      await expectLater(
        harness.client.get(
          '/visits',
          decode: ignoreBody,
          options: const ApiRequestOptions(retry: RetryPolicy.never),
        ),
        throwsA(isA<ServerException>()),
      );
      expect(harness.adapter.requests, hasLength(1));
    });

    test('respects a request-specific retry limit', () async {
      final harness = NetworkHarness(
        responses: [_status(503), _status(503), _status(503)],
      );

      await expectLater(
        harness.client.get(
          '/visits',
          decode: ignoreBody,
          options: const ApiRequestOptions(retry: RetryPolicy(maxRetries: 1)),
        ),
        throwsA(isA<ServerException>()),
      );
      expect(harness.adapter.requests, hasLength(2));
    });

    test('never retries a cancelled request', () async {
      final harness = NetworkHarness(
        responses: [failWith(DioExceptionType.cancel)],
      );

      await expectLater(
        harness.client.get('/visits', decode: ignoreBody),
        throwsA(isA<CancelledException>()),
      );
      expect(harness.adapter.requests, hasLength(1));
      expect(harness.delays, isEmpty);
    });

    test('keeps one correlation ID across retries and logs each try', () async {
      final harness = NetworkHarness(
        responses: [_status(503), _status(502), _ok()],
      );

      await harness.client.get('/visits', decode: ignoreBody);

      final ids = harness.adapter.requests
          .map((r) => r.headers['X-Correlation-Id'])
          .toSet();
      expect(ids, hasLength(1));
      expect(harness.logs, hasLength(3), reason: 'no duplicated lines');
      expect(harness.logs[1], contains('(retry 1)'));
      expect(harness.logs[2], contains('(retry 2)'));
    });

    test('an auth replay that hits a 503 is retried, once per loop', () async {
      final tokens = FakeTokens(token: 'old', recovered: 'new');
      final harness = NetworkHarness(
        tokens: tokens,
        responses: [_status(401), _status(503), _ok()],
      );

      await harness.client.get('/me', decode: ignoreBody);

      expect(harness.adapter.requests, hasLength(3));
      expect(tokens.recoveries, hasLength(1));
    });

    test('a POST that cannot be replayed is not retried', () async {
      final harness = NetworkHarness(responses: [_status(503)]);

      await expectLater(
        harness.client.post(
          '/stream',
          body: Stream<List<int>>.value([1]),
          decode: ignoreBody,
          options: const ApiRequestOptions(
            retry: RetryPolicy.always,
            headers: {'content-length': '1'},
          ),
        ),
        throwsA(isA<ServerException>()),
      );
      expect(harness.adapter.requests, hasLength(1));
    });
  });

  group('CorrelationIdInterceptor', () {
    test('generates a UUID v4 per logical request', () async {
      final harness = NetworkHarness(responses: [_ok(), _ok()]);

      await harness.client.get('/a', decode: ignoreBody);
      await harness.client.get('/b', decode: ignoreBody);

      final ids = [
        for (final r in harness.adapter.requests)
          r.headers['X-Correlation-Id']! as String,
      ];
      expect(ids.toSet(), hasLength(2));
      for (final id in ids) {
        expect(
          id,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
              r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
      }
    });

    test('propagates an ID supplied by the caller', () async {
      final harness = NetworkHarness(responses: [_ok()]);

      await harness.client.get(
        '/a',
        decode: ignoreBody,
        options: const ApiRequestOptions(
          headers: {'X-Correlation-Id': 'abc-123'},
        ),
      );

      expect(
        harness.adapter.requests.single.headers['X-Correlation-Id'],
        'abc-123',
      );
    });
  });

  group('LoggingInterceptor', () {
    test('logs method, path, status and duration only', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'secret-token'),
        responses: [
          respondJson(
            dataBody({'patientName': 'Kamla Devi', 'age': 72}),
          ),
        ],
      );

      await harness.client.get(
        '/patients',
        query: {'name': 'Kamla'},
        decode: ignoreBody,
      );

      final line = harness.logs.single;
      expect(
        line,
        matches(
          RegExp(r'^GET /api/v1/patients \[[0-9a-f-]{36}\] → 200 in \d+ ms$'),
        ),
      );
      for (final secret in ['secret-token', 'Kamla', 'api.proxycare']) {
        expect(line, isNot(contains(secret)), reason: secret);
      }
    });

    test('logs failures with their status or type', () async {
      final harness = NetworkHarness(
        responses: [failWith(DioExceptionType.receiveTimeout)],
      );

      await expectLater(
        harness.client.get('/visits', decode: ignoreBody),
        throwsA(isA<TimeoutException>()),
      );

      expect(harness.logs.single, contains('→ receiveTimeout'));
    });

    test('detailed logs mask secrets and show only query names', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'secret-token'),
        detailedLogging: true,
        responses: [_ok()],
      );

      await harness.client.get(
        '/patients',
        query: {'mobile': '9876543210'},
        decode: ignoreBody,
        options: const ApiRequestOptions(
          headers: {'X-Api-Key': 'k-123', 'Cookie': 'session=1'},
        ),
      );

      final all = harness.logs.join('\n');
      expect(all, contains('query: mobile'));
      for (final secret in ['9876543210', 'k-123', 'session=1']) {
        expect(all, isNot(contains(secret)), reason: secret);
      }
    });

    test('the token is attached after logging, so it is never logged', () {
      // Logging runs before AuthInterceptor in the request phase.
      final lines = <String>[];
      final interceptor = LoggingInterceptor(log: lines.add, detailed: true);
      final options = RequestOptions(
        path: '/me',
        headers: {'Authorization': 'Bearer abc'},
      );

      interceptor.onRequest(options, RequestInterceptorHandler());

      expect(lines.single, contains('Authorization: ***'));
      expect(lines.single, isNot(contains('abc')));
    });

    test('measures duration with the injected clock', () {
      var now = DateTime(2026, 11, 14, 10);
      final lines = <String>[];
      final interceptor = LoggingInterceptor(log: lines.add, clock: () => now);
      final options = RequestOptions(path: '/me', method: 'GET');

      interceptor.onRequest(options, RequestInterceptorHandler());
      now = now.add(const Duration(milliseconds: 182));
      interceptor.onResponse(
        Response<Object?>(requestOptions: options, statusCode: 200),
        ResponseInterceptorHandler(),
      );

      expect(lines.single, 'GET /me → 200 in 182 ms');
    });
  });

  group('Redactor', () {
    const redactor = Redactor();

    test('masks credentials and personal fields at any depth', () {
      final redacted = redactor.json({
        'bookingId': 'PC-2481',
        'password': 'p',
        'refresh_token': 't',
        'patient': {'name': 'Kamla', 'healthNotes': 'diabetic'},
        'items': [
          {'aadhaarNumber': '1234', 'amount': 500},
        ],
      });

      expect(redacted, {
        'bookingId': 'PC-2481',
        'password': '***',
        'refresh_token': '***',
        'patient': '***',
        'items': [
          {'aadhaarNumber': '***', 'amount': 500},
        ],
      });
    });

    test('masks sensitive headers', () {
      expect(
        redactor.headers({
          'Authorization': 'Bearer x',
          'Accept': 'application/json',
          'X-Refresh-Token': 'y',
        }),
        {
          'Authorization': '***',
          'Accept': 'application/json',
          'X-Refresh-Token': '***',
        },
      );
    });

    test('accepts extra sensitive names', () {
      const custom = Redactor(extraSensitiveKeys: ['ward']);
      expect(custom.isSensitive('wardNumber'), isTrue);
      expect(redactor.isSensitive('wardNumber'), isFalse);
    });
  });
}

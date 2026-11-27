import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/network/interceptors/logging_interceptor.dart';
import 'package:proxy_care_client/core/network/network_config.dart';
import 'package:proxy_care_client/core/network/public_endpoints.dart';
import 'package:proxy_care_client/core/security/redactor.dart';

import '../../helpers/backend_api_error.dart';
import '../../helpers/dio_probe.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/network_harness.dart';

FakeResponder _ok() => respondJson(const <String, Object?>{});

/// The backend `ErrorCode` sent with [status]; null where the backend has
/// none (412, 428, 429).
String? _backendCode(int status) => switch (status) {
  400 => 'VALIDATION_FAILED',
  401 => 'UNAUTHENTICATED',
  403 => 'ACCESS_DENIED',
  404 => 'RESOURCE_NOT_FOUND',
  409 => 'RESOURCE_ALREADY_EXISTS',
  500 => 'INTERNAL_ERROR',
  502 => 'EXTERNAL_SERVICE_ERROR',
  503 => 'EXTERNAL_SERVICE_UNAVAILABLE',
  _ => null,
};

FakeResponder _status(int status) =>
    respondApiError(_backendCode(status), status: status);

void main() {
  group('AuthInterceptor', () {
    test('attaches the bearer token', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'access-1'),
        responses: [_ok()],
      );

      await harness.client.get('/me');

      expect(
        harness.adapter.requests.single.headers['Authorization'],
        'Bearer access-1',
      );
    });

    test('reads the token again for every request', () async {
      final tokens = FakeTokens(token: 'access-1');
      final harness = NetworkHarness(
        tokens: tokens,
        responses: [_ok(), _ok()],
      );

      await harness.client.get('/me');
      tokens.token = 'access-2';
      await harness.client.get('/me');

      expect(harness.adapter.requests.map((r) => r.headers['Authorization']), [
        'Bearer access-1',
        'Bearer access-2',
      ]);
    });

    test('sends no header when there is no token', () async {
      final harness = NetworkHarness(responses: [_ok()]);

      await harness.client.get('/me');

      expect(
        harness.adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('sends no header for an empty token', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: ''),
        responses: [_ok()],
      );

      await harness.client.get('/me');

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
        options: const CallOptions(
          skipAuth: true,
          headers: {'Authorization': 'Bearer leaked'},
        ),
      );

      expect(
        harness.adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('a caller-supplied Authorization header is replaced', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'access-1'),
        responses: [_ok()],
      );

      await harness.client.get(
        '/me',
        options: const CallOptions(
          headers: {'Authorization': 'Bearer caller'},
        ),
      );

      expect(
        harness.adapter.requests.single.headers['Authorization'],
        'Bearer access-1',
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

      await harness.client.get('/status');
      await harness.client.get('/public/config');
      await harness.client.get('/status/details');

      final auth = [
        for (final r in harness.adapter.requests) r.headers['Authorization'],
      ];
      expect(auth, [null, null, 'Bearer access-1']);
    });

    test('a 401 is not recovered or repeated', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'old'),
        responses: [_status(401)],
      );

      await expectLater(
        harness.client.get('/me'),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(harness.adapter.requests, hasLength(1));
    });

    test('a 403 is neither recovered nor retried', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'old'),
        responses: [_status(403)],
      );

      await expectLater(
        harness.client.get('/me'),
        throwsA(isA<ForbiddenException>()),
      );
      expect(harness.adapter.requests, hasLength(1));
    });

    test('a token that cannot be read fails the request unsent', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(error: StateError('storage unavailable')),
        responses: [_ok()],
      );

      await expectLater(
        harness.client.get('/me'),
        throwsA(isA<UnknownException>()),
      );
      expect(harness.adapter.requests, isEmpty);
    });
  });

  group('retry (dio_smart_retry)', () {
    test('retries a GET up to three times on a connection error', () async {
      final harness = NetworkHarness(
        responses: [
          for (var i = 0; i < 4; i++)
            failWith(DioExceptionType.connectionError),
        ],
      );

      await expectLater(
        harness.client.get('/visits'),
        throwsA(isA<NetworkException>()),
      );

      expect(harness.adapter.requests, hasLength(4), reason: '1 + 3 retries');
    });

    test('waits 0.5 s, 1 s and 2 s between retries by default', () {
      expect(NetworkConfig.maxRetries, 3);
      expect(NetworkConfig.retryDelays, const [
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

        await harness.client.get('/visits');

        expect(harness.adapter.requests, hasLength(3));
      });
    }

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      test('retries a GET after a ${type.name}', () async {
        final harness = NetworkHarness(responses: [failWith(type), _ok()]);

        await harness.client.get('/visits');

        expect(harness.adapter.requests, hasLength(2));
      });
    }

    test('a 503 after every retry becomes a ServerException', () async {
      final harness = NetworkHarness()..adapter.fallback = _status(503);

      await expectLater(
        harness.client.get('/visits'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 503),
        ),
      );
      expect(harness.adapter.requests, hasLength(4));
    });

    for (final status in [400, 401, 403, 404, 409, 412, 428, 429, 500]) {
      test('does not retry HTTP $status', () async {
        final harness = NetworkHarness(responses: [_status(status)]);

        await expectLater(
          harness.client.get('/visits'),
          throwsA(isA<AppException>()),
        );
        expect(harness.adapter.requests, hasLength(1));
      });
    }

    test('does not retry a cancelled request', () async {
      final harness = NetworkHarness(
        responses: [failWith(DioExceptionType.cancel)],
      );

      await expectLater(
        harness.client.get('/visits'),
        throwsA(isA<CancelledException>()),
      );
      expect(harness.adapter.requests, hasLength(1));
    });

    test('does not wait for Retry-After: a 503 is retried as usual', () async {
      final harness = NetworkHarness(
        responses: [
          respondApiError(
            'EXTERNAL_SERVICE_UNAVAILABLE',
            status: 503,
            headers: {
              'Retry-After': ['3'],
            },
          ),
          _ok(),
        ],
      );

      await harness.client.get('/visits');

      expect(harness.adapter.requests, hasLength(2));
    });

    test('a 429 is not retried and exposes its Retry-After', () async {
      final harness = NetworkHarness(
        responses: [
          respondApiError(
            null,
            status: 429,
            headers: {
              'Retry-After': ['120'],
            },
          ),
        ],
      );

      await expectLater(
        harness.client.get('/visits'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(minutes: 2),
          ),
        ),
      );
      expect(harness.adapter.requests, hasLength(1));
    });

    for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
      test('never retries $method on a 503', () async {
        final harness = NetworkHarness(responses: [_status(503)]);

        await expectLater(
          harness.client.send(method, '/x'),
          throwsA(isA<ServerException>()),
        );
        expect(harness.adapter.requests, hasLength(1));
      });

      test('never retries $method on a connection error', () async {
        final harness = NetworkHarness(
          responses: [failWith(DioExceptionType.connectionError)],
        );

        await expectLater(
          harness.client.send(method, '/x'),
          throwsA(isA<NetworkException>()),
        );
        expect(harness.adapter.requests, hasLength(1));
      });
    }

    test('keeps one correlation ID across retries and logs each try', () async {
      final harness = NetworkHarness(
        responses: [_status(503), _status(502), _ok()],
      );

      await harness.client.get('/visits');

      final ids = harness.adapter.requests
          .map((r) => r.headers['X-Correlation-Id'])
          .toSet();
      expect(ids, hasLength(1));
      expect(harness.logs, hasLength(3), reason: 'no duplicated lines');
      expect(harness.logs[0], isNot(contains('(retry')));
      expect(harness.logs[1], contains('(retry 1)'));
      expect(harness.logs[2], contains('(retry 2)'));
    });

    test('a retry gets the token current at that moment', () async {
      final tokens = FakeTokens(token: 'old');
      final harness = NetworkHarness(
        tokens: tokens,
        responses: [
          (options) {
            tokens.token = 'rotated';
            return _status(503)(options);
          },
          _ok(),
        ],
      );

      await harness.client.get('/visits');

      expect(harness.adapter.requests.map((r) => r.headers['Authorization']), [
        'Bearer old',
        'Bearer rotated',
      ]);
    });
  });

  group('CorrelationIdInterceptor', () {
    test('generates a UUID v4 per logical request', () async {
      final harness = NetworkHarness(responses: [_ok(), _ok()]);

      await harness.client.get('/a');
      await harness.client.get('/b');

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

    test('always generates its own ID', () async {
      final harness = NetworkHarness(responses: [_ok()]);

      await harness.client.get(
        '/a',
        options: const CallOptions(
          headers: {'X-Correlation-Id': 'abc-123'},
        ),
      );

      final id = harness.adapter.requests.single.headers['X-Correlation-Id'];
      expect(id, isNot('abc-123'));
      expect(id, hasLength(36));
    });
  });

  group('LoggingInterceptor', () {
    test('logs method, path, status and duration only', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'secret-token'),
        responses: [
          respondJson(
            {'patientName': 'Kamla Devi', 'age': 72},
          ),
        ],
      );

      await harness.client.get(
        '/patients',
        query: {'name': 'Kamla'},
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

    test('never logs the server error text', () async {
      const serverMessage = 'Phone +919876543210 is already registered';
      const serverFieldMessage = 'Anita Deshmukh is not a valid name';
      final harness = NetworkHarness(
        responses: [
          respondApiError(
            'VALIDATION_FAILED',
            status: 400,
            message: serverMessage,
            fieldErrors: {'fullName': serverFieldMessage},
          ),
        ],
      );

      await expectLater(
        harness.client.put('/users/me', body: const {}),
        throwsA(isA<ValidationException>()),
      );

      expect(harness.logs, isNotEmpty);
      for (final line in harness.logs) {
        for (final secret in [
          '+919876543210',
          serverMessage,
          serverFieldMessage,
          'Anita',
        ]) {
          expect(line, isNot(contains(secret)), reason: '$secret in $line');
        }
      }
    });

    test('logs failures with their status or type', () async {
      // A POST is never retried, so the failure is logged once.
      final harness = NetworkHarness(
        responses: [failWith(DioExceptionType.receiveTimeout)],
      );

      await expectLater(
        harness.client.post('/visits'),
        throwsA(isA<TimeoutException>()),
      );

      expect(harness.logs.single, contains('→ receiveTimeout'));
    });

    test('never logs headers, query values or bodies', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'secret-token'),
        responses: [_ok()],
      );

      await harness.client.post(
        '/patients',
        body: const {'name': 'Kamla Devi'},
        options: const CallOptions(
          headers: {'X-Api-Key': 'k-123', 'Cookie': 'session=1'},
        ),
      );

      final all = harness.logs.join('\n');
      for (final secret in ['k-123', 'session=1', 'Kamla', 'secret-token']) {
        expect(all, isNot(contains(secret)), reason: secret);
      }
    });

    test('writes nothing when the request starts', () {
      final lines = <String>[];
      final interceptor = LoggingInterceptor(log: lines.add);
      final options = RequestOptions(
        path: '/me',
        headers: {'Authorization': 'Bearer abc'},
      );

      interceptor.onRequest(options, RequestInterceptorHandler());

      expect(lines, isEmpty);
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

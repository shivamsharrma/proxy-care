import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/di/network_providers.dart';
import 'package:proxy_care_client/core/auth/authentication_session.dart';
import 'package:proxy_care_client/core/di/auth_providers.dart';
import 'package:proxy_care_client/core/network/dio_factory.dart';
import 'package:proxy_care_client/core/network/interceptors/auth_interceptor.dart';
import 'package:proxy_care_client/core/network/interceptors/correlation_id_interceptor.dart';
import 'package:proxy_care_client/core/network/interceptors/logging_interceptor.dart';
import 'package:proxy_care_client/core/network/invalid_response_logger.dart';

import '../../fixtures/env_fixtures.dart';
import '../../helpers/backend_api_error.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/network_harness.dart';
import '../../helpers/provider_container.dart';

/// Records the phase it runs in, to observe Dio's real ordering.
final class _SpyInterceptor extends Interceptor {
  _SpyInterceptor(this.name, this.events);

  final String name;
  final List<String> events;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    events.add('$name.request');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    events.add('$name.response');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    events.add('$name.error');
    handler.next(err);
  }
}

void main() {
  group('base options', () {
    final options = DioFactory.baseOptions(
      Uri.parse('https://api.proxycare.test'),
    );

    test('use the /api/v1 root of the base URL and the agreed timeouts', () {
      expect(options.baseUrl, 'https://api.proxycare.test/api/v1/');
      expect(options.connectTimeout, const Duration(seconds: 10));
      expect(options.receiveTimeout, const Duration(seconds: 30));
      expect(options.sendTimeout, const Duration(seconds: 30));
    });

    test('send and accept JSON by default', () {
      expect(options.contentType, Headers.jsonContentType);
      expect(options.responseType, ResponseType.json);
      expect(
        options.headers['Accept'],
        'application/json',
      );
    });

    test('keep a path prefix of the base URL before /api/v1', () {
      expect(
        DioFactory.baseOptions(
          Uri.parse('https://proxy.example/backend'),
        ).baseUrl,
        'https://proxy.example/backend/api/v1/',
      );
    });

    test('resource paths resolve under /api/v1', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson(const <String, Object?>{}),
          respondJson(const <String, Object?>{}),
        ],
      );

      await harness.client.get('/patients/p1');
      await harness.client.get('patients');

      expect(
        harness.adapter.requests.map((r) => r.uri.toString()),
        [
          'https://api.proxycare.test/api/v1/patients/p1',
          'https://api.proxycare.test/api/v1/patients',
        ],
      );
    });
  });

  group('interceptor ordering', () {
    test('Dio runs request, response and error interceptors FIFO', () async {
      final events = <String>[];
      final adapter = FakeHttpAdapter([
        respondJson(const {}),
        respondJson(const {}, status: 500),
      ]);
      final dio = Dio()
        ..httpClientAdapter = adapter
        ..interceptors.addAll([
          _SpyInterceptor('first', events),
          _SpyInterceptor('second', events),
        ]);

      await dio.get<Object?>('https://api.proxycare.test/ok');
      expect(events, [
        'first.request',
        'second.request',
        'first.response',
        'second.response',
      ]);

      events.clear();
      await expectLater(
        dio.get<Object?>('https://api.proxycare.test/fail'),
        throwsA(isA<DioException>()),
      );
      expect(events, [
        'first.request',
        'second.request',
        'first.error',
        'second.error',
      ]);
    });

    test('the factory installs correlation, logging, auth, retry', () {
      final dio = DioFactory(
        baseUrl: Uri.parse('https://api.proxycare.test'),
        tokens: FakeTokens(),
        log: (_) {},
      ).create();

      final types = dio.interceptors.map((i) => i.runtimeType).toList();
      expect(types.first.toString(), 'ImplyContentTypeInterceptor');
      expect(types.skip(1), [
        InterceptorsWrapper,
        CorrelationIdInterceptor,
        LoggingInterceptor,
        AuthInterceptor,
        RetryInterceptor,
      ]);
    });

    test(
      'the request reaches the adapter with ID and token attached',
      () async {
        final harness = NetworkHarness(
          tokens: FakeTokens(token: 'access-1'),
          responses: [respondJson(const <String, Object?>{})],
        );

        await harness.client.get('/me');

        final sent = harness.adapter.requests.single;
        expect(sent.headers['Authorization'], 'Bearer access-1');
        expect(sent.headers['X-Correlation-Id'], isNotNull);
        expect(harness.logs.single, contains(sent.headers['X-Correlation-Id']));
      },
    );

    test('logging records a failed attempt before it is retried', () async {
      final harness = NetworkHarness(
        tokens: FakeTokens(token: 'old'),
        responses: [
          respondApiError('EXTERNAL_SERVICE_UNAVAILABLE', status: 503),
          respondJson(const <String, Object?>{}),
        ],
      );

      await harness.client.get('/me');

      expect(harness.logs, hasLength(2));
      expect(harness.logs.first, contains('→ 503'));
      expect(harness.logs.last, contains('→ 200'));
    });
  });

  group('send timeout', () {
    test('is switched off for bodiless requests', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson(const <String, Object?>{}),
          respondJson(const <String, Object?>{}),
        ],
      );

      await harness.client.get('/visits');
      await harness.client.post(
        '/visits',
        body: const {'patientId': 'p1'},
      );

      expect(harness.adapter.requests[0].sendTimeout, Duration.zero);
      expect(
        harness.adapter.requests[1].sendTimeout,
        const Duration(seconds: 30),
      );
      expect(
        harness.adapter.requests[0].connectTimeout,
        const Duration(seconds: 10),
      );
    });
  });

  test('providers build Dio from the environment', () async {
    final container = createTestContainer(
      env: testEnv(apiBaseUrl: 'https://api.proxycare.test'),
    );

    // Without Supabase settings, authentication is unconfigured.
    expect(await container.read(supabaseAuthClientProvider.future), isNull);
    final dio = container.read(dioProvider);
    expect(dio.options.baseUrl, 'https://api.proxycare.test/api/v1/');
    expect(
      container.read(parseErrorLoggerProvider),
      isA<InvalidResponseLogger>(),
    );
    expect(
      container.read(authenticationSessionProvider),
      isA<UnconfiguredAuthenticationSession>(),
    );
  });
}

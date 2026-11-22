import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proxy_care_client/core/auth/authentication_session.dart';
import 'package:proxy_care_client/core/auth/authentication_state.dart';
import 'package:proxy_care_client/core/auth/session_token_recovery.dart';
import 'package:proxy_care_client/core/auth/supabase/secure_supabase_storage.dart';
import 'package:proxy_care_client/core/auth/supabase/supabase_authentication_session.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/network/api_client.dart';
import 'package:proxy_care_client/core/network/dio_api_client.dart';
import 'package:proxy_care_client/core/network/dio_factory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/backend_api_error.dart';
import '../../helpers/fake_http_adapter.dart';

/// A session whose refresh, like the SDK's, is shared by concurrent callers.
final class _DedupingSession extends FakeAuthenticationSession {
  _DedupingSession({super.token, super.tokenAfterRefresh});

  Completer<void>? _inFlight;

  @override
  Future<void> refreshSession() {
    final pending = _inFlight;
    if (pending != null) return pending.future;
    final completer = _inFlight = Completer<void>();
    unawaited(
      Future<void>.delayed(Duration.zero, () async {
        await super.refreshSession();
        _inFlight = null;
        completer.complete();
      }),
    );
    return completer.future;
  }
}

/// The real networking stack over [session], with a fake HTTP adapter.
(DioApiClient, FakeHttpAdapter) _stack(AuthenticationSession session) {
  final adapter = FakeHttpAdapter();
  final dio = DioFactory(
    baseUrl: Uri.parse('https://api.proxycare.test'),
    tokens: session,
    recovery: SessionTokenRecovery(session),
    log: (_) {},
    adapter: adapter,
    retryDelay: (_) async {},
  ).create();
  return (DioApiClient(dio), adapter);
}

FakeResponder _unauthorized() =>
    respondApiError('UNAUTHENTICATED', status: 401);

FakeResponder _ok() => respondJson(const <String, Object?>{});

/// 401 unless the request carries [token].
FakeResponder _acceptsOnly(String token) => (options) {
  final ok = options.headers['Authorization'] == 'Bearer $token';
  return (ok ? _ok() : _unauthorized())(options);
};

void main() {
  test('a token the SDK already refreshed is reused, no refresh', () async {
    final session = FakeAuthenticationSession(token: 'old');
    final (client, adapter) = _stack(session);
    adapter.enqueue([
      (options) {
        // The SDK refreshes while the request is in flight.
        session.token = 'newer';
        return _unauthorized()(options);
      },
      _acceptsOnly('newer'),
    ]);

    await client.get('/me', decode: ignoreBody);

    expect(session.refreshes, 0);
    expect(adapter.requests.last.headers['Authorization'], 'Bearer newer');
  });

  test('concurrent 401s share one refresh and each replays once', () async {
    final session = _DedupingSession(token: 'old', tokenAfterRefresh: 'new');
    final (client, adapter) = _stack(session);
    adapter.fallback = _acceptsOnly('new');

    await Future.wait([
      client.get('/a', decode: ignoreBody),
      client.get('/b', decode: ignoreBody),
      client.get('/c', decode: ignoreBody),
    ]);

    expect(session.refreshes, 1);
    expect(adapter.requests, hasLength(6));
    expect(
      adapter.requests.skip(3).map((r) => r.headers['Authorization']).toSet(),
      {'Bearer new'},
    );
  });

  test('a resource-specific 401 after a good refresh keeps the session', () {
    final session = FakeAuthenticationSession(
      token: 'old',
      tokenAfterRefresh: 'new',
    );
    final (client, adapter) = _stack(session);
    adapter.fallback = _unauthorized();

    return expectLater(
      client.get('/restricted', decode: ignoreBody),
      throwsA(isA<UnauthorizedException>()),
    ).then((_) {
      expect(adapter.requests, hasLength(2), reason: 'one replay, no loop');
      expect(session.refreshes, 1);
      expect(session.invalidations, 0);
    });
  });

  group('with the Supabase session', () {
    late MockGoTrueClient auth;
    late StreamController<AuthState> events;
    late FakeSecureKeyValueStore store;
    late SupabaseAuthenticationSession session;
    Session? current;

    setUp(() {
      auth = MockGoTrueClient();
      events = StreamController<AuthState>();
      store = FakeSecureKeyValueStore()
        ..values[SupabaseStorageKeys.session] = '{"stored":true}';
      current = fakeSession();
      when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
      when(() => auth.currentSession).thenAnswer((_) => current);
      session = SupabaseAuthenticationSession(
        auth: auth,
        storage: SecureSupabaseLocalStorage(store),
      )..start();
    });

    tearDown(() async {
      await session.dispose();
      await events.close();
    });

    test('a 401 refreshes through the SDK and replays once', () async {
      final renewed = fakeSession(tokenId: 'b');
      when(() => auth.refreshSession()).thenAnswer((_) async {
        current = renewed;
        return AuthResponse(session: renewed);
      });
      final (client, adapter) = _stack(session);
      adapter.fallback = _acceptsOnly(renewed.accessToken);

      await client.get('/me', decode: ignoreBody);

      verify(() => auth.refreshSession()).called(1);
      expect(adapter.requests, hasLength(2));
    });

    test(
      'after rotation, later requests use the new token, no refresh',
      () async {
        final original = current!.accessToken;
        final renewed = fakeSession(tokenId: 'b');
        when(() => auth.refreshSession()).thenAnswer((_) async {
          current = renewed;
          return AuthResponse(session: renewed);
        });
        final (client, adapter) = _stack(session);
        adapter.fallback = _acceptsOnly(renewed.accessToken);

        await client.get('/me', decode: ignoreBody);
        await client.get('/bookings', decode: ignoreBody);

        verify(() => auth.refreshSession()).called(1);
        expect(adapter.requests.map((r) => r.headers['Authorization']), [
          'Bearer $original',
          'Bearer ${renewed.accessToken}',
          'Bearer ${renewed.accessToken}',
        ]);
      },
    );

    test('a rejected refresh expires the session and clears storage', () async {
      when(() => auth.refreshSession()).thenThrow(
        const AuthApiException(
          'Invalid Refresh Token',
          statusCode: '400',
          code: 'refresh_token_not_found',
        ),
      );
      final (client, adapter) = _stack(session);
      adapter.fallback = _unauthorized();

      await expectLater(
        client.get('/me', decode: ignoreBody),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(session.currentState, isA<SessionExpired>());
      expect(store.values, isEmpty);
      expect(adapter.requests, hasLength(1));
    });

    test('signed out: no Authorization header at all', () async {
      current = null;
      final (client, adapter) = _stack(session);
      adapter.fallback = _ok();

      await client.get('/public-ish', decode: ignoreBody);

      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('the token is never logged', () async {
      final lines = <String>[];
      final adapter = FakeHttpAdapter()..fallback = _ok();
      final dio = DioFactory(
        baseUrl: Uri.parse('https://api.proxycare.test'),
        tokens: session,
        log: lines.add,
        detailedLogging: true,
        adapter: adapter,
      ).create();

      await DioApiClient(dio).get('/me', decode: ignoreBody);

      expect(lines.join('\n'), isNot(contains(current!.accessToken)));
      expect(dio, isA<Dio>());
    });
  });
}

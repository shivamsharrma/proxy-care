import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proxy_care_client/core/auth/authentication_session.dart';
import 'package:proxy_care_client/core/auth/supabase/secure_supabase_storage.dart';
import 'package:proxy_care_client/core/auth/supabase/supabase_authentication_session.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/network/dio_factory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/backend_api_error.dart';
import '../../helpers/dio_probe.dart';
import '../../helpers/fake_http_adapter.dart';

/// The real networking stack over [session], with a fake HTTP adapter.
(DioProbe, FakeHttpAdapter, List<String>) _stack(
  AuthenticationSession session,
) {
  final adapter = FakeHttpAdapter();
  final logs = <String>[];
  final dio = DioFactory(
    baseUrl: Uri.parse('https://api.proxycare.test'),
    tokens: session,
    log: logs.add,
    adapter: adapter,
    retryDelays: const [],
  ).create();
  return (DioProbe(dio), adapter, logs);
}

FakeResponder _unauthorized() =>
    respondApiError('UNAUTHENTICATED', status: 401);

FakeResponder _ok() => respondJson(const <String, Object?>{});

void main() {
  test('the session token is attached to every request', () async {
    final session = FakeAuthenticationSession(token: 'access-1');
    final (client, adapter, _) = _stack(session);
    adapter.fallback = _ok();

    await client.get('/me');
    session.token = 'access-2';
    await client.get('/me');

    expect(adapter.requests.map((r) => r.headers['Authorization']), [
      'Bearer access-1',
      'Bearer access-2',
    ]);
    expect(session.refreshes, 0, reason: 'the network layer never refreshes');
  });

  test('a 401 reaches the caller: no refresh, no replay', () async {
    final session = FakeAuthenticationSession(
      token: 'old',
      tokenAfterRefresh: 'new',
    );
    final (client, adapter, _) = _stack(session);
    adapter.fallback = _unauthorized();

    await expectLater(
      client.get('/restricted'),
      throwsA(isA<UnauthorizedException>()),
    );

    expect(adapter.requests, hasLength(1));
    expect(session.refreshes, 0);
    expect(session.invalidations, 0, reason: 'a 401 does not end the session');
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

    test('after the SDK rotates the token, requests use the new one', () async {
      final original = current!.accessToken;
      final renewed = fakeSession(tokenId: 'b');
      final (client, adapter, _) = _stack(session);
      adapter.fallback = _ok();

      await client.get('/me');
      current = renewed;
      await client.get('/bookings');

      expect(adapter.requests.map((r) => r.headers['Authorization']), [
        'Bearer $original',
        'Bearer ${renewed.accessToken}',
      ]);
      verifyNever(() => auth.refreshSession());
    });

    test('a 401 leaves the session and its storage untouched', () async {
      final (client, adapter, _) = _stack(session);
      adapter.fallback = _unauthorized();

      await expectLater(
        client.get('/me'),
        throwsA(isA<UnauthorizedException>()),
      );

      expect(adapter.requests, hasLength(1));
      verifyNever(() => auth.refreshSession());
      expect(store.values, isNotEmpty);
    });

    test('signed out: no Authorization header at all', () async {
      current = null;
      final (client, adapter, _) = _stack(session);
      adapter.fallback = _ok();

      await client.get('/public-ish');

      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('the token is never logged', () async {
      final (client, adapter, logs) = _stack(session);
      adapter.fallback = _ok();

      await client.get('/me');

      expect(logs, isNotEmpty);
      expect(logs.join('\n'), isNot(contains(current!.accessToken)));
    });
  });
}

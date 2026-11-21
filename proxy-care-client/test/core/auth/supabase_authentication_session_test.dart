import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proxy_care_client/core/auth/authentication_session.dart';
import 'package:proxy_care_client/core/auth/authentication_state.dart';
import 'package:proxy_care_client/core/auth/supabase/secure_supabase_storage.dart';
import 'package:proxy_care_client/core/auth/supabase/supabase_authentication_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/auth_fakes.dart';
import '../../mocks/core_mocks.dart';

void main() {
  setUpAll(() => registerFallbackValue(StackTrace.empty));

  late MockGoTrueClient auth;
  late StreamController<AuthState> events;
  late FakeSecureKeyValueStore store;
  late MockErrorReporter reporter;
  late SupabaseAuthenticationSession session;
  late List<AuthenticationState> states;
  Session? current;

  setUp(() {
    auth = MockGoTrueClient();
    events = StreamController<AuthState>();
    store = FakeSecureKeyValueStore()
      ..values[SupabaseStorageKeys.session] = '{"stored":true}';
    reporter = MockErrorReporter();
    current = null;
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
    when(() => auth.currentSession).thenAnswer((_) => current);
    session = SupabaseAuthenticationSession(
      auth: auth,
      storage: SecureSupabaseLocalStorage(store, reporter: reporter),
      reporter: reporter,
    )..start();
    states = [];
    session.authStateChanges.listen(states.add);
  });

  tearDown(() async {
    await session.dispose();
    await events.close();
  });

  Future<void> emit(
    AuthChangeEvent event, {
    Session? withSession,
    SignOutReason? reason,
  }) async {
    current = withSession;
    events.add(AuthState(event, withSession, signOutReason: reason));
    await Future<void>.delayed(Duration.zero);
  }

  group('state from auth events', () {
    test('starts as initializing', () {
      expect(session.currentState, isA<AuthenticationInitializing>());
    });

    test('an initial session restores the signed-in user', () async {
      final restored = fakeSession();
      await emit(AuthChangeEvent.initialSession, withSession: restored);

      final state = session.currentState as Authenticated;
      expect(state.user.id, 'user-1');
      expect(state.user.email, 'user@example.test');
      expect(state.expiresAt, isNotNull);
      expect(session.sessionExpiresAt, state.expiresAt);
    });

    test('no initial session means unauthenticated', () async {
      await emit(AuthChangeEvent.initialSession);

      expect(session.currentState, isA<Unauthenticated>());
    });

    test('a refresh updates the expiry; a user update the email', () async {
      final first = DateTime.now().add(const Duration(hours: 1));
      await emit(
        AuthChangeEvent.signedIn,
        withSession: fakeSession(expiresAt: first),
      );
      final later = DateTime.now().add(const Duration(hours: 2));
      await emit(
        AuthChangeEvent.tokenRefreshed,
        withSession: fakeSession(tokenId: 'b', expiresAt: later),
      );
      await emit(
        AuthChangeEvent.userUpdated,
        withSession: fakeSession(
          tokenId: 'b',
          expiresAt: later,
          email: 'new@example.test',
        ),
      );

      expect(states, hasLength(3));
      final refreshed = states[1] as Authenticated;
      expect(
        refreshed.expiresAt!.isAfter((states[0] as Authenticated).expiresAt!),
        isTrue,
      );
      expect((states[2] as Authenticated).user.email, 'new@example.test');
    });

    test('a user sign-out is unauthenticated, not expired', () async {
      await emit(AuthChangeEvent.signedIn, withSession: fakeSession());
      await emit(
        AuthChangeEvent.signedOut,
        reason: SignOutReason.userInitiated,
      );

      expect(session.currentState, isA<Unauthenticated>());
    });

    test(
      'a rejected refresh token expires the session and clears storage',
      () async {
        await emit(AuthChangeEvent.signedIn, withSession: fakeSession());
        await emit(
          AuthChangeEvent.signedOut,
          reason: SignOutReason.sessionExpired,
        );

        expect(session.currentState, isA<SessionExpired>());
        expect(store.values, isEmpty);
      },
    );

    test('an unusable stored session also counts as expired', () async {
      await emit(
        AuthChangeEvent.signedOut,
        reason: SignOutReason.sessionMissing,
      );

      expect(session.currentState, isA<SessionExpired>());
    });

    test('a stream error is reported and keeps the session', () async {
      await emit(AuthChangeEvent.signedIn, withSession: fakeSession());
      events.addError(AuthRetryableFetchException(message: 'offline'));
      await Future<void>.delayed(Duration.zero);

      expect(session.currentState, isA<Authenticated>());
      verify(
        () => reporter.report(
          any(that: isA<AuthRetryableFetchException>()),
          any(),
          context: 'auth',
        ),
      ).called(1);
    });

    test('an error before any event settles the initial state', () async {
      events.addError(AuthRetryableFetchException(message: 'offline'));
      await Future<void>.delayed(Duration.zero);

      expect(session.currentState, isA<Unauthenticated>());
    });

    test('restoreSession syncs with the SDK without refreshing', () async {
      current = fakeSession();

      await session.restoreSession();

      expect(session.currentState, isA<Authenticated>());
      verifyNever(() => auth.refreshSession());
    });
  });

  group('access token', () {
    test('is the current session token', () async {
      current = fakeSession();

      expect(await session.getAccessToken(), current!.accessToken);
      verifyNever(() => auth.refreshSession());
    });

    test('is null when signed out', () async {
      expect(await session.getAccessToken(), isNull);
    });

    test('an expiring token is refreshed through the SDK first', () async {
      current = fakeSession(
        expiresAt: DateTime.now().add(const Duration(seconds: 5)),
      );
      final renewed = fakeSession(tokenId: 'b');
      when(() => auth.refreshSession()).thenAnswer((_) async {
        current = renewed;
        return AuthResponse(session: renewed);
      });

      expect(await session.getAccessToken(), renewed.accessToken);
      verify(() => auth.refreshSession()).called(1);
    });
  });

  group('refresh', () {
    test('an invalid refresh session expires and clears storage', () async {
      current = fakeSession();
      when(() => auth.refreshSession()).thenThrow(
        const AuthApiException(
          'Invalid Refresh Token',
          statusCode: '400',
          code: 'refresh_token_not_found',
        ),
      );

      await expectLater(
        session.refreshSession(),
        throwsA(
          isA<SessionRefreshException>().having(
            (e) => e.sessionInvalid,
            'sessionInvalid',
            isTrue,
          ),
        ),
      );
      expect(session.currentState, isA<SessionExpired>());
      expect(store.values, isEmpty);
    });

    test('a network failure keeps the session', () async {
      current = fakeSession();
      await emit(AuthChangeEvent.signedIn, withSession: current);
      when(
        () => auth.refreshSession(),
      ).thenThrow(AuthRetryableFetchException(message: 'offline'));

      await expectLater(
        session.refreshSession(),
        throwsA(
          isA<SessionRefreshException>().having(
            (e) => e.sessionInvalid,
            'sessionInvalid',
            isFalse,
          ),
        ),
      );
      expect(session.currentState, isA<Authenticated>());
      expect(store.values, isNotEmpty);
    });

    test('a missing session is invalid', () async {
      when(() => auth.refreshSession())
          .thenThrow(AuthSessionMissingException());

      await expectLater(
        session.refreshSession(),
        throwsA(isA<SessionRefreshException>()),
      );
      expect(session.currentState, isA<SessionExpired>());
    });
  });

  group('invalidation', () {
    test('signs out locally, clears credentials, unauthenticated', () async {
      await emit(AuthChangeEvent.signedIn, withSession: fakeSession());
      when(
        () => auth.signOut(scope: SignOutScope.local),
      ).thenAnswer((_) async {});

      await session.invalidateSession();

      verify(() => auth.signOut(scope: SignOutScope.local)).called(1);
      expect(store.values, isEmpty);
      expect(session.currentState, isA<Unauthenticated>());
    });

    test('still clears credentials when the SDK sign-out fails', () async {
      when(
        () => auth.signOut(scope: SignOutScope.local),
      ).thenThrow(const AuthApiException('server down'));

      await session.invalidateSession();

      expect(store.values, isEmpty);
      expect(session.currentState, isA<Unauthenticated>());
    });
  });

  group('lifecycle', () {
    testWidgets('background and foreground never trigger a refresh', (
      tester,
    ) async {
      current = fakeSession();
      events.add(AuthState(AuthChangeEvent.initialSession, current));
      await tester.pump();

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }

      verifyNever(() => auth.refreshSession());
      expect(session.currentState, isA<Authenticated>());
    });

    test('a refresh done by the SDK while resuming syncs the state', () async {
      await emit(AuthChangeEvent.initialSession, withSession: fakeSession());
      final renewed = fakeSession(
        tokenId: 'b',
        expiresAt: DateTime.now().add(const Duration(hours: 3)),
      );
      await emit(AuthChangeEvent.tokenRefreshed, withSession: renewed);

      expect(await session.getAccessToken(), renewed.accessToken);
      expect(states.last, isA<Authenticated>());
    });

    test('dispose cancels the SDK subscription', () async {
      await session.dispose();

      expect(events.hasListener, isFalse);
    });
  });
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proxy_care_client/core/auth/authentication_session.dart';
import 'package:proxy_care_client/core/auth/authentication_state.dart';
import 'package:proxy_care_client/core/auth/authorization/authorization.dart';
import 'package:proxy_care_client/core/auth/biometric_gate.dart';
import 'package:proxy_care_client/core/auth/session_token_recovery.dart';
import 'package:proxy_care_client/core/auth/supabase/secure_supabase_storage.dart';
import 'package:proxy_care_client/core/auth/supabase/supabase_initializer.dart';
import 'package:proxy_care_client/core/config/app_variant.dart';
import 'package:proxy_care_client/core/di/app_container.dart';
import 'package:proxy_care_client/core/di/auth_providers.dart';
import 'package:proxy_care_client/core/security/secure_key_value_store.dart';

import '../../fixtures/env_fixtures.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/provider_container.dart';
import '../../mocks/core_mocks.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  setUpAll(() => registerFallbackValue(StackTrace.empty));

  group('SecureSupabaseLocalStorage', () {
    late FakeSecureKeyValueStore store;
    late MockErrorReporter reporter;
    late SecureSupabaseLocalStorage storage;

    setUp(() {
      store = FakeSecureKeyValueStore();
      reporter = MockErrorReporter();
      storage = SecureSupabaseLocalStorage(store, reporter: reporter);
    });

    test('persists the whole session as one secure entry', () async {
      await storage.initialize();
      await storage.persistSession('{"access_token":"a","refresh_token":"r"}');

      expect(store.values, {
        SupabaseStorageKeys.session: '{"access_token":"a","refresh_token":"r"}',
      });
      expect(await storage.hasAccessToken(), isTrue);
      expect(
        await storage.accessToken(),
        '{"access_token":"a","refresh_token":"r"}',
      );
    });

    test('deletes the session', () async {
      await storage.persistSession('{}');
      await storage.removePersistedSession();

      expect(store.values, isEmpty);
      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
    });

    test('a read failure is reported and means no session', () async {
      store
        ..values[SupabaseStorageKeys.session] = '{}'
        ..failReads = true;

      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
      verify(
        () => reporter.report(
          any(that: isA<SecureStorageException>()),
          any(),
          context: 'secure-storage',
        ),
      ).called(2);
    });

    test('a write failure is reported and rethrown, nothing stored', () async {
      store.failWrites = true;

      await expectLater(
        storage.persistSession('{"access_token":"a"}'),
        throwsA(isA<SecureStorageException>()),
      );
      expect(store.values, isEmpty);
      verify(
        () => reporter.report(any(), any(), context: 'secure-storage'),
      ).called(1);
    });

    test('a delete failure is reported and rethrown', () async {
      store
        ..values[SupabaseStorageKeys.session] = '{}'
        ..failDeletes = true;

      await expectLater(
        storage.removePersistedSession(),
        throwsA(isA<SecureStorageException>()),
      );
      verify(
        () => reporter.report(any(), any(), context: 'secure-storage'),
      ).called(1);
    });
  });

  group('SecureGotrueAsyncStorage (PKCE verifiers)', () {
    test('keeps verifiers in secure storage under its own prefix', () async {
      final store = FakeSecureKeyValueStore();
      final storage = SecureGotrueAsyncStorage(store);

      await storage.setItem(key: 'sb-code-verifier', value: 'v');
      expect(store.values, {'proxycare.supabase.pkce.sb-code-verifier': 'v'});
      expect(await storage.getItem(key: 'sb-code-verifier'), 'v');
      await storage.removeItem(key: 'sb-code-verifier');
      expect(store.values, isEmpty);
    });

    test('failures are rethrown, never downgraded', () async {
      final store = FakeSecureKeyValueStore()..failWrites = true;

      await expectLater(
        SecureGotrueAsyncStorage(store).setItem(key: 'k', value: 'v'),
        throwsA(isA<SecureStorageException>()),
      );
    });
  });

  group('FlutterSecureKeyValueStore', () {
    test('uses Keystore AES-GCM on Android and device-only Keychain', () {
      expect(
        FlutterSecureKeyValueStore.androidOptions.toMap()['keyCipherAlgorithm'],
        'AES_GCM_NoPadding',
      );
      expect(
        FlutterSecureKeyValueStore.androidOptions
            .toMap()['storageCipherAlgorithm'],
        'AES_GCM_NoPadding',
      );
      expect(
        FlutterSecureKeyValueStore.iosOptions.accessibility,
        KeychainAccessibility.first_unlock_this_device,
      );
      expect(FlutterSecureKeyValueStore.iosOptions.synchronizable, isFalse);
    });

    test(
      'platform errors become SecureStorageExceptions without values',
      () async {
        final platform = _MockFlutterSecureStorage();
        when(
          () => platform.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenThrow(PlatformException(code: 'keychain', message: 'denied'));
        when(
          () => platform.read(key: any(named: 'key')),
        ).thenThrow(PlatformException(code: 'keystore'));
        when(
          () => platform.delete(key: any(named: 'key')),
        ).thenThrow(PlatformException(code: 'keystore'));
        final store = FlutterSecureKeyValueStore(storage: platform);

        await expectLater(
          store.write('session', 'secret-token-value'),
          throwsA(
            isA<SecureStorageException>()
                .having((e) => e.operation, 'op', SecureStorageOperation.write)
                .having(
                  (e) => e.toString(),
                  'message',
                  isNot(contains('secret-token-value')),
                ),
          ),
        );
        await expectLater(
          store.read('session'),
          throwsA(isA<SecureStorageException>()),
        );
        await expectLater(
          store.delete('session'),
          throwsA(isA<SecureStorageException>()),
        );
      },
    );
  });

  test('Supabase gets secure storage for the session and PKCE', () {
    final options = secureAuthOptions(store: FakeSecureKeyValueStore());

    expect(options.localStorage, isA<SecureSupabaseLocalStorage>());
    expect(options.pkceAsyncStorage, isA<SecureGotrueAsyncStorage>());
    expect(options.autoRefreshToken, isTrue, reason: 'the SDK refreshes');
  });

  test('no code persists credentials outside secure storage', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync());

    for (final source in sources) {
      expect(source, isNot(contains('package:shared_preferences')));
      expect(source, isNot(contains('SharedPreferencesLocalStorage')));
      expect(source, isNot(contains('EmptyLocalStorage')));
    }
  });

  group('SessionTokenRecovery', () {
    test('reuses a newer token without refreshing', () async {
      final session = FakeAuthenticationSession(token: 'newer');

      expect(
        await SessionTokenRecovery(session).recoverAccessToken(
          rejectedToken: 'old',
        ),
        'newer',
      );
      expect(session.refreshes, 0);
    });

    test('refreshes when the rejected token is still current', () async {
      final session = FakeAuthenticationSession(
        token: 'old',
        tokenAfterRefresh: 'new',
      );

      expect(
        await SessionTokenRecovery(session).recoverAccessToken(
          rejectedToken: 'old',
        ),
        'new',
      );
      expect(session.refreshes, 1);
    });

    test('a failed refresh gives no token, without invalidating', () async {
      final session = FakeAuthenticationSession(token: 'old')
        ..refreshError = const SessionRefreshException(sessionInvalid: false);

      expect(
        await SessionTokenRecovery(session).recoverAccessToken(
          rejectedToken: 'old',
        ),
        isNull,
      );
      expect(session.invalidations, 0);
    });

    test('signed out: nothing to recover', () async {
      final session = FakeAuthenticationSession();

      expect(
        await SessionTokenRecovery(session).recoverAccessToken(
          rejectedToken: 'old',
        ),
        isNull,
      );
      expect(session.refreshes, 0);
    });
  });

  group('authentication state provider', () {
    test('mirrors the session and stops listening when disposed', () async {
      final session = FakeAuthenticationSession();
      final container = createAppContainer(
        env: testEnv(),
        variant: AppVariant.user,
        overrides: [authenticationSessionProvider.overrideWithValue(session)],
      );
      final seen = <AuthenticationState>[];
      container.listen(
        authenticationStateProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );

      session.emit(
        const Authenticated(user: AuthenticatedUser(id: 'user-1')),
      );
      await Future<void>.delayed(Duration.zero);
      session.emit(const SessionExpired());
      await Future<void>.delayed(Duration.zero);

      expect(seen.map((s) => s.runtimeType), [
        AuthenticationInitializing,
        Authenticated,
        SessionExpired,
      ]);

      container.dispose();
      expect(session.changes.hasListener, isFalse);
    });

    test('is signed out when authentication is not configured', () async {
      final container = createTestContainer();
      await container.read(supabaseAuthClientProvider.future);

      expect(
        container.read(authenticationSessionProvider),
        isA<UnconfiguredAuthenticationSession>(),
      );
      expect(
        container.read(authenticationStateProvider),
        isA<Unauthenticated>(),
      );
      expect(
        await container.read(authenticationSessionProvider).getAccessToken(),
        isNull,
      );
    });
  });

  group('authorization', () {
    const read = Permission('records.read');
    const write = Permission('records.write');
    const viewer = Role('viewer');
    const editor = Role('editor');
    final service = AuthorizationService(
      RolePermissionPolicy({
        viewer: {read},
        editor: {read, write},
      }),
    );

    test('grants by role and explains denials', () {
      expect(service.decide({viewer}, read).isAllowed, isTrue);
      expect(
        (service.decide({viewer}, write) as Denied).reason,
        DenialReason.missingPermission,
      );
      expect(service.decide({editor}, write).isAllowed, isTrue);
      expect(
        (service.decide(null, read) as Denied).reason,
        DenialReason.unauthenticated,
      );
    });

    test('the default policy grants nothing', () {
      final container = createTestContainer();
      expect(
        container.read(authorizationServiceProvider).decide({editor}, read),
        isA<Denied>(),
      );
    });
  });

  test('biometrics are optional and off by default', () async {
    final container = createTestContainer();
    final gate = container.read(biometricGateProvider);

    expect(await gate.isAvailable(), isFalse);
    expect(
      await gate.confirm(reason: 'Unlock'),
      BiometricResult.unavailable,
    );
  });

  test('users and failures never print secrets or contact details', () {
    const user = AuthenticatedUser(id: 'user-1', email: 'a@example.test');
    expect(user.toString(), isNot(contains('example')));
    expect(
      const SecureStorageException(
        SecureStorageOperation.read,
        'proxycare.supabase.session',
      ).toString(),
      'SecureStorageException: read of "proxycare.supabase.session" failed',
    );
  });
}

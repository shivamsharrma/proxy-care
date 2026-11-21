import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proxy_care_client/core/auth/authentication_state.dart';
import 'package:proxy_care_client/core/di/app_container.dart';
import 'package:proxy_care_client/core/di/auth_providers.dart';
import 'package:proxy_care_client/core/di/core_providers.dart';
import 'package:proxy_care_client/core/di/platform_providers.dart';
import 'package:proxy_care_client/core/security/redactor.dart';
import 'package:proxy_care_client/core/security/session_cleanup.dart';

import '../../fixtures/env_fixtures.dart';
import '../../helpers/auth_fakes.dart';
import '../../mocks/core_mocks.dart';

void main() {
  group('Redactor.text', () {
    const redactor = Redactor();

    test('masks values that are sensitive whatever they are called', () {
      const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJl';
      final cases = {
        'token $jwt end': 'token *** end',
        'Authorization: Bearer abc.123': 'Authorization: ***',
        'mail ravi.k+1@example.co.in now': 'mail *** now',
        'call +91 98765 43210': 'call ***',
        'aadhaar 1234 5678 9012': 'aadhaar ***',
        'account 123456789012': 'account ***',
      };
      cases.forEach((input, expected) {
        expect(redactor.text(input), expected, reason: input);
      });
    });

    test('leaves ordinary text, ids and short numbers alone', () {
      for (final text in [
        'Booking PC-2481 created',
        'GET /v1/bookings → 200 in 182 ms',
        'retry 3 of 5 on 2026-11-15',
      ]) {
        expect(redactor.text(text), text);
      }
    });

    test('masks sensitive keys at any depth', () {
      expect(
        redactor.json({
          'id': 'b-1',
          'patient': {'name': 'x'},
          'items': [
            {'otp': '1234', 'kind': 'a'},
          ],
        }),
        {
          'id': 'b-1',
          'patient': '***',
          'items': [
            {'otp': '***', 'kind': 'a'},
          ],
        },
      );
    });
  });

  group('SessionCleanup', () {
    setUpAll(() => registerFallbackValue(StackTrace.empty));

    test('runs every task; failures are reported, not thrown', () async {
      final reporter = MockErrorReporter();
      final ran = <String>[];
      final cleanup = SessionCleanup(reporter)
        ..register('cache', () async => ran.add('cache'))
        ..register('broken', () async => throw StateError('x'))
        ..register('drafts', () async => ran.add('drafts'));

      await cleanup.run();

      expect(ran, ['cache', 'drafts']);
      verify(
        () => reporter.report(
          any(),
          any(),
          context: 'session-cleanup:broken',
        ),
      ).called(1);
    });

    test('runs when the session ends, not on sign-in', () async {
      final session = FakeAuthenticationSession()
        ..currentState = const Unauthenticated();
      final container = createAppContainer(
        env: testEnv(),
        overrides: [
          authenticationSessionProvider.overrideWithValue(session),
          loggerProvider.overrideWithValue(RecordingLogger()),
        ],
      );
      addTearDown(container.dispose);
      var runs = 0;
      container
          .read(sessionCleanupProvider)
          .register('count', () async => runs++);

      session.emit(
        const Authenticated(user: AuthenticatedUser(id: 'u1')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(runs, 0);

      session.emit(const SessionExpired());
      await Future<void>.delayed(Duration.zero);
      expect(runs, 1);
    });
  });
}

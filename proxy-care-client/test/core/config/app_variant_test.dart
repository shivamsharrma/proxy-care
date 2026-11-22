import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/auth/authorization/authorization.dart';
import 'package:proxy_care_client/core/config/app_variant.dart';
import 'package:proxy_care_client/core/config/env_exception.dart';

// Slice C0 (plan §4 "App variant"): the build's APP_VARIANT decides which app
// this is (User or Caretaker) and so the role it signs up as. Enables
// 01_welcome "Get started takes the visitor to the shared mobile number
// screen as the app's role". The variant is a UX boundary only; the server
// checks roles.
void main() {
  group('APP_VARIANT', () {
    test('parses user as the User app', () {
      expect(AppVariant.parse('user'), AppVariant.user);
    });

    test('parses caretaker as the Caretaker app', () {
      expect(AppVariant.parse('caretaker'), AppVariant.caretaker);
    });

    test('accepts surrounding spaces and any letter case', () {
      expect(AppVariant.parse(' User '), AppVariant.user);
      expect(AppVariant.parse('CARETAKER'), AppVariant.caretaker);
    });

    test('fails when the value is missing', () {
      expect(
        () => AppVariant.parse(''),
        throwsAppVariantError(contains('APP_VARIANT is required')),
      );
    });

    test('fails on an unknown value', () {
      expect(
        () => AppVariant.parse('admin'),
        throwsAppVariantError(
          allOf(contains('APP_VARIANT must be one of'), contains('"admin"')),
        ),
      );
    });

    test(
      'fromEnvironment fails at start-up when APP_VARIANT is not defined',
      () {
        // `flutter test` runs without --dart-define, so APP_VARIANT is empty.
        expect(
          AppVariant.fromEnvironment,
          throwsAppVariantError(contains('APP_VARIANT is required')),
        );
      },
    );
  });

  group('role', () {
    test('the User app signs up with the USER role', () {
      expect(AppVariant.user.role, const Role('USER'));
    });

    test('the Caretaker app signs up with the CARETAKER role', () {
      expect(AppVariant.caretaker.role, const Role('CARETAKER'));
    });
  });
}

/// An [EnvConfigException], like every other invalid compile-time value,
/// whose single error matches [message].
Matcher throwsAppVariantError(Matcher message) => throwsA(
  isA<EnvConfigException>().having(
    (exception) => exception.errors,
    'errors',
    [message],
  ),
);

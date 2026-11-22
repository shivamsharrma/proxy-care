import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/config/app_variant.dart';
import 'package:proxy_care_client/core/di/core_providers.dart';
import 'package:proxy_care_client/core/error/logger_error_reporter.dart';
import 'package:proxy_care_client/core/logging/app_logger.dart';
import 'package:proxy_care_client/core/logging/package_app_logger.dart';

import '../../fixtures/env_fixtures.dart';
import '../../helpers/provider_container.dart';
import '../../mocks/core_mocks.dart';

void main() {
  test('envProvider has no default and must be overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(() => container.read(envProvider), throwsA(anything));
  });

  test('createAppContainer provides the given env', () {
    final env = testEnv(appName: 'Injected');
    final container = createTestContainer(env: env);

    expect(container.read(envProvider), same(env));
  });

  test('loggerProvider builds one logger for the container', () {
    final container = createTestContainer();

    final first = container.read(loggerProvider);
    final second = container.read(loggerProvider);

    expect(first, isA<PackageAppLogger>());
    expect(second, same(first));
  });

  test('errorReporterProvider defaults to the logger-backed reporter', () {
    final container = createTestContainer();

    expect(container.read(errorReporterProvider), isA<LoggerErrorReporter>());
  });

  test('infrastructure can be replaced with an override', () {
    final reporter = MockErrorReporter();
    final container = createTestContainer(
      overrides: [errorReporterProvider.overrideWithValue(reporter)],
    );

    expect(container.read(errorReporterProvider), same(reporter));
  });

  test('the error reporter writes to the injected logger', () {
    final logger = RecordingLogger();
    final container = createTestContainer(
      overrides: [loggerProvider.overrideWithValue(logger)],
    );
    final reporter = container.read(errorReporterProvider);
    final error = StateError('boom');

    reporter.report(error, StackTrace.empty, context: 'test');

    final entry = logger.entries.single;
    expect(entry.level, LogLevel.error);
    expect(entry.message, 'Unhandled error');
    expect(entry.fields, {'context': 'test'});
    expect(entry.error, same(error));
  });

  test('createAppContainer provides the given variant', () {
    final container = createTestContainer(variant: AppVariant.caretaker);

    expect(container.read(appVariantProvider), AppVariant.caretaker);
  });

  test('appVariantProvider has no usable default and must be overridden', () {
    // `flutter test` runs without APP_VARIANT, so there is no variant to use.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(appVariantProvider),
      throwsA(
        isA<ProviderException>().having(
          (error) => error.exception,
          'exception',
          isA<UnimplementedError>(),
        ),
      ),
    );
  });

  for (final variant in AppVariant.values) {
    test(
      'appVariantProvider provides the overridden ${variant.name} variant',
      () {
        final container = createTestContainer(variant: variant);

        expect(container.read(appVariantProvider), variant);
      },
    );
  }
}

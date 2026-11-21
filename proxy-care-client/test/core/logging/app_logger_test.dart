import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:proxy_care_client/core/config/env.dart';
import 'package:proxy_care_client/core/logging/app_logger.dart';
import 'package:proxy_care_client/core/logging/package_app_logger.dart';

import '../../fixtures/env_fixtures.dart';

final class _Capture extends LogOutput {
  final lines = <String>[];

  @override
  void output(OutputEvent event) => lines.addAll(event.lines);
}

(PackageAppLogger, _Capture) _logger(
  LogLevel minimum, {
  bool details = false,
}) {
  final capture = _Capture();
  return (
    PackageAppLogger(
      minimumLevel: minimum,
      includeErrorDetails: details,
      output: capture,
    ),
    capture,
  );
}

void main() {
  test('writes structured fields with sensitive values masked', () {
    final (logger, out) = _logger(LogLevel.debug);

    logger.info(
      'Booking created',
      fields: {
        'bookingId': 'b-1',
        'patientName': 'Kamla Devi',
        'accessToken': 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.sig',
        'nested': {'phone': '9876543210', 'count': 2},
      },
    );

    final line = out.lines.single;
    expect(line, contains('Booking created'));
    expect(line, contains('"bookingId":"b-1"'));
    expect(line, contains('"count":2'));
    for (final secret in ['Kamla', 'eyJ', '9876543210']) {
      expect(line, isNot(contains(secret)));
    }
  });

  test('masks tokens, emails and numbers inside message text', () {
    final (logger, out) = _logger(LogLevel.debug);

    logger.warning(
      'Retry for a@b.co with Bearer abc.def and +91 98765 43210',
    );

    expect(out.lines.single, isNot(contains('a@b.co')));
    expect(out.lines.single, isNot(contains('abc.def')));
    expect(out.lines.single, isNot(contains('98765')));
  });

  test('writes the error type only, unless details are enabled', () {
    final (quiet, quietOut) = _logger(LogLevel.debug);
    final (verbose, verboseOut) = _logger(LogLevel.debug, details: true);
    final error = StateError('token eyJabc.def.ghi for ravi@x.in');

    quiet.error('Failed', error: error);
    verbose.error('Failed', error: error);

    expect(quietOut.lines.single, endsWith('error=StateError'));
    expect(verboseOut.lines.single, contains('error=StateError: Bad state'));
    expect(verboseOut.lines.single, isNot(contains('eyJ')));
    expect(verboseOut.lines.single, isNot(contains('ravi@x.in')));
  });

  test('drops entries below the minimum level; off writes nothing', () {
    final (logger, out) = _logger(LogLevel.warning);
    logger
      ..debug('d')
      ..info('i')
      ..warning('w')
      ..error('e');
    expect(out.lines, hasLength(2));

    final (off, offOut) = _logger(LogLevel.off);
    off.error('e');
    expect(offOut.lines, isEmpty);
  });

  test('the level follows the environment', () {
    Env env(String appEnv, {bool logging = true}) => testEnv(
      appEnv: appEnv,
      apiBaseUrl: 'https://api.proxycare.test',
      enableLogging: logging,
      supabaseUrl: 'https://project.supabase.co',
      supabasePublishableKey: 'sb_publishable_test',
    );

    expect(logLevelFor(env('development')), LogLevel.debug);
    expect(logLevelFor(env('staging')), LogLevel.info);
    expect(logLevelFor(env('production')), LogLevel.warning);
    expect(logLevelFor(env('production', logging: false)), LogLevel.off);
  });
}

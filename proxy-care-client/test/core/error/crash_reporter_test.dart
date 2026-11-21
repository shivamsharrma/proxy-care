import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/di/core_providers.dart';
import 'package:proxy_care_client/core/error/crash_reporter.dart';
import 'package:proxy_care_client/core/error/logger_error_reporter.dart';

import '../../helpers/provider_container.dart';
import '../../mocks/core_mocks.dart';

class _RecordingCrashReporter implements CrashReporter {
  final reports = <CrashReport>[];

  @override
  void record(CrashReport report) => reports.add(report);
}

void main() {
  test('the MVP crash reporter is a no-op', () {
    final container = createTestContainer();

    expect(container.read(crashReporterProvider), isA<NoopCrashReporter>());
    const NoopCrashReporter().record(
      const CrashReport(errorType: 'StateError', stackTrace: StackTrace.empty),
    );
  });

  test('reports keep the error type, never the message', () {
    final report = CrashReport.from(
      StateError('patient Kamla Devi, token eyJhbGciOi'),
      StackTrace.empty,
      context: 'zone',
    );

    expect(report.errorType, 'StateError');
    expect(report.context, 'zone');
  });

  test('the error reporter logs and forwards a safe crash report', () {
    final logger = RecordingLogger();
    final crashes = _RecordingCrashReporter();
    final reporter = LoggerErrorReporter(logger, crashReporter: crashes);

    reporter.report(StateError('secret'), StackTrace.empty, context: 'zone');
    reporter.report(
      Exception('also secret'),
      StackTrace.empty,
      context: 'repository',
    );

    expect(logger.entries.map((e) => e.fields['context']), [
      'zone',
      'repository',
    ]);
    expect(crashes.reports.map((r) => (r.errorType, r.fatal)), [
      ('StateError', true),
      ('_Exception', false),
    ]);
  });

  test('a real crash reporter can be plugged in with an override', () {
    final crashes = _RecordingCrashReporter();
    final container = createTestContainer(
      overrides: [crashReporterProvider.overrideWithValue(crashes)],
    );

    container
        .read(errorReporterProvider)
        .report(StateError('x'), StackTrace.empty, context: 'platform');

    expect(crashes.reports.single.fatal, isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/di/core_providers.dart';
import 'package:proxy_care_client/core/error/crash_reporter.dart';
import 'package:proxy_care_client/core/observability/analytics_service.dart';
import 'package:proxy_care_client/core/observability/performance_monitor.dart';

import '../../helpers/provider_container.dart';

final class _RecordingAnalytics implements AnalyticsService {
  final events = <(String, Map<String, Object>)>[];

  @override
  void logEvent(String name, {Map<String, Object> parameters = const {}}) =>
      events.add((name, parameters));
}

void main() {
  test('the defaults are no-ops behind vendor-independent interfaces', () {
    final container = createTestContainer();

    expect(container.read(crashReporterProvider), isA<NoopCrashReporter>());
    expect(
      container.read(analyticsAdapterProvider),
      isA<NoopAnalyticsService>(),
    );
    expect(
      container.read(analyticsServiceProvider),
      isA<FilteringAnalyticsService>(),
    );
    final monitor = container.read(performanceMonitorProvider);
    expect(monitor, isA<NoopPerformanceMonitor>());
    monitor.startTrace('booking_load').stop();
    container.read(analyticsServiceProvider).logEvent('app_open');
  });

  test('an adapter override receives only filtered events', () {
    final adapter = _RecordingAnalytics();
    final container = createTestContainer(
      overrides: [analyticsAdapterProvider.overrideWithValue(adapter)],
    );

    container
        .read(analyticsServiceProvider)
        .logEvent('booking_confirmed', parameters: {'purposes': 2});

    final (name, parameters) = adapter.events.single;
    expect(name, 'booking_confirmed');
    expect(parameters, {'purposes': 2});
  });

  group('FilteringAnalyticsService', () {
    late _RecordingAnalytics inner;
    late FilteringAnalyticsService analytics;

    setUp(() {
      inner = _RecordingAnalytics();
      analytics = FilteringAnalyticsService(inner);
    });

    test('drops events with invalid names', () {
      for (final name in [
        'BookingConfirmed',
        'booking-confirmed',
        '',
        'x' * 41,
      ]) {
        analytics.logEvent(name);
      }
      expect(inner.events, isEmpty);
    });

    test('drops sensitive, malformed and unsafe parameters', () {
      analytics.logEvent(
        'visit_started',
        parameters: {
          'mobility': 'wheelchair', // sensitive key
          'patient_id': 'p-1', // sensitive key
          'step': 'pickup',
          'step_count': 3,
          'is_first': true,
          'Bad-Key': 'x',
          'free_text': 'call 9876543210', // looks like personal data
          'long_text': 'x' * 101,
          'list': [1, 2],
        },
      );

      expect(inner.events.single.$2, {
        'step': 'pickup',
        'step_count': 3,
        'is_first': true,
      });
    });

    test('keeps at most the parameter limit', () {
      analytics.logEvent(
        'many_params',
        parameters: {for (var i = 0; i < 30; i++) 'p$i': i},
      );
      expect(
        inner.events.single.$2,
        hasLength(FilteringAnalyticsService.maxParameters),
      );
    });
  });
}

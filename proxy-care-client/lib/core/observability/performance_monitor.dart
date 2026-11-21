/// Vendor-independent performance tracing. Pure Dart.
///
/// ```dart
/// final trace = monitor.startTrace('booking_load');
/// try { ... } finally { trace.stop(); }
/// ```
///
/// Trace names follow the analytics rules: snake_case, no user data.
abstract interface class PerformanceMonitor {
  /// Starts timing [name].
  PerformanceTrace startTrace(String name);
}

/// A running trace.
abstract interface class PerformanceTrace {
  /// Stops the trace and records it. Calling it again does nothing.
  void stop();
}

/// Records nothing (no performance vendor is chosen yet).
final class NoopPerformanceMonitor implements PerformanceMonitor {
  /// Creates the no-op monitor.
  const NoopPerformanceMonitor();

  @override
  PerformanceTrace startTrace(String name) => const _NoopTrace();
}

final class _NoopTrace implements PerformanceTrace {
  const _NoopTrace();

  @override
  void stop() {}
}

import '../security/redactor.dart';

/// Vendor-independent product analytics. Pure Dart.
///
/// Features call [AnalyticsService] (through `analyticsServiceProvider`,
/// which always filters); a vendor adapter implements it later without
/// changes elsewhere (see docs/observability.md).
abstract interface class AnalyticsService {
  /// Records the event [name] with [parameters].
  void logEvent(String name, {Map<String, Object> parameters = const {}});
}

/// Records nothing (no analytics vendor is chosen yet).
final class NoopAnalyticsService implements AnalyticsService {
  /// Creates the no-op service.
  const NoopAnalyticsService();

  @override
  void logEvent(String name, {Map<String, Object> parameters = const {}}) {}
}

/// Passes only safe events to [inner].
///
/// - The event name must be snake_case, at most [maxNameLength] characters
///   (`booking_confirmed`); other events are dropped.
/// - Parameters keep only snake_case keys that are not sensitive (see
///   [Redactor]) with `num`, `bool` or short `String` values; at most
///   [maxParameters]. Everything else is dropped, never sent.
///
/// So identifiers of people, health details and free text can only reach
/// an analytics vendor by being renamed to look harmless: review event
/// parameters like API fields.
final class FilteringAnalyticsService implements AnalyticsService {
  /// Creates the filter in front of [inner].
  const FilteringAnalyticsService(
    this.inner, {
    this.redactor = const Redactor(),
  });

  /// Longest event name or parameter key.
  static const maxNameLength = 40;

  /// Longest string parameter value.
  static const maxValueLength = 100;

  /// Most parameters per event.
  static const maxParameters = 25;

  static final RegExp _name = RegExp(r'^[a-z][a-z0-9_]*$');

  /// Where safe events go.
  final AnalyticsService inner;

  /// Decides which parameter keys are sensitive.
  final Redactor redactor;

  @override
  void logEvent(String name, {Map<String, Object> parameters = const {}}) {
    if (!_isName(name)) return;
    final safe = <String, Object>{
      for (final MapEntry(:key, :value) in parameters.entries)
        if (_isName(key) && !redactor.isSensitive(key) && _isSafeValue(value))
          key: value,
    };
    inner.logEvent(
      name,
      parameters: Map.fromEntries(safe.entries.take(maxParameters)),
    );
  }

  bool _isName(String name) =>
      name.length <= maxNameLength && _name.hasMatch(name);

  bool _isSafeValue(Object value) => switch (value) {
    num() || bool() => true,
    final String text =>
      text.length <= maxValueLength && redactor.text(text) == text,
    _ => false,
  };
}

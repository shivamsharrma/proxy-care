import 'route_conventions.dart';

/// A validated request to navigate, for example from a push notification.
/// Pure Dart.
///
/// The raw payload is a map `{"type": "<module>.<event>", "data": {...}}`
/// where every data key is lowerCamelCase and every value a string. Nothing
/// else is accepted, so a malformed or oversized payload never reaches a
/// feature's resolver. Identifiers go in [data] and from there into path
/// parameters, never into navigation extras.
final class NavigationPayload {
  const NavigationPayload._(this.type, this.data);

  /// The most data entries accepted.
  static const maxEntries = 20;

  /// The longest data value accepted.
  static const maxValueLength = 512;

  /// The payload type, `<module>.<event>`, for example `bookings.updated`.
  final String type;

  /// The payload's string data (unmodifiable).
  final Map<String, String> data;

  /// Validates [raw], or returns null when it is not a valid payload.
  static NavigationPayload? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final type = raw['type'];
    if (type is! String || !RouteConventions.isRouteName(type)) return null;
    final rawData = raw['data'] ?? const <String, Object?>{};
    if (rawData is! Map || rawData.length > maxEntries) return null;
    final data = <String, String>{};
    for (final MapEntry(:key, :value) in rawData.entries) {
      if (key is! String || !RouteConventions.isQueryKey(key)) return null;
      if (value is! String || value.length > maxValueLength) return null;
      data[key] = value;
    }
    return NavigationPayload._(type, Map.unmodifiable(data));
  }

  @override
  String toString() => 'NavigationPayload($type)';
}

/// Maps a validated [NavigationPayload] to an in-app location, or null when
/// the payload cannot be opened. Must be pure: no I/O, no navigation.
typedef NotificationLocationResolver = String? Function(
  NavigationPayload payload,
);

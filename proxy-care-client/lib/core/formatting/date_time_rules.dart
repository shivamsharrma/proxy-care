/// The app's date and time rules. Pure Dart.
///
/// 1. **Instants** (a moment: pickup time, payment time; `timestamptz` in
///    the database) travel as ISO-8601 with an offset, are held as UTC
///    `DateTime`s ([ApiDateTime.parseInstant]) and are shown in the
///    service time zone ([ServiceTimeZone.india]), labelled, whatever the
///    device's zone. A sponsor abroad sees the pickup time the caretaker
///    and patient will see.
/// 2. **Civil dates** (a calendar day with no time: visit date; `date` in
///    the database) travel as `yyyy-MM-dd`, are held as a UTC-midnight
///    `DateTime` ([ApiDateTime.parseDate]) and are never converted between
///    zones.
/// 3. A time the user picks for a visit is a wall-clock time in the
///    service zone; [ServiceTimeZone.instantAt] turns it into an instant.
/// 4. Never call `DateTime.now()` in features to decide what day it is in
///    the service zone; convert with [ServiceTimeZone.toWallClock].
library;

/// A fixed-offset time zone in which visits happen.
///
/// shortcut: fixed offset only, because India has no daylight saving time;
/// upgrade to the `timezone` package (IANA rules) if the service extends to
/// a region with DST.
final class ServiceTimeZone {
  /// Creates a zone named [name] at [offset] from UTC.
  const ServiceTimeZone(this.name, this.offset);

  /// India Standard Time, UTC+05:30.
  static const india = ServiceTimeZone('IST', Duration(hours: 5, minutes: 30));

  /// Short display name, shown next to times.
  final String name;

  /// Offset from UTC.
  final Duration offset;

  /// The wall-clock fields of [instant] in this zone, as a UTC-flagged
  /// `DateTime` (only its fields are meaningful; format it, don't compare
  /// it with instants).
  DateTime toWallClock(DateTime instant) => instant.toUtc().add(offset);

  /// The instant at [hour]:[minute] on the civil [date] in this zone.
  DateTime instantAt(DateTime date, int hour, int minute) => DateTime.utc(
    date.year,
    date.month,
    date.day,
    hour,
    minute,
  ).subtract(offset);
}

/// Converting dates and instants to and from the API.
abstract final class ApiDateTime {
  static final RegExp _offset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');
  static final RegExp _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Parses an ISO-8601 instant that states its offset (`Z` or `+05:30`).
  /// Throws a [FormatException] for a time without offset, which would
  /// otherwise be read in the device's zone.
  static DateTime parseInstant(String value) {
    if (!value.contains('T') || !_offset.hasMatch(value)) {
      throw FormatException('Instant without a time zone offset', value);
    }
    return DateTime.parse(value).toUtc();
  }

  /// [instant] as ISO-8601 UTC, for the API.
  static String formatInstant(DateTime instant) =>
      instant.toUtc().toIso8601String();

  /// Parses a civil date `yyyy-MM-dd` to a UTC-midnight `DateTime`.
  static DateTime parseDate(String value) {
    if (!_date.hasMatch(value)) {
      throw FormatException('Expected yyyy-MM-dd', value);
    }
    final date = DateTime.parse('${value}T00:00:00Z');
    if (formatDate(date) != value) {
      throw FormatException('Not a calendar date', value);
    }
    return date;
  }

  /// The civil date of [date] as `yyyy-MM-dd` (its fields, no conversion).
  static String formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

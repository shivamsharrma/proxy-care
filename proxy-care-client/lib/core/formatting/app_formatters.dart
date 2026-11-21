import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'date_time_rules.dart';

/// Every user-facing date, time, number and amount format, in one place.
/// Features never build `DateFormat` or `NumberFormat` themselves.
///
/// - Instants are shown in [zone] (see `date_time_rules.dart`).
/// - Numbers and amounts use Indian digit grouping (`1,23,456`).
/// - Amounts are integer paise, as in the API; never `double` rupees.
///
/// Call [initialize] once before use (bootstrap does).
final class AppFormatters {
  /// Creates formatters for the [language] (an ARB locale such as `en`)
  /// in India.
  AppFormatters({String language = 'en', this.zone = ServiceTimeZone.india})
    : _date = DateFormat('d MMM y', language),
      _time = DateFormat('h:mm a', language),
      _number = NumberFormat.decimalPattern('${language}_IN'),
      _language = language;

  /// Loads the date symbols of every locale. Must complete before the first
  /// formatter is created.
  static Future<void> initialize() => initializeDateFormatting();

  /// The zone instants are shown in.
  final ServiceTimeZone zone;

  final DateFormat _date;
  final DateFormat _time;
  final NumberFormat _number;
  final String _language;

  /// A civil date: `15 Nov 2026`.
  String date(DateTime civilDate) => _date.format(civilDate);

  /// The date of an [instant] in [zone]: `15 Nov 2026`.
  String instantDate(DateTime instant) =>
      _date.format(zone.toWallClock(instant));

  /// The time of an [instant] in [zone]: `10:30 AM IST`.
  String instantTime(DateTime instant) =>
      '${_time.format(zone.toWallClock(instant))} ${zone.name}';

  /// Date and time of an [instant] in [zone]: `15 Nov 2026, 10:30 AM IST`.
  String instantDateTime(DateTime instant) =>
      '${instantDate(instant)}, ${instantTime(instant)}';

  /// A number with grouping: `1,23,456.5`.
  String number(num value) => _number.format(value);

  /// An amount in [paise] as rupees: `₹1,099`, or `₹1,099.50` when there
  /// are paise.
  String rupees(int paise) => NumberFormat.currency(
    locale: '${_language}_IN',
    symbol: '₹',
    decimalDigits: paise % 100 == 0 ? 0 : 2,
  ).format(paise / 100);
}

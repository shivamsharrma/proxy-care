import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/formatting/app_formatters.dart';
import 'package:proxy_care_client/core/formatting/date_time_rules.dart';

void main() {
  setUpAll(AppFormatters.initialize);

  group('ApiDateTime', () {
    test('instants need an offset and are held in UTC', () {
      final instant = ApiDateTime.parseInstant('2026-11-15T10:30:00+05:30');
      expect(instant, DateTime.utc(2026, 11, 15, 5));
      expect(instant.isUtc, isTrue);
      expect(
        ApiDateTime.parseInstant('2026-11-15T05:00:00Z'),
        DateTime.utc(2026, 11, 15, 5),
      );
      expect(ApiDateTime.formatInstant(instant), '2026-11-15T05:00:00.000Z');
      for (final naive in ['2026-11-15T10:30:00', '2026-11-15', 'soon']) {
        expect(
          () => ApiDateTime.parseInstant(naive),
          throwsFormatException,
          reason: naive,
        );
      }
    });

    test('civil dates round-trip without zone conversion', () {
      final date = ApiDateTime.parseDate('2026-03-01');
      expect(date, DateTime.utc(2026, 3));
      expect(ApiDateTime.formatDate(date), '2026-03-01');
      for (final bad in ['2026-02-30', '2026-3-1', '2026-03-01T00:00Z']) {
        expect(
          () => ApiDateTime.parseDate(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });
  });

  group('ServiceTimeZone', () {
    const ist = ServiceTimeZone.india;

    test('shows instants on the IST wall clock', () {
      final wall = ist.toWallClock(DateTime.utc(2026, 11, 14, 20));
      expect((wall.day, wall.hour, wall.minute), (15, 1, 30));
    });

    test('a picked IST time becomes the right instant', () {
      final instant = ist.instantAt(DateTime.utc(2026, 11, 15), 9, 15);
      expect(instant, DateTime.utc(2026, 11, 15, 3, 45));
      expect(ist.toWallClock(instant).hour, 9);
    });
  });

  group('AppFormatters', () {
    late AppFormatters formatters;
    setUp(() => formatters = AppFormatters());
    final instant = DateTime.utc(2026, 11, 15, 5); // 10:30 IST

    test('formats dates and instants in IST', () {
      expect(formatters.date(DateTime.utc(2026, 11, 15)), '15 Nov 2026');
      expect(formatters.instantTime(instant), '10:30 AM IST');
      expect(formatters.instantDateTime(instant), '15 Nov 2026, 10:30 AM IST');
      expect(
        formatters.instantDate(DateTime.utc(2026, 11, 14, 19)),
        '15 Nov 2026',
        reason: 'already the next day in IST',
      );
    });

    test('device time zone does not matter for instants', () {
      expect(formatters.instantTime(instant.toLocal()), '10:30 AM IST');
    });

    test('formats numbers with Indian grouping', () {
      expect(formatters.number(1234567), '12,34,567');
      expect(formatters.number(1234.5), '1,234.5');
    });

    test('formats paise as rupees', () {
      expect(formatters.rupees(109900), '₹1,099');
      expect(formatters.rupees(109950), '₹1,099.50');
      expect(formatters.rupees(12345600), '₹1,23,456');
      expect(formatters.rupees(0), '₹0');
      expect(formatters.rupees(-9900), '-₹99');
    });
  });
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get errorNetwork =>
      'Unable to connect. Please check your internet connection.';

  @override
  String get errorTimeout => 'The request took too long. Please try again.';

  @override
  String get errorUnauthenticated =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorForbidden =>
      'You don\'t have permission to perform this action.';

  @override
  String get errorNotFound => 'The requested information could not be found.';

  @override
  String get errorValidation => 'Please check the entered information.';

  @override
  String get errorConflict =>
      'This information has changed. Please refresh and try again.';

  @override
  String get errorBusinessRule =>
      'This action cannot be completed at the moment.';

  @override
  String get errorRateLimited => 'Too many requests. Please try again later.';

  @override
  String get errorServer =>
      'Something went wrong on our end. Please try again later.';

  @override
  String get errorServiceUnavailable =>
      'The service is temporarily unavailable. Please try again.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String get a11yBack => 'Back';

  @override
  String get a11yClose => 'Close';

  @override
  String get a11yOtpField => 'One-time code';

  @override
  String a11yOtpDigit(int position, int length) {
    return 'Digit $position of $length';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String a11yStepProgress(int current, int total) {
    return 'Step $current of $total';
  }
}

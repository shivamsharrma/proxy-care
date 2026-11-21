import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Shown when the app cannot reach the server (NETWORK_ERROR).
  ///
  /// In en, this message translates to:
  /// **'Unable to connect. Please check your internet connection.'**
  String get errorNetwork;

  /// Shown when a request timed out (TIMEOUT).
  ///
  /// In en, this message translates to:
  /// **'The request took too long. Please try again.'**
  String get errorTimeout;

  /// Shown when the session is missing or expired (UNAUTHENTICATED).
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get errorUnauthenticated;

  /// Shown when the user may not perform the action (FORBIDDEN).
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to perform this action.'**
  String get errorForbidden;

  /// Shown when the requested resource does not exist (NOT_FOUND).
  ///
  /// In en, this message translates to:
  /// **'The requested information could not be found.'**
  String get errorNotFound;

  /// Shown when the backend rejected the entered data (VALIDATION_ERROR). Also used next to a field the backend rejected.
  ///
  /// In en, this message translates to:
  /// **'Please check the entered information.'**
  String get errorValidation;

  /// Shown when the data changed on the server meanwhile (CONFLICT).
  ///
  /// In en, this message translates to:
  /// **'This information has changed. Please refresh and try again.'**
  String get errorConflict;

  /// Shown when a business rule prevents the action (BUSINESS_RULE_VIOLATION).
  ///
  /// In en, this message translates to:
  /// **'This action cannot be completed at the moment.'**
  String get errorBusinessRule;

  /// Shown when the backend is rate limiting the user (RATE_LIMITED).
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later.'**
  String get errorRateLimited;

  /// Shown for server failures (SERVER_ERROR / INTERNAL_ERROR).
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our end. Please try again later.'**
  String get errorServer;

  /// Shown when the service is down or overloaded (SERVICE_UNAVAILABLE).
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Please try again.'**
  String get errorServiceUnavailable;

  /// Shown for any error that has no more specific message (UNKNOWN_ERROR).
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnknown;

  /// Screen-reader label of the back button in the top app bar.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get a11yBack;

  /// Screen-reader label of close buttons (top app bar, info tip).
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get a11yClose;

  /// Screen-reader label of the one-time code input.
  ///
  /// In en, this message translates to:
  /// **'One-time code'**
  String get a11yOtpField;

  /// Screen-reader label of one cell of the one-time code input.
  ///
  /// In en, this message translates to:
  /// **'Digit {position} of {length}'**
  String a11yOtpDigit(int position, int length);

  /// A duration in whole hours, e.g. the caretaker's booked block ('3 hours').
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String durationHours(int count);

  /// Screen-reader label of the step progress bar in multi-step flows.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String a11yStepProgress(int current, int total);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

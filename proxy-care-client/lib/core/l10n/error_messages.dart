import '../error/failure.dart';
import '../error/user_error_kind.dart';
import 'generated/app_localizations.dart';

/// User-facing error messages, from localization resources only.
///
/// Raw backend messages, exception text and stack traces are never shown:
/// the message depends only on the failure's [UserErrorKind]. Adding a
/// language means adding an ARB file; this code does not change.
extension ErrorMessages on AppLocalizations {
  /// The localized message for [kind].
  String errorMessage(UserErrorKind kind) => switch (kind) {
    UserErrorKind.network => errorNetwork,
    UserErrorKind.timeout => errorTimeout,
    UserErrorKind.unauthenticated => errorUnauthenticated,
    UserErrorKind.forbidden => errorForbidden,
    UserErrorKind.notFound => errorNotFound,
    UserErrorKind.validation => errorValidation,
    UserErrorKind.conflict => errorConflict,
    UserErrorKind.businessRule => errorBusinessRule,
    UserErrorKind.rateLimited => errorRateLimited,
    UserErrorKind.server => errorServer,
    UserErrorKind.serviceUnavailable => errorServiceUnavailable,
    UserErrorKind.unknown => errorUnknown,
  };

  /// The message to show for [failure], or null when there is nothing to
  /// show (a cancelled operation).
  String? failureMessage(AppFailure failure) {
    final kind = UserErrorKind.of(failure);
    return kind == null ? null : errorMessage(kind);
  }

  /// The message to show under [field] when [failure] rejected it, or null
  /// when the field is fine. Pass it to `PcTextField.error`.
  ///
  /// The backend's field messages are not localized, so by default the
  /// field shows the localized validation message. Set [backendText] only
  /// for an endpoint whose field messages are agreed to be user-facing.
  String? fieldErrorMessage(
    AppFailure? failure,
    String field, {
    bool backendText = false,
  }) {
    if (failure is! ValidationFailure) return null;
    final messages = failure.errorsFor(field);
    if (messages.isEmpty) return null;
    return backendText ? messages.first : errorValidation;
  }
}

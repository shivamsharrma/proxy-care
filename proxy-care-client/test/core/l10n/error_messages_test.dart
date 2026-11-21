import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/core/error/failure.dart';
import 'package:proxy_care_client/core/error/user_error_kind.dart';
import 'package:proxy_care_client/core/l10n/error_messages.dart';
import 'package:proxy_care_client/core/l10n/generated/app_localizations.dart';

final class _SlotTaken extends DomainFailure {
  const _SlotTaken() : super('slot taken');
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('UserErrorKind.of', () {
    final cases = <AppFailure, UserErrorKind?>{
      const NetworkFailure('x'): UserErrorKind.network,
      const NetworkFailure('x', isTimeout: true): UserErrorKind.timeout,
      const UnauthorizedFailure('x'): UserErrorKind.unauthenticated,
      const ForbiddenFailure('x'): UserErrorKind.forbidden,
      const NotFoundFailure('x'): UserErrorKind.notFound,
      const ValidationFailure('x'): UserErrorKind.validation,
      const ConflictFailure('x'): UserErrorKind.conflict,
      const BusinessRuleFailure('x'): UserErrorKind.businessRule,
      const _SlotTaken(): UserErrorKind.businessRule,
      const RateLimitedFailure('x'): UserErrorKind.rateLimited,
      const ServerFailure('x'): UserErrorKind.server,
      const ServiceUnavailableFailure('x'): UserErrorKind.serviceUnavailable,
      const UnexpectedFailure('x'): UserErrorKind.unknown,
      const CancelledFailure('x'): null,
    };

    for (final MapEntry(key: failure, value: kind) in cases.entries) {
      test('${failure.runtimeType} → $kind', () {
        expect(UserErrorKind.of(failure), kind);
      });
    }
  });

  group('English messages', () {
    test('match the agreed copy', () {
      expect(
        l10n.errorMessage(UserErrorKind.network),
        'Unable to connect. Please check your internet connection.',
      );
      expect(
        l10n.errorMessage(UserErrorKind.timeout),
        'The request took too long. Please try again.',
      );
      expect(
        l10n.errorMessage(UserErrorKind.unauthenticated),
        'Your session has expired. Please sign in again.',
      );
      expect(
        l10n.errorMessage(UserErrorKind.forbidden),
        "You don't have permission to perform this action.",
      );
      expect(
        l10n.errorMessage(UserErrorKind.notFound),
        'The requested information could not be found.',
      );
      expect(
        l10n.errorMessage(UserErrorKind.validation),
        'Please check the entered information.',
      );
      expect(
        l10n.errorMessage(UserErrorKind.conflict),
        'This information has changed. Please refresh and try again.',
      );
      expect(
        l10n.errorMessage(UserErrorKind.businessRule),
        'This action cannot be completed at the moment.',
      );
      expect(
        l10n.errorMessage(UserErrorKind.rateLimited),
        'Too many requests. Please try again later.',
      );
      expect(
        l10n.errorMessage(UserErrorKind.server),
        'Something went wrong on our end. Please try again later.',
      );
      expect(
        l10n.errorMessage(UserErrorKind.serviceUnavailable),
        'The service is temporarily unavailable. Please try again.',
      );
      expect(
        l10n.errorMessage(UserErrorKind.unknown),
        'Something went wrong. Please try again.',
      );
    });

    test('never show the backend message or the cause', () {
      const failure = ServerFailure(
        'NullPointerException at BookingService.java:88',
        statusCode: 500,
        cause: 'stack trace',
      );

      final message = l10n.failureMessage(failure)!;
      expect(message, isNot(contains('NullPointer')));
      expect(message, isNot(contains('stack')));
      expect(message, l10n.errorServer);
    });

    test('a cancelled operation shows nothing', () {
      expect(l10n.failureMessage(const CancelledFailure('x')), isNull);
    });
  });

  group('field errors', () {
    const failure = ValidationFailure(
      'Request validation failed',
      fieldErrors: {
        'email': ['Invalid email address'],
      },
    );

    test('a rejected field shows the localized message by default', () {
      expect(l10n.fieldErrorMessage(failure, 'email'), l10n.errorValidation);
    });

    test('backend field text is shown only when asked for', () {
      expect(
        l10n.fieldErrorMessage(failure, 'email', backendText: true),
        'Invalid email address',
      );
    });

    test('other fields and other failures show nothing', () {
      expect(l10n.fieldErrorMessage(failure, 'name'), isNull);
      expect(
        l10n.fieldErrorMessage(const NetworkFailure('x'), 'email'),
        isNull,
      );
      expect(l10n.fieldErrorMessage(null, 'email'), isNull);
    });
  });
}

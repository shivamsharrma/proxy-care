import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/error/backend_error_code.dart';
import 'package:proxy_care_client/core/error/backend_error_parser.dart';
import 'package:proxy_care_client/core/error/error_mapper.dart';
import 'package:proxy_care_client/core/error/failure.dart';
import 'package:proxy_care_client/core/error/failure_mapper.dart';
import 'package:proxy_care_client/core/error/user_error_kind.dart';
import 'package:proxy_care_client/core/l10n/error_messages.dart';
import 'package:proxy_care_client/core/l10n/generated/app_localizations.dart';

import '../../helpers/backend_api_error.dart';

final _options = RequestOptions(path: '/bookings');

DioException _dio(DioExceptionType type, {Object? error}) =>
    DioException(requestOptions: _options, type: type, error: error);

DioException _response(
  int status, [
  Object? data,
  Map<String, List<String>> headers = const {},
]) => DioException(
  requestOptions: _options,
  type: DioExceptionType.badResponse,
  response: Response<Object?>(
    requestOptions: _options,
    statusCode: status,
    data: data,
    headers: Headers.fromMap(headers),
  ),
);

void main() {
  const mapper = ErrorMapper();

  group('DioException types', () {
    final cases = <DioExceptionType, Type>{
      DioExceptionType.connectionTimeout: TimeoutException,
      DioExceptionType.sendTimeout: TimeoutException,
      DioExceptionType.receiveTimeout: TimeoutException,
      DioExceptionType.transformTimeout: TimeoutException,
      DioExceptionType.cancel: CancelledException,
      DioExceptionType.connectionError: NetworkException,
      DioExceptionType.badCertificate: NetworkException,
      DioExceptionType.unknown: UnknownException,
    };

    for (final MapEntry(key: type, value: expected) in cases.entries) {
      test('$type → $expected', () {
        final error = _dio(type);
        final mapped = mapper.map(error);

        expect(mapped.runtimeType, expected);
        expect(mapped.cause, same(error));
      });
    }

    test('unknown wrapping an AppException returns it', () {
      const inner = NotFoundException();
      expect(
        mapper.map(_dio(DioExceptionType.unknown, error: inner)),
        same(inner),
      );
    });

    test('unknown wrapping a decoding error is an invalid response', () {
      final mapped = mapper.map(
        _dio(DioExceptionType.unknown, error: const FormatException('<html>')),
      );

      expect(mapped, isA<ServerException>());
      expect((mapped as ServerException).invalidResponse, isTrue);
    });
  });

  group('HTTP status codes', () {
    final cases = <int, Type>{
      400: ValidationException,
      401: UnauthorizedException,
      403: ForbiddenException,
      404: NotFoundException,
      408: TimeoutException,
      405: ServerException,
      406: ServerException,
      409: ServerException,
      410: NotFoundException,
      412: ServerException,
      413: ServerException,
      415: ServerException,
      422: ServerException,
      428: ServerException,
      429: ServerException,
      500: ServerException,
      502: ServerException,
      503: ServerException,
      504: TimeoutException,
    };

    for (final MapEntry(key: status, value: expected) in cases.entries) {
      test('$status → $expected', () {
        final mapped = mapper.map(_response(status));

        expect(mapped.runtimeType, expected);
        expect(mapped.statusCode, status);
      });
    }

    test('a response without a status is a server error', () {
      final error = DioException(
        requestOptions: _options,
        type: DioExceptionType.badResponse,
      );

      expect(mapper.map(error), isA<ServerException>());
    });
  });

  group('ApiError bodies', () {
    test('the default mapper reads bodies with BackendErrorParser', () {
      expect(mapper.parser, BackendErrorParser.parse);
    });

    test('keeps code and trace id, never the server message', () {
      final mapped = mapper.map(
        _response(
          409,
          apiErrorBody(
            'RESOURCE_ALREADY_EXISTS',
            message: 'The requested operation conflicts with existing data',
            traceId: '4bf92f3577b34da6a3ce929d0e0e4736',
          ),
        ),
      );

      expect(mapped, isA<ServerException>());
      expect(mapped.code, 'RESOURCE_ALREADY_EXISTS');
      expect(mapped.errorCode, BackendErrorCode.resourceAlreadyExists);
      expect(mapped.message, 'The server failed to handle the request.');
      expect(mapped.traceId, '4bf92f3577b34da6a3ce929d0e0e4736');
    });

    test('reads an ApiError string body', () {
      final mapped = mapper.map(
        _response(
          403,
          '{"code":"ACCESS_DENIED","message":"Access denied",'
          '"meta":{"traceId":"t-1","timestamp":"2026-11-22T09:30:00Z"}}',
        ),
      );

      expect(mapped, isA<ForbiddenException>());
      expect(mapped.errorCode, BackendErrorCode.accessDenied);
      expect(mapped.traceId, 't-1');
    });

    test('keeps an unknown code as sent and classifies by status', () {
      final conflict = mapper.map(
        _response(409, apiErrorBody('EMAIL_ALREADY_IN_USE')),
      );
      final notFound = mapper.map(
        _response(404, apiErrorBody('APP_USER_NOT_FOUND')),
      );

      expect(conflict.code, 'EMAIL_ALREADY_IN_USE');
      expect(conflict.errorCode, isNull);
      expect(conflict, isA<ServerException>());
      expect(conflict.traceId, testTraceId);
      expect(notFound, isA<NotFoundException>());
      expect(notFound.code, 'APP_USER_NOT_FOUND');
      expect(notFound.errorCode, isNull);
    });

    test('a missing code falls back to the status', () {
      final mapped = mapper.map(_response(401, apiErrorBody(null)));

      expect(mapped, isA<UnauthorizedException>());
      expect(mapped.code, isNull);
    });

    test('a body without meta still maps, with no trace id', () {
      final mapped = mapper.map(
        _response(403, apiErrorBody('ACCESS_DENIED', includeMeta: false)),
      );

      expect(mapped, isA<ForbiddenException>());
      expect(mapped.errorCode, BackendErrorCode.accessDenied);
      expect(mapped.traceId, isNull);
    });

    test('a non-JSON or unrelated body falls back to the HTTP status', () {
      for (final (status, expected, message) in [
        (400, ValidationException, 'The request was invalid.'),
        (401, UnauthorizedException, 'Authentication is required.'),
        (403, ForbiddenException, 'The action is not allowed.'),
        (404, NotFoundException, 'The resource was not found.'),
        (502, ServerException, 'The server failed to handle the request.'),
      ]) {
        for (final body in <Object?>[
          '<html>Bad gateway</html>',
          {
            'success': false,
            'error': {'code': 'INTERNAL_ERROR'},
          },
          {'error': 'nope'},
          null,
        ]) {
          final mapped = mapper.map(_response(status, body));

          expect(mapped.runtimeType, expected, reason: '$status $body');
          expect(mapped.code, isNull, reason: '$status $body');
          expect(mapped.traceId, isNull, reason: '$status $body');
          expect(mapped.message, message, reason: '$status $body');
        }
      }
    });

    test('the HTTP status stays authoritative over the code', () {
      final mapped = mapper.map(
        _response(401, apiErrorBody('VALIDATION_FAILED')),
      );

      expect(mapped, isA<UnauthorizedException>());
    });

    test('an endpoint can supply its own parser', () {
      final custom = ErrorMapper(
        parser: (body) => BackendError(
          code: (body! as Map<String, Object?>)['reason'] as String?,
        ),
      );

      final mapped = custom.map(
        _response(409, {'reason': 'RESOURCE_ALREADY_EXISTS'}),
      );
      expect(mapped.errorCode, BackendErrorCode.resourceAlreadyExists);

      final perCall = mapper.fromResponse(
        404,
        {'legacyCode': 'GONE'},
        parser: (body) => const BackendError(code: 'RESOURCE_NOT_FOUND'),
      );
      expect(perCall.errorCode, BackendErrorCode.resourceNotFound);
    });
  });

  group('backend codes by status', () {
    test('400 INVALID_PARAMETER is a validation error without fields', () {
      final mapped = mapper.map(
        _response(
          400,
          apiErrorBody(
            'INVALID_PARAMETER',
            message: 'HTTP method not supported',
          ),
        ),
      );

      expect(mapped, isA<ValidationException>());
      expect(mapped.errorCode, BackendErrorCode.invalidParameter);
      expect((mapped as ValidationException).fieldErrors, isEmpty);
      expect(mapped.traceId, testTraceId);
    });

    test('415 UNSUPPORTED_MEDIA_TYPE is a non-retryable server failure', () {
      final mapped = mapper.map(
        _response(
          415,
          apiErrorBody(
            'UNSUPPORTED_MEDIA_TYPE',
            message: 'Unsupported media type',
          ),
        ),
      );

      expect(mapped, isA<ServerException>());
      expect(mapped.statusCode, 415);
      expect(mapped.errorCode, BackendErrorCode.unsupportedMediaType);
      final failure = mapped.toFailure();
      expect(failure, isA<ServerFailure>());
      expect(failure.isRetryable, isFalse);
    });

    test('401 UNAUTHENTICATED is unauthorized', () {
      final mapped = mapper.map(
        _response(401, apiErrorBody('UNAUTHENTICATED')),
      );

      expect(mapped, isA<UnauthorizedException>());
      expect(mapped.errorCode, BackendErrorCode.unauthenticated);
      expect(mapped.traceId, testTraceId);
    });

    test('403 ACCESS_DENIED is forbidden', () {
      final mapped = mapper.map(
        _response(403, apiErrorBody('ACCESS_DENIED', message: 'Access denied')),
      );

      expect(mapped, isA<ForbiddenException>());
      expect(mapped.code, 'ACCESS_DENIED');
      expect(mapped.errorCode, BackendErrorCode.accessDenied);
      expect(mapped.traceId, testTraceId);
    });

    test('404 RESOURCE_NOT_FOUND and PROFILE_NOT_FOUND are not found', () {
      final notFound = mapper.map(
        _response(404, apiErrorBody('RESOURCE_NOT_FOUND')),
      );
      final noProfile = mapper.map(
        _response(404, apiErrorBody('PROFILE_NOT_FOUND')),
      );

      expect(notFound, isA<NotFoundException>());
      expect(notFound.errorCode, BackendErrorCode.resourceNotFound);
      expect(notFound.traceId, testTraceId);
      expect(noProfile, isA<NotFoundException>());
      expect(noProfile.errorCode, BackendErrorCode.profileNotFound);
    });

    test('409 RESOURCE_ALREADY_EXISTS and CONCURRENT_MODIFICATION are '
        'conflicts', () {
      for (final (wire, code) in [
        ('RESOURCE_ALREADY_EXISTS', BackendErrorCode.resourceAlreadyExists),
        ('CONCURRENT_MODIFICATION', BackendErrorCode.concurrentModification),
      ]) {
        final mapped = mapper.map(_response(409, apiErrorBody(wire)));

        expect(mapped, isA<ServerException>(), reason: wire);
        expect(mapped.statusCode, 409, reason: wire);
        expect(mapped.errorCode, code, reason: wire);
        expect(mapped.traceId, testTraceId, reason: wire);
        expect(mapped.toFailure(), isA<ConflictFailure>(), reason: wire);
      }
    });

    test('a 422 BUSINESS_RULE_VIOLATION is a business-rule failure, not a validation error', () {
      final mapped = mapper.map(
        _response(422, apiErrorBody('BUSINESS_RULE_VIOLATION')),
      );

      expect(mapped, isA<ServerException>());
      expect(mapped.errorCode, BackendErrorCode.businessRuleViolation);
      expect(mapped.traceId, testTraceId);
      expect(mapped.toFailure(), isA<BusinessRuleFailure>());
    });

    test('a 422 with an unknown code is a business-rule failure', () {
      final mapped = mapper.map(
        _response(422, apiErrorBody('PAYOUT_NAME_MISMATCH')),
      );

      expect(mapped, isA<ServerException>());
      expect(mapped.statusCode, 422);
      expect(mapped.code, 'PAYOUT_NAME_MISMATCH');
      expect(mapped.errorCode, isNull);
      expect(mapped.message, 'The server failed to handle the request.');
      final failure = mapped.toFailure();
      expect(failure, isA<BusinessRuleFailure>());
      expect(failure.code, 'PAYOUT_NAME_MISMATCH');
    });

    test('413 PAYLOAD_TOO_LARGE is a server error', () {
      final mapped = mapper.map(
        _response(413, apiErrorBody('PAYLOAD_TOO_LARGE')),
      );

      expect(mapped, isA<ServerException>());
      expect(mapped.errorCode, BackendErrorCode.payloadTooLarge);
    });

    test('500 INTERNAL_ERROR is a retryable server failure', () {
      final mapped = mapper.map(
        _response(500, apiErrorBody('INTERNAL_ERROR')),
      );

      expect(mapped, isA<ServerException>());
      expect(mapped.errorCode, BackendErrorCode.internalError);
      expect(mapped.traceId, testTraceId);
      final failure = mapped.toFailure();
      expect(failure, isA<ServerFailure>());
      expect(failure.isRetryable, isTrue);
    });

    test('502 EXTERNAL_SERVICE_ERROR is a server failure', () {
      final mapped = mapper.map(
        _response(502, apiErrorBody('EXTERNAL_SERVICE_ERROR')),
      );

      expect(mapped, isA<ServerException>());
      expect(mapped.errorCode, BackendErrorCode.externalServiceError);
      expect(mapped.traceId, testTraceId);
      expect(mapped.toFailure(), isA<ServerFailure>());
    });

    test('503 EXTERNAL_SERVICE_UNAVAILABLE is service unavailable', () {
      final mapped = mapper.map(
        _response(503, apiErrorBody('EXTERNAL_SERVICE_UNAVAILABLE')),
      );

      expect(mapped, isA<ServerException>());
      expect(mapped.errorCode, BackendErrorCode.externalServiceUnavailable);
      expect(mapped.toFailure(), isA<ServiceUnavailableFailure>());
    });
  });

  group('Retry-After', () {
    test('is kept on a 429 and a 503', () {
      for (final (status, code) in [
        (429, null),
        (503, 'EXTERNAL_SERVICE_UNAVAILABLE'),
      ]) {
        final mapped = mapper.map(
          _response(status, apiErrorBody(code), {
            'retry-after': ['12'],
          }),
        );

        expect(
          (mapped as ServerException).retryAfter,
          const Duration(seconds: 12),
          reason: '$status',
        );
      }
    });

    test('is ignored on other statuses and when unreadable', () {
      final other = mapper.map(
        _response(500, apiErrorBody('INTERNAL_ERROR'), {
          'retry-after': ['12'],
        }),
      );
      final date = mapper.map(
        _response(503, apiErrorBody('EXTERNAL_SERVICE_UNAVAILABLE'), {
          'retry-after': ['Wed, 18 Nov 2026 09:30:00 GMT'],
        }),
      );
      final missing = mapper.map(_response(429, apiErrorBody(null)));

      expect((other as ServerException).retryAfter, isNull);
      expect((date as ServerException).retryAfter, isNull);
      expect((missing as ServerException).retryAfter, isNull);
    });

    test('parses seconds only', () {
      expect(parseRetryAfter('0'), Duration.zero);
      expect(parseRetryAfter(' 30 '), const Duration(seconds: 30));
      expect(parseRetryAfter('-1'), isNull);
      expect(parseRetryAfter('soon'), isNull);
      expect(parseRetryAfter(null), isNull);
    });
  });

  group('validation errors', () {
    test('field errors from the fieldErrors object', () {
      final mapped = mapper.map(
        _response(
          400,
          apiErrorBody(
            'VALIDATION_FAILED',
            message: 'Validation failed',
            fieldErrors: {
              'email': 'Invalid email address',
              'mobile': 'Enter 10 digits',
              'patient.age': 'must be at most 120',
            },
          ),
        ),
      );

      expect(mapped, isA<ValidationException>());
      final validation = mapped as ValidationException;
      expect(validation.statusCode, 400);
      expect(validation.errorCode, BackendErrorCode.validationFailed);
      expect(validation.fieldErrors, {
        'email': 'Invalid email address',
        'mobile': 'Enter 10 digits',
        'patient.age': 'must be at most 120',
      });
      expect(validation.traceId, testTraceId);
    });

    test('a 400 malformed request is a general validation error', () {
      final mapped = mapper.map(
        _response(
          400,
          apiErrorBody('MALFORMED_REQUEST', message: 'Invalid request'),
        ),
      );

      expect(mapped, isA<ValidationException>());
      expect(mapped.errorCode, BackendErrorCode.malformedRequest);
      expect((mapped as ValidationException).fieldErrors, isEmpty);
      expect(mapped.traceId, testTraceId);
    });

    test('field errors on another 4xx still make a validation error', () {
      final mapped = mapper.map(
        _response(
          409,
          apiErrorBody(
            'RESOURCE_ALREADY_EXISTS',
            fieldErrors: {'email': 'Already in use'},
          ),
        ),
      );

      expect(mapped, isA<ValidationException>());
      expect(mapped.statusCode, 409);
    });

    test('field errors on a 5xx stay a server error', () {
      final mapped = mapper.map(
        _response(
          500,
          apiErrorBody(
            'INTERNAL_ERROR',
            fieldErrors: {'otp': 'Code expired'},
          ),
        ),
      );

      expect(mapped, isA<ServerException>());
    });

    test('a 400 without a body is a general validation error', () {
      final mapped = mapper.map(_response(400));

      expect(mapped, isA<ValidationException>());
      expect((mapped as ValidationException).fieldErrors, isEmpty);
    });

    test('field errors cannot be modified', () {
      final mapped = mapper.map(
        _response(
          400,
          apiErrorBody('VALIDATION_FAILED', fieldErrors: {'pan': 'Required'}),
        ),
      ) as ValidationException;

      expect(mapped.fieldErrors, {'pan': 'Required'});
      expect(() => mapped.fieldErrors['x'] = 'y', throwsUnsupportedError);
      expect(() => mapped.fieldErrors.remove('pan'), throwsUnsupportedError);
    });

    test(
      'the validation failure names the invalid fields for inline errors',
      () {
        final failure = mapper
            .map(
              _response(
                400,
                apiErrorBody(
                  'VALIDATION_FAILED',
                  fieldErrors: {'emergencyContact': 'must be 10 digits'},
                ),
              ),
            )
            .toFailure();

        expect(failure, isA<ValidationFailure>());
        final validation = failure as ValidationFailure;
        expect(validation.code, 'VALIDATION_FAILED');
        expect(validation.invalidFields, {'emergencyContact'});
        expect(validation.hasErrorFor('emergencyContact'), isTrue);
        expect(validation.hasErrorFor('age'), isFalse);
      },
    );
  });

  group('user-facing text never comes from the server', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    const serverMessage =
        'Anita Deshmukh (+919876543210) is already registered';
    const serverFieldMessage = 'Anita Deshmukh is not a valid name';

    AppFailure validationFailure() => mapper
        .map(
          _response(
            400,
            apiErrorBody(
              'VALIDATION_FAILED',
              message: serverMessage,
              fieldErrors: {'fullName': serverFieldMessage},
            ),
          ),
        )
        .toFailure();

    test('the exception carries its default message, not the server text', () {
      for (final (status, code, message) in [
        (400, 'VALIDATION_FAILED', 'The request was invalid.'),
        (401, 'UNAUTHENTICATED', 'Authentication is required.'),
        (403, 'ACCESS_DENIED', 'The action is not allowed.'),
        (404, 'PROFILE_NOT_FOUND', 'The resource was not found.'),
        (
          409,
          'RESOURCE_ALREADY_EXISTS',
          'The server failed to handle the request.',
        ),
        (
          422,
          'BUSINESS_RULE_VIOLATION',
          'The server failed to handle the request.',
        ),
        (500, 'INTERNAL_ERROR', 'The server failed to handle the request.'),
      ]) {
        final mapped = mapper.map(
          _response(
            status,
            apiErrorBody(
              code,
              message: serverMessage,
              fieldErrors: status == 400
                  ? {'fullName': serverFieldMessage}
                  : null,
            ),
          ),
        );

        expect(mapped.message, message, reason: code);
        expect('$mapped', isNot(contains('Anita')), reason: code);
        expect('${mapped.toFailure()}', isNot(contains('Anita')), reason: code);
      }
    });

    test('the failure message comes from the code mapping, not message', () {
      final shown = l10n.failureMessage(validationFailure());

      expect(shown, l10n.errorMessage(UserErrorKind.validation));
      expect(shown, isNot(contains('+919876543210')));
      expect(shown, isNot(contains(serverFieldMessage)));
    });

    test('a field shows the localized message, not the server text', () {
      final failure = validationFailure();

      expect(l10n.fieldErrorMessage(failure, 'fullName'), l10n.errorValidation);
      expect(l10n.fieldErrorMessage(failure, 'age'), isNull);
    });

    test('the validation failure exposes exactly the invalid field names', () {
      final failure =
          mapper
                  .map(
                    _response(
                      400,
                      apiErrorBody(
                        'VALIDATION_FAILED',
                        fieldErrors: {
                          'fullName': serverFieldMessage,
                          'emergencyContact': 'must be 10 digits',
                        },
                      ),
                    ),
                  )
                  .toFailure()
              as ValidationFailure;

      expect(failure.invalidFields, {'fullName', 'emergencyContact'});
      expect(failure.hasErrorFor('fullName'), isTrue);
      expect(failure.hasErrorFor('emergencyContact'), isTrue);
      expect(failure.hasErrorFor('age'), isFalse);
      expect(failure.hasErrorFor(''), isFalse);
      expect(() => failure.invalidFields.add('age'), throwsUnsupportedError);
    });

    test('the validation failure never exposes the server field text', () {
      final failure = validationFailure() as ValidationFailure;

      expect('$failure', isNot(contains('Anita')));
      expect(failure.message, isNot(contains('Anita')));
      expect(failure.invalidFields, {'fullName'});
      for (final field in failure.invalidFields) {
        expect(field, isNot(contains('Anita')));
      }
    });
  });

  group('serialization errors', () {
    test('invalid JSON', () {
      final mapped = mapper.map(const FormatException('Unexpected character'));

      expect(mapped, isA<ServerException>());
      expect((mapped as ServerException).invalidResponse, isTrue);
    });

    test('checked fromJson failure', () {
      final error = CheckedFromJsonException(
        const {'id': 1},
        'id',
        'UserDto',
        'type int is not a subtype of String',
      );

      final mapped = mapper.map(error);
      expect((mapped as ServerException).invalidResponse, isTrue);
      expect(mapped.cause, same(error));
    });
  });

  group('unexpected errors', () {
    test('an AppException passes through unchanged', () {
      const error = ForbiddenException();
      expect(mapper.map(error), same(error));
    });

    test('any other exception is unknown and keeps its cause', () {
      final error = Exception('boom');
      final mapped = mapper.map(error);

      expect(mapped, isA<UnknownException>());
      expect(mapped.cause, same(error));
    });

    test('an Error is unknown too (the guard decides whether to catch it)', () {
      expect(mapper.map(StateError('bug')), isA<UnknownException>());
    });
  });
}

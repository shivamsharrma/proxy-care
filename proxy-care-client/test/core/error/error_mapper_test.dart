import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/error/backend_error_code.dart';
import 'package:proxy_care_client/core/error/error_mapper.dart';

final _options = RequestOptions(path: '/bookings');

DioException _dio(DioExceptionType type, {Object? error}) =>
    DioException(requestOptions: _options, type: type, error: error);

/// A problem details body (ADR 0012).
Map<String, Object?> _problem({
  String? code,
  String? detail,
  List<Object?>? errors,
  String? traceId,
}) => {
  'type': 'urn:proxycare:problem:test',
  'title': 'Test title',
  'status': 400,
  'detail': ?detail,
  'instance': '/api/v1/bookings',
  'code': ?code,
  'traceId': ?traceId,
  'timestamp': '2026-11-18T09:30:00Z',
  'errors': ?errors,
};

Map<String, Object?> _field(String field, String message) => {
  'field': field,
  'code': 'Invalid',
  'message': message,
};

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
      422: ValidationException,
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

  group('problem details', () {
    test('reads code, detail and trace id', () {
      final mapped = mapper.map(
        _response(
          409,
          _problem(
            code: 'CONFLICT',
            detail: 'Booking version mismatch',
            traceId: '4bf92f3577b34da6a3ce929d0e0e4736',
          ),
        ),
      );

      expect(mapped, isA<ServerException>());
      expect(mapped.code, 'CONFLICT');
      expect(mapped.errorCode, BackendErrorCode.conflict);
      expect(mapped.message, 'Booking version mismatch');
      expect(mapped.traceId, '4bf92f3577b34da6a3ce929d0e0e4736');
    });

    test('falls back to the title for the log message', () {
      final mapped = mapper.map(_response(403, _problem(code: 'FORBIDDEN')));

      expect(mapped.message, 'Test title');
    });

    test('reads a problem+json string body', () {
      final mapped = mapper.map(
        _response(
          403,
          '{"type":"urn:proxycare:problem:forbidden","title":"Forbidden",'
          '"status":403,"code":"FORBIDDEN","traceId":"t-1"}',
        ),
      );

      expect(mapped, isA<ForbiddenException>());
      expect(mapped.errorCode, BackendErrorCode.forbidden);
      expect(mapped.traceId, 't-1');
    });

    test('knows every code of the ADR 0012 table', () {
      const table = {
        'MALFORMED_REQUEST': 400,
        'UNAUTHENTICATED': 401,
        'FORBIDDEN': 403,
        'NOT_FOUND': 404,
        'METHOD_NOT_ALLOWED': 405,
        'NOT_ACCEPTABLE': 406,
        'CONFLICT': 409,
        'PRECONDITION_FAILED': 412,
        'PAYLOAD_TOO_LARGE': 413,
        'UNSUPPORTED_MEDIA_TYPE': 415,
        'VALIDATION_ERROR': 422,
        'BUSINESS_RULE_VIOLATION': 422,
        'PRECONDITION_REQUIRED': 428,
        'RATE_LIMITED': 429,
        'INTERNAL_ERROR': 500,
        'UPSTREAM_ERROR': 502,
        'SERVICE_UNAVAILABLE': 503,
        'UPSTREAM_TIMEOUT': 504,
      };

      expect(BackendErrorCode.values, hasLength(table.length));
      for (final MapEntry(key: wire, value: status) in table.entries) {
        final code = BackendErrorCode.fromWire(wire);
        expect(code, isNotNull, reason: wire);
        expect(code!.impliedStatus, status, reason: wire);
      }
    });

    test('keeps an unknown code as sent and classifies by status', () {
      final conflict = mapper.map(
        _response(409, _problem(code: 'SLOT_TAKEN')),
      );
      final notFound = mapper.map(
        _response(404, _problem(code: 'SOMETHING_NEW')),
      );

      expect(conflict.code, 'SLOT_TAKEN');
      expect(conflict.errorCode, isNull);
      expect(conflict, isA<ServerException>());
      expect(notFound, isA<NotFoundException>());
    });

    test('a missing code falls back to the status', () {
      final mapped = mapper.map(_response(401, _problem()));

      expect(mapped, isA<UnauthorizedException>());
      expect(mapped.code, isNull);
    });

    test('ignores a body that is not a problem', () {
      for (final body in <Object?>[
        '<html>Bad gateway</html>',
        {
          'success': false,
          'error': {'code': 'INTERNAL_ERROR'},
        },
        null,
      ]) {
        final mapped = mapper.map(_response(502, body));

        expect(mapped, isA<ServerException>());
        expect(mapped.code, isNull);
        expect(mapped.message, 'The server failed to handle the request.');
      }
    });

    test('the HTTP status stays authoritative over the code', () {
      final mapped = mapper.map(
        _response(401, _problem(code: 'VALIDATION_ERROR')),
      );

      expect(mapped, isA<UnauthorizedException>());
    });

    test('a 422 business-rule violation is not a validation error', () {
      final mapped = mapper.map(
        _response(422, _problem(code: 'BUSINESS_RULE_VIOLATION')),
      );

      expect(mapped, isA<ServerException>());
      expect(mapped.errorCode, BackendErrorCode.businessRuleViolation);
    });

    test('an endpoint can supply its own parser', () {
      final custom = ErrorMapper(
        parser: (body) => BackendError(
          code: (body! as Map<String, Object?>)['reason'] as String?,
        ),
      );

      final mapped = custom.map(_response(409, {'reason': 'CONFLICT'}));
      expect(mapped.errorCode, BackendErrorCode.conflict);

      final perCall = mapper.fromResponse(
        404,
        {'legacyCode': 'GONE'},
        parser: (body) => const BackendError(code: 'NOT_FOUND'),
      );
      expect(perCall.errorCode, BackendErrorCode.notFound);
    });
  });

  group('Retry-After', () {
    test('is kept on a 429 and a 503', () {
      for (final status in [429, 503]) {
        final mapped = mapper.map(
          _response(status, _problem(), {
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
        _response(500, _problem(), {
          'retry-after': ['12'],
        }),
      );
      final date = mapper.map(
        _response(503, _problem(), {
          'retry-after': ['Wed, 18 Nov 2026 09:30:00 GMT'],
        }),
      );
      final missing = mapper.map(_response(429, _problem()));

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
    test('field errors from the errors array', () {
      final mapped = mapper.map(
        _response(
          422,
          _problem(
            code: 'VALIDATION_ERROR',
            detail: 'The request contains invalid values.',
            errors: [
              _field('email', 'Invalid email address'),
              _field('mobile', 'Enter 10 digits'),
              _field('mobile', 'Without 0 or +91'),
              _field('patient.age', 'must be at most 120'),
            ],
          ),
        ),
      );

      expect(mapped, isA<ValidationException>());
      final validation = mapped as ValidationException;
      expect(validation.errorCode, BackendErrorCode.validationError);
      expect(validation.fieldErrors, {
        'email': ['Invalid email address'],
        'mobile': ['Enter 10 digits', 'Without 0 or +91'],
        'patient.age': ['must be at most 120'],
      });
    });

    test('object-level errors are under the empty field name', () {
      final mapped = mapper.map(
        _response(
          422,
          _problem(
            code: 'VALIDATION_ERROR',
            errors: [
              _field('', 'End must be after start'),
              {'code': 'Consistent', 'message': 'Dates overlap'},
            ],
          ),
        ),
      );

      expect((mapped as ValidationException).fieldErrors, {
        '': ['End must be after start', 'Dates overlap'],
      });
    });

    test('an entry without a message keeps its constraint code', () {
      final mapped = mapper.map(
        _response(
          422,
          _problem(
            code: 'VALIDATION_ERROR',
            errors: [
              {'field': 'pan', 'code': 'NotBlank'},
              'not an object',
              {'field': 'x'},
            ],
          ),
        ),
      );

      expect((mapped as ValidationException).fieldErrors, {
        'pan': ['NotBlank'],
      });
    });

    test('a 400 malformed request is a general validation error', () {
      final mapped = mapper.map(
        _response(400, _problem(code: 'MALFORMED_REQUEST')),
      );

      expect(mapped, isA<ValidationException>());
      expect(mapped.errorCode, BackendErrorCode.malformedRequest);
      expect((mapped as ValidationException).fieldErrors, isEmpty);
    });

    test('field errors on another 4xx still make a validation error', () {
      final mapped = mapper.map(
        _response(
          409,
          _problem(
            code: 'CONFLICT',
            errors: [_field('otp', 'Code expired')],
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
          _problem(
            code: 'INTERNAL_ERROR',
            errors: [_field('otp', 'Code expired')],
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
          422,
          _problem(errors: [_field('pan', 'Required')]),
        ),
      ) as ValidationException;

      expect(() => mapped.fieldErrors['x'] = [], throwsUnsupportedError);
      expect(() => mapped.fieldErrors['pan']!.add('y'), throwsUnsupportedError);
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

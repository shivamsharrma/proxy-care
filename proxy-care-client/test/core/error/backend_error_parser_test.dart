import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/error/backend_error_parser.dart';

import '../../helpers/backend_api_error.dart';

/// Mirrors the backend's error body, `com.proxycare.common.api.ApiError
/// {code, message, fieldErrors, meta{traceId, timestamp}}`
/// (`@JsonInclude(NON_NULL)`), built by `ApiErrorFactory` for
/// `GlobalExceptionHandler` and `ApiErrorResponseWriter`. `fieldErrors` is
/// an object of field → first message (`FieldErrors`).
void main() {
  group('BackendErrorParser', () {
    test('reads code, message, field errors and meta.traceId', () {
      final error = BackendErrorParser.parse(
        apiErrorBody(
          'VALIDATION_FAILED',
          message: 'Validation failed',
          fieldErrors: {
            'age': 'must be less than or equal to 120',
            'fullName': 'must not be blank',
          },
          traceId: 'trace-1',
        ),
      );

      expect(error.code, 'VALIDATION_FAILED');
      expect(error.message, 'Validation failed');
      expect(error.fieldErrors, {
        'age': 'must be less than or equal to 120',
        'fullName': 'must not be blank',
      });
      expect(error.traceId, 'trace-1');
    });

    test('reads a nested property path as the field name', () {
      final error = BackendErrorParser.parse(
        apiErrorBody(
          'VALIDATION_FAILED',
          fieldErrors: {'patient.age': 'must be at most 120'},
        ),
      );

      expect(error.fieldErrors, {'patient.age': 'must be at most 120'});
    });

    test('reads an ApiError sent as a JSON string', () {
      final error = BackendErrorParser.parse(
        jsonEncode(
          apiErrorBody(
            'ACCESS_DENIED',
            message: 'Access denied',
            traceId: 'trace-2',
          ),
        ),
      );

      expect(error.code, 'ACCESS_DENIED');
      expect(error.message, 'Access denied');
      expect(error.traceId, 'trace-2');
    });

    test('a body without fieldErrors has no field errors', () {
      final error = BackendErrorParser.parse(
        apiErrorBody('RESOURCE_NOT_FOUND', message: 'Resource not found'),
      );

      expect(error.code, 'RESOURCE_NOT_FOUND');
      expect(error.fieldErrors, isEmpty);
      expect(error.traceId, testTraceId);
    });

    test('a body without meta has no trace id', () {
      final error = BackendErrorParser.parse(
        apiErrorBody('UNAUTHENTICATED', includeMeta: false),
      );

      expect(error.code, 'UNAUTHENTICATED');
      expect(error.traceId, isNull);
    });

    test('a meta without traceId has no trace id', () {
      final error = BackendErrorParser.parse(
        apiErrorBody('INTERNAL_ERROR', traceId: null),
      );

      expect(error.code, 'INTERNAL_ERROR');
      expect(error.traceId, isNull);
    });

    test('ignores malformed parts and keeps the rest', () {
      final error = BackendErrorParser.parse({
        'code': 'VALIDATION_FAILED',
        'message': 42,
        'fieldErrors': {
          'age': 'must be at least 18',
          'sex': 7,
          'address': null,
        },
        'meta': 'not an object',
      });

      expect(error.code, 'VALIDATION_FAILED');
      expect(error.message, isNull);
      expect(error.fieldErrors, {'age': 'must be at least 18'});
      expect(error.traceId, isNull);
    });

    test('fieldErrors that are not an object are ignored', () {
      for (final fieldErrors in <Object?>[
        [
          {'field': 'age', 'message': 'too high'},
        ],
        'age: too high',
        null,
      ]) {
        final error = BackendErrorParser.parse({
          'code': 'VALIDATION_FAILED',
          'message': 'Validation failed',
          'fieldErrors': fieldErrors,
        });

        expect(error.code, 'VALIDATION_FAILED', reason: '$fieldErrors');
        expect(error.fieldErrors, isEmpty, reason: '$fieldErrors');
      }
    });

    test('a non-JSON or unrelated body yields an empty error', () {
      for (final body in <Object?>[
        null,
        '',
        '<html><body>Bad gateway</body></html>',
        '{not json',
        'plain text',
        [1, 2, 3],
        42,
        {
          'success': false,
          'error': {'code': 'INTERNAL_ERROR'},
        },
      ]) {
        final error = BackendErrorParser.parse(body);

        expect(error.code, isNull, reason: '$body');
        expect(error.message, isNull, reason: '$body');
        expect(error.fieldErrors, isEmpty, reason: '$body');
        expect(error.traceId, isNull, reason: '$body');
      }
    });
  });
}

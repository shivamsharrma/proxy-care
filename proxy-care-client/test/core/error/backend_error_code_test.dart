import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/error/backend_error_code.dart';

/// Mirrors `com.proxycare.common.exception.ErrorCode` (name → HTTP
/// status). Backend codes are never renamed.
void main() {
  const backendErrorCodes = {
    'VALIDATION_FAILED': 400,
    'MALFORMED_REQUEST': 400,
    'INVALID_PARAMETER': 400,
    'UNSUPPORTED_MEDIA_TYPE': 415,
    'PAYLOAD_TOO_LARGE': 413,
    'UNAUTHENTICATED': 401,
    'ACCESS_DENIED': 403,
    'RESOURCE_NOT_FOUND': 404,
    'RESOURCE_ALREADY_EXISTS': 409,
    'BUSINESS_RULE_VIOLATION': 422,
    'CONCURRENT_MODIFICATION': 409,
    'PROFILE_NOT_FOUND': 404,
    'EXTERNAL_SERVICE_ERROR': 502,
    'EXTERNAL_SERVICE_UNAVAILABLE': 503,
    'INTERNAL_ERROR': 500,
  };

  group('BackendErrorCode', () {
    test('knows every backend ErrorCode with its HTTP status', () {
      for (final MapEntry(key: wire, value: status)
          in backendErrorCodes.entries) {
        final code = BackendErrorCode.fromWire(wire);

        expect(code, isNotNull, reason: wire);
        expect(code!.wireName, wire, reason: wire);
        expect(code.impliedStatus, status, reason: wire);
      }
    });

    test('has exactly the backend ErrorCode names', () {
      expect(
        BackendErrorCode.values.map((code) => code.wireName).toSet(),
        backendErrorCodes.keys.toSet(),
      );
    });

    test('each backend name maps to its client code', () {
      const expected = {
        'VALIDATION_FAILED': BackendErrorCode.validationFailed,
        'MALFORMED_REQUEST': BackendErrorCode.malformedRequest,
        'INVALID_PARAMETER': BackendErrorCode.invalidParameter,
        'UNSUPPORTED_MEDIA_TYPE': BackendErrorCode.unsupportedMediaType,
        'PAYLOAD_TOO_LARGE': BackendErrorCode.payloadTooLarge,
        'UNAUTHENTICATED': BackendErrorCode.unauthenticated,
        'ACCESS_DENIED': BackendErrorCode.accessDenied,
        'RESOURCE_NOT_FOUND': BackendErrorCode.resourceNotFound,
        'RESOURCE_ALREADY_EXISTS': BackendErrorCode.resourceAlreadyExists,
        'BUSINESS_RULE_VIOLATION': BackendErrorCode.businessRuleViolation,
        'CONCURRENT_MODIFICATION': BackendErrorCode.concurrentModification,
        'PROFILE_NOT_FOUND': BackendErrorCode.profileNotFound,
        'EXTERNAL_SERVICE_ERROR': BackendErrorCode.externalServiceError,
        'EXTERNAL_SERVICE_UNAVAILABLE':
            BackendErrorCode.externalServiceUnavailable,
        'INTERNAL_ERROR': BackendErrorCode.internalError,
      };

      for (final MapEntry(key: wire, value: code) in expected.entries) {
        expect(BackendErrorCode.fromWire(wire), code, reason: wire);
      }
    });

    test('the old client-only names are not backend codes', () {
      for (final wire in [
        'VALIDATION_ERROR',
        'FORBIDDEN',
        'NOT_FOUND',
        'CONFLICT',
        'UPSTREAM_ERROR',
        'UPSTREAM_TIMEOUT',
        'SERVICE_UNAVAILABLE',
      ]) {
        expect(BackendErrorCode.fromWire(wire), isNull, reason: wire);
      }
    });

    test('an unknown or missing code has no client code', () {
      expect(BackendErrorCode.fromWire('SOMETHING_NEW'), isNull);
      expect(BackendErrorCode.fromWire(''), isNull);
      expect(BackendErrorCode.fromWire(null), isNull);
    });
  });
}

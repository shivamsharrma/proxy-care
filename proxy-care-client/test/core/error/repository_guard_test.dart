import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/error/failure.dart';
import 'package:proxy_care_client/core/error/failure_mapper.dart';
import 'package:proxy_care_client/core/error/repository_guard.dart';
import 'package:proxy_care_client/core/error/serialization.dart';
import 'package:proxy_care_client/shared/models/result.dart';

import '../../mocks/core_mocks.dart';

final _options = RequestOptions(path: '/me');

/// Casting this to `int` is a programming error (a `TypeError`).
const Object _notAnInt = 'seven';

void main() {
  setUpAll(() => registerFallbackValue(StackTrace.empty));

  late MockErrorReporter reporter;
  setUp(() => reporter = MockErrorReporter());

  group('guardResult', () {
    test('wraps the value in a Success', () async {
      final result = await guardResult(() async => 'Kamla', reporter: reporter);

      expect(result, const Success('Kamla'));
      verifyZeroInteractions(reporter);
    });

    test('maps a Dio error to a failure without reporting it', () async {
      final result = await guardResult<String>(
        () async => throw DioException(
          requestOptions: _options,
          type: DioExceptionType.connectionError,
        ),
        reporter: reporter,
      );

      expect(result.failureOrNull, isA<NetworkFailure>());
      verifyZeroInteractions(reporter);
    });

    test('keeps backend validation errors for the form', () async {
      final result = await guardResult<void>(
        () async => throw DioException(
          requestOptions: _options,
          type: DioExceptionType.badResponse,
          response: Response<Object?>(
            requestOptions: _options,
            statusCode: 422,
            data: {
              'type': 'urn:proxycare:problem:validation-error',
              'title': 'Validation failed',
              'status': 422,
              'code': 'VALIDATION_ERROR',
              'traceId': '4bf92f35',
              'errors': [
                {
                  'field': 'mobile',
                  'code': 'Pattern',
                  'message': 'Enter 10 digits',
                },
              ],
            },
          ),
        ),
      );

      final failure = result.failureOrNull! as ValidationFailure;
      expect(failure.errorsFor('mobile'), ['Enter 10 digits']);
      expect(failure.errorsFor('name'), isEmpty);
    });

    test('reports unknown and unreadable-response failures', () async {
      final unknown = await guardResult<void>(
        () async => throw Exception('boom'),
        reporter: reporter,
      );
      final unreadable = await guardResult<void>(
        () async => decodeResponse<String>(() => throw const FormatException()),
        reporter: reporter,
      );

      expect(unknown.failureOrNull, isA<UnexpectedFailure>());
      expect(unreadable.failureOrNull, isA<ServerFailure>());
      verify(
        () => reporter.report(any(), any(), context: 'repository'),
      ).called(2);
    });

    test('returns a failure thrown inside the action as it is', () async {
      const failure = NotFoundFailure('gone');
      final result = await guardResult<int>(
        () async => const Result<int>.failure(failure).getOrThrow(),
      );

      expect(result.failureOrNull, same(failure));
    });

    test('rethrows programming errors instead of hiding them', () async {
      await expectLater(
        guardResult<void>(() async => throw StateError('bug')),
        throwsStateError,
      );
      await expectLater(
        guardResult<int>(() async => _notAnInt as int),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('decodeResponse', () {
    test('returns the parsed value', () {
      expect(decodeResponse(() => 7), 7);
    });

    test('turns a shape mismatch into an invalid-response exception', () {
      final json = <String, Object?>{'id': null};

      expect(
        () => decodeResponse(() => json['id']! as String),
        throwsA(
          isA<ServerException>().having(
            (e) => e.invalidResponse,
            'invalidResponse',
            isTrue,
          ),
        ),
      );
    });
  });

  group('AppException.toFailure', () {
    test('separates infrastructure exceptions from application failures', () {
      final cases = <AppException, Type>{
        const NetworkException(): NetworkFailure,
        const TimeoutException(): NetworkFailure,
        const UnauthorizedException(): UnauthorizedFailure,
        const ForbiddenException(): ForbiddenFailure,
        const NotFoundException(): NotFoundFailure,
        ValidationException(): ValidationFailure,
        const ServerException(): ServerFailure,
        const ServerException(statusCode: 409): ConflictFailure,
        const ServerException(statusCode: 412): ConflictFailure,
        const ServerException(statusCode: 428): ServerFailure,
        const ServerException(statusCode: 400, code: 'PRECONDITION_FAILED'):
            ConflictFailure,
        const ServerException(statusCode: 429): RateLimitedFailure,
        const ServerException(statusCode: 503): ServiceUnavailableFailure,
        const ServerException(statusCode: 500): ServerFailure,
        const ServerException(
          statusCode: 422,
          code: 'BUSINESS_RULE_VIOLATION',
        ): BusinessRuleFailure,
        const ServerException(statusCode: 500, code: 'CONFLICT'): ServerFailure,
        const ServerException(code: 'SERVICE_UNAVAILABLE'):
            ServiceUnavailableFailure,
        const ServerException.invalidResponse(statusCode: 409): ServerFailure,
        const CancelledException(): CancelledFailure,
        const UnknownException(): UnexpectedFailure,
      };

      for (final MapEntry(key: exception, value: expected) in cases.entries) {
        expect(
          exception.toFailure().runtimeType,
          expected,
          reason: '$exception',
        );
      }
    });

    test('keeps the details the app needs', () {
      final failure =
          ValidationException(
                fieldErrors: {
                  'pan': ['Required'],
                },
                code: 'VALIDATION_FAILED',
              ).toFailure()
              as ValidationFailure;

      expect(failure.fieldErrors, {
        'pan': ['Required'],
      });
      expect(failure.code, 'VALIDATION_FAILED');
      expect(
        (const TimeoutException().toFailure() as NetworkFailure).isTimeout,
        isTrue,
      );
      expect(
        (const ServerException(statusCode: 500).toFailure() as ServerFailure)
            .statusCode,
        500,
      );
    });

    test('keeps Retry-After on rate-limited and unavailable failures', () {
      const wait = Duration(seconds: 30);

      final limited =
          const ServerException(statusCode: 429, retryAfter: wait).toFailure()
              as RateLimitedFailure;
      final unavailable =
          const ServerException(statusCode: 503, retryAfter: wait).toFailure()
              as ServiceUnavailableFailure;

      expect(limited.retryAfter, wait);
      expect(unavailable.retryAfter, wait);
      expect(limited.isRetryable, isTrue);
    });
  });
}

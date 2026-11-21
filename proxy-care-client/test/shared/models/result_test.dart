import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/error/failure.dart';
import 'package:proxy_care_client/shared/models/result.dart';

/// A feature-style business-rule failure.
final class _SlotUnavailable extends DomainFailure {
  const _SlotUnavailable() : super('The selected slot was taken.');
}

void main() {
  const offline = NetworkFailure('offline');

  group('success', () {
    const Result<int> result = Result.success(42);

    test('holds the value', () {
      expect(result, isA<Success<int>>());
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
      expect(result.getOrThrow(), 42);
    });

    test('folds into the success branch', () {
      expect(
        result.fold(onSuccess: (v) => 'value $v', onFailure: (_) => 'failed'),
        'value 42',
      );
    });
  });

  group('failure', () {
    const Result<int> result = Result.failure(offline);

    test('holds the failure', () {
      expect(result, isA<Failure<int>>());
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, same(offline));
    });

    test('folds into the failure branch', () {
      expect(
        result.fold(
          onSuccess: (_) => 'value',
          onFailure: (failure) => failure.message,
        ),
        'offline',
      );
    });

    test('getOrThrow throws the failure itself', () {
      expect(result.getOrThrow, throwsA(same(offline)));
    });
  });

  group('transformations', () {
    test('map transforms a success and keeps the type safe', () {
      const Result<int> result = Success(2);
      final Result<String> mapped = result.map((v) => 'n=$v');

      expect(mapped, const Success('n=2'));
    });

    test('map passes a failure through untouched', () {
      const Result<int> result = Failure(offline);
      final mapped = result.map((v) => v * 2);

      expect(mapped, isA<Failure<int>>());
      expect(mapped.failureOrNull, same(offline));
    });

    test('flatMap chains operations and stops at the first failure', () {
      Result<int> half(int v) =>
          v.isEven ? Success(v ~/ 2) : const Failure(ValidationFailure('odd'));

      expect(const Success(8).flatMap(half).flatMap(half), const Success(2));
      expect(
        const Success(6).flatMap(half).flatMap(half).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        const Result<int>.failure(offline).flatMap(half).failureOrNull,
        same(offline),
      );
    });
  });

  test('is handled exhaustively, including failure subtypes', () {
    String describe(Result<int> result) => switch (result) {
      Success(:final value) => 'value $value',
      Failure(failure: ValidationFailure(:final fieldErrors)) =>
        'invalid ${fieldErrors.keys.join(',')}',
      Failure(failure: DomainFailure(:final message)) => 'rule: $message',
      Failure(:final failure) => 'failed: ${failure.runtimeType}',
    };

    expect(describe(const Success(1)), 'value 1');
    expect(
      describe(
        const Failure(
          ValidationFailure(
            'invalid',
            fieldErrors: {
              'mobile': ['Enter 10 digits'],
            },
          ),
        ),
      ),
      'invalid mobile',
    );
    expect(
      describe(const Failure(_SlotUnavailable())),
      'rule: The selected slot was taken.',
    );
    expect(describe(const Failure(offline)), 'failed: NetworkFailure');
  });

  test('compares by value', () {
    expect(const Success(1), const Success(1));
    expect(const Success(1).hashCode, const Success(1).hashCode);
    expect(const Success(1), isNot(const Success(2)));
    expect(const Failure<int>(offline), const Failure<int>(offline));
  });

  test('failures describe themselves without exposing a cause', () {
    const failure = ServerFailure(
      'upstream failed',
      statusCode: 503,
      code: 'UPSTREAM',
      cause: 'secret detail',
    );

    expect(failure.toString(), 'ServerFailure [UPSTREAM]: upstream failed');
    expect(failure.isRetryable, isTrue);
    expect(const ServerFailure('bad', statusCode: 409).isRetryable, isFalse);
    expect(offline.isRetryable, isTrue);
  });
}

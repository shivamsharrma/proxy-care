import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/error/failure.dart';
import 'package:proxy_care_client/shared/models/result.dart';

/// Matches a `Success` holding a value equal to (or matching) [value].
Matcher isSuccessWith(Object? value) =>
    isA<Success<Object?>>().having((s) => s.value, 'value', value);

/// Matches a `Failure` whose failure is an [F].
Matcher isFailureOf<F extends AppFailure>() =>
    isA<Failure<Object?>>().having((f) => f.failure, 'failure', isA<F>());

/// Matches a future or call that throws an [E] (an `AppException`).
Matcher throwsAppException<E extends AppException>() => throwsA(isA<E>());

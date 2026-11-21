import '../../shared/models/result.dart';
import 'app_exception.dart';
import 'error_mapper.dart';
import 'error_reporter.dart';
import 'failure.dart';
import 'failure_mapper.dart';

/// Runs a repository operation and returns its [Result]. This is the
/// repository error convention:
///
/// * the value of [action] becomes a [Success];
/// * an [Exception] (Dio, serialization, [AppException]) is mapped by
///   [mapper] to an [AppException] and then to an [AppFailure], returned as
///   a [Failure]. Unknown and unreadable-response failures are also sent to
///   [reporter];
/// * an [AppFailure] thrown inside [action] (for example by
///   `Result.getOrThrow` on a nested result) is returned as it is;
/// * an [Error] (`TypeError`, `StateError`, a failed assertion…) is a
///   programming error and is **rethrown**, so it reaches the global error
///   handlers instead of being disguised as an ordinary failure.
///
/// ```dart
/// Future<Result<User>> currentUser() => guardResult(
///   () async => (await _remote.fetchMe()).toEntity(),
///   mapper: _mapper,
///   reporter: _reporter,
/// );
/// ```
Future<Result<T>> guardResult<T>(
  Future<T> Function() action, {
  ErrorMapper mapper = const ErrorMapper(),
  ErrorReporter? reporter,
}) async {
  try {
    return Success(await action());
  } on AppFailure catch (failure) {
    return Failure(failure);
  } on Exception catch (error, stackTrace) {
    final exception = mapper.map(error);
    if (_shouldReport(exception)) {
      reporter?.report(error, stackTrace, context: 'repository');
    }
    return Failure(exception.toFailure());
  }
}

/// Failures nobody expected need a developer's attention; expected ones
/// (offline, validation, 404…) do not.
bool _shouldReport(AppException exception) => switch (exception) {
  UnknownException() => true,
  ServerException(:final invalidResponse, :final statusCode) =>
    invalidResponse || statusCode == null || statusCode >= 500,
  _ => false,
};

import '../../core/error/failure.dart';

/// The outcome of an operation that can fail in an expected way: a
/// [Success] holding a value or a [Failure] holding an [AppFailure].
///
/// Repositories and use cases return `Result` instead of throwing for
/// expected failures. Handle both cases with an exhaustive `switch`:
///
/// ```dart
/// switch (result) {
///   case Success(:final value):
///     // use value
///   case Failure(failure: ValidationFailure(:final fieldErrors)):
///     // show field errors
///   case Failure(:final failure):
///     // show a generic state for failure
/// }
/// ```
///
/// or with [fold]. Hand-written rather than generated with Freezed: a sealed
/// class with two variants needs no code generation.
sealed class Result<T> {
  const Result();

  /// A successful result holding [value].
  const factory Result.success(T value) = Success<T>;

  /// A failed result holding [failure].
  const factory Result.failure(AppFailure failure) = Failure<T>;

  /// Whether this is a [Success].
  bool get isSuccess => this is Success<T>;

  /// Whether this is a [Failure].
  bool get isFailure => this is Failure<T>;

  /// The value of a [Success], otherwise `null`.
  T? get valueOrNull => switch (this) {
    Success(:final value) => value,
    Failure() => null,
  };

  /// The failure of a [Failure], otherwise `null`.
  AppFailure? get failureOrNull => switch (this) {
    Success() => null,
    Failure(:final failure) => failure,
  };

  /// Collapses both cases into one value.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppFailure failure) onFailure,
  }) => switch (this) {
    Success(:final value) => onSuccess(value),
    Failure(:final failure) => onFailure(failure),
  };

  /// Transforms the value of a [Success]; a [Failure] passes through.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success(:final value) => Success(transform(value)),
    Failure(:final failure) => Failure(failure),
  };

  /// Chains an operation that can itself fail; a [Failure] passes through.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
    Success(:final value) => transform(value),
    Failure(:final failure) => Failure(failure),
  };

  /// The value of a [Success]; throws the [AppFailure] of a [Failure].
  ///
  /// For Riverpod `AsyncNotifier.build`, where a thrown failure becomes
  /// `AsyncValue.error`.
  T getOrThrow() => switch (this) {
    Success(:final value) => value,
    Failure(:final failure) => throw failure,
  };
}

/// A successful [Result].
final class Success<T> extends Result<T> {
  /// Creates a successful result holding [value].
  const Success(this.value);

  /// The produced value.
  final T value;

  @override
  bool operator ==(Object other) => other is Success<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Success, value);

  @override
  String toString() => 'Success($value)';
}

/// A failed [Result].
final class Failure<T> extends Result<T> {
  /// Creates a failed result holding [failure].
  const Failure(this.failure);

  /// What went wrong.
  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is Failure<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Failure, failure);

  @override
  String toString() => 'Failure($failure)';
}

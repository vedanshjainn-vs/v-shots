// ════════════════════════════════════════════════
// Project Lyra — Result Type
// ════════════════════════════════════════════════
//
// Type-safe result wrapper that replaces
// raw exceptions. Every operation returns
// Result<T> instead of throwing.
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import 'failure.dart';

/// Type alias for Either<Failure, T>.
typedef Result<T> = Either<Failure, T>;

/// Type alias for Future<Either<Failure, T>>.
typedef FutureResult<T> = Future<Either<Failure, T>>;

/// Extension methods on [Result] for ergonomic usage.
extension ResultExtensions<T> on Either<Failure, T> {
  /// Whether this result is a success.
  bool get isSuccess => isRight();

  /// Whether this result is a failure.
  bool get isFailure => isLeft();

  /// Extract data if success, null otherwise.
  T? get dataOrNull => fold((_) => null, (data) => data);

  /// Extract failure if failure, null otherwise.
  Failure? get failureOrNull => fold((f) => null, (_) => null);

  /// Extract data or throw the failure.
  T get dataOrThrow => fold(
        (failure) => throw failure,
        (data) => data,
      );

  /// Extract data or return a default value.
  T dataOr(T defaultValue) => fold((_) => defaultValue, (data) => data);

  /// Map the success value.
  Either<Failure, R> mapData<R>(R Function(T) mapper) {
    return map(mapper);
  }

  /// FlatMap (bind) for chaining operations.
  Future<Either<Failure, R>> flatMap<R>(
    Future<Either<Failure, R>> Function(T) mapper,
  ) async {
    return fold(
      (failure) => Left(failure),
      (data) => mapper(data),
    );
  }

  /// Execute a side effect on success.
  Either<Failure, T> onSuccess(void Function(T) callback) {
    return fold(
      (failure) => Left(failure),
      (data) {
        callback(data);
        return Right(data);
      },
    );
  }

  /// Execute a side effect on failure.
  Either<Failure, T> onFailure(void Function(Failure) callback) {
    return fold(
      (failure) {
        callback(failure);
        return Left(failure);
      },
      (data) => Right(data),
    );
  }
}

/// Extension on [FutureResult] for async chaining.
extension FutureResultExtensions<T> on Future<Either<Failure, T>> {
  /// Map the success value asynchronously.
  Future<Either<Failure, R>> mapData<R>(R Function(T) mapper) async {
    final result = await this;
    return result.map(mapper);
  }

  /// FlatMap for chaining async operations.
  Future<Either<Failure, R>> flatMap<R>(
    Future<Either<Failure, R>> Function(T) mapper,
  ) async {
    final result = await this;
    return result.fold(
      (failure) => Left(failure),
      (data) => mapper(data),
    );
  }

  /// Execute a side effect on success.
  Future<Either<Failure, T>> onSuccess(void Function(T) callback) async {
    final result = await this;
    return result.onSuccess(callback);
  }

  /// Execute a side effect on failure.
  Future<Either<Failure, T>> onFailure(void Function(Failure) callback) async {
    final result = await this;
    return result.onFailure(callback);
  }
}

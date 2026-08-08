// ════════════════════════════════════════════════
// Project Lyra — Fake Repositories
// ════════════════════════════════════════════════
//
// Fake implementations of repository interfaces
// for unit testing. No network calls, no storage.
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import 'package:project_lyra/core/error/failures.dart';

/// A fake repository that returns configurable results.
///
/// Use in tests to control what the repository returns
/// without making network calls.
///
/// ```dart
/// final repo = FakeRepository<Track>();
/// repo.setResult(Right(Track(id: '1', title: 'Test')));
/// final result = await repo.getItem('1'); // Returns the configured result.
/// ```
class FakeRepository<T> {
  Either<Failure, T>? _singleResult;
  Either<Failure, List<T>>? _listResult;
  Failure? _failure;

  int getCallCount = 0;
  int putCallCount = 0;
  int deleteCallCount = 0;
  String? lastRequestedId;

  /// Configure the result for single-item gets.
  void setResult(Either<Failure, T> result) {
    _singleResult = result;
    _failure = null;
  }

  /// Configure the result for list gets.
  void setListResult(Either<Failure, List<T>> result) {
    _listResult = result;
  }

  /// Configure a failure for all operations.
  void setFailure(Failure failure) {
    _failure = failure;
    _singleResult = null;
    _listResult = null;
  }

  /// Simulate getting a single item.
  Future<Either<Failure, T>> getItem(String id) async {
    getCallCount++;
    lastRequestedId = id;

    if (_failure != null) return Left(_failure!);
    if (_singleResult != null) return _singleResult!;

    return Left(UnknownFailure(message: 'No result configured'));
  }

  /// Simulate getting a list.
  Future<Either<Failure, List<T>>> getList({
    int page = 1,
    int limit = 20,
  }) async {
    getCallCount++;

    if (_failure != null) return Left(_failure!);
    if (_listResult != null) return _listResult!;

    return const Right([]);
  }

  /// Simulate putting an item.
  Future<Either<Failure, void>> putItem(String id, T data) async {
    putCallCount++;
    lastRequestedId = id;

    if (_failure != null) return Left(_failure!);
    return const Right(null);
  }

  /// Simulate deleting an item.
  Future<Either<Failure, void>> deleteItem(String id) async {
    deleteCallCount++;
    lastRequestedId = id;

    if (_failure != null) return Left(_failure!);
    return const Right(null);
  }

  /// Reset all state.
  void reset() {
    _singleResult = null;
    _listResult = null;
    _failure = null;
    getCallCount = 0;
    putCallCount = 0;
    deleteCallCount = 0;
    lastRequestedId = null;
  }
}

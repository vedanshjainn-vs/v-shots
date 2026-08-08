// ════════════════════════════════════════════════
// Project Lyra — Use Case Contracts
// ════════════════════════════════════════════════
//
// Base classes for the domain layer.
// One use case = one business action.
// Returns Either<Failure, Success> via dartz.
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../error/failures.dart';

/// A use case that returns a value.
///
/// Type params:
/// - [Type] — the success return type
/// - [Params] — the input parameters
///
/// ```dart
/// class GetTrack implements UseCase<Track, TrackParams> {
///   @override
///   Future<Either<Failure, Track>> call(TrackParams params) {
///     return repository.getTrack(params.id);
///   }
/// }
/// ```
abstract class UseCase<Type, Params> {
  const UseCase();

  /// Execute the use case.
  Future<Either<Failure, Type>> call(Params params);
}

/// A use case that performs an action without returning data.
///
/// ```dart
/// class LogoutUser implements UseCase<void, NoParams> {
///   @override
///   Future<Either<Failure, void>> call(NoParams params) {
///     return repository.logout();
///   }
/// }
/// ```
abstract class UseCaseVoid<Params> {
  const UseCaseVoid();

  /// Execute the use case.
  Future<Either<Failure, void>> call(Params params);
}

/// A use case that returns a stream (reactive data).
///
/// ```dart
/// class WatchPlaybackState implements StreamUseCase<PlaybackState, NoParams> {
///   @override
///   Stream<Either<Failure, PlaybackState>> call(NoParams params) {
///     return repository.playbackStream;
///   }
/// }
/// ```
abstract class StreamUseCase<Type, Params> {
  const StreamUseCase();

  /// Execute the use case — returns a stream.
  Stream<Either<Failure, Type>> call(Params params);
}

/// No parameters needed.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}

/// Pagination parameters.
class PageParams extends Equatable {
  const PageParams({
    this.page = 1,
    this.limit = 20,
    this.query,
  });

  final int page;
  final int limit;
  final String? query;

  @override
  List<Object?> get props => [page, limit, query];
}

/// ID-based parameters.
class IdParams extends Equatable {
  const IdParams({required this.id});

  final String id;

  @override
  List<Object?> get props => [id];
}

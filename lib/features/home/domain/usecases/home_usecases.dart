// ════════════════════════════════════════════════
// Project Lyra — Home Use Cases
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/home_entities.dart';
import '../repositories/home_repository.dart';

class GetHomeFeed implements UseCase<HomeFeed, GetHomeFeedParams> {
  const GetHomeFeed(this.repository);
  final HomeRepository repository;

  @override
  Future<Either<Failure, HomeFeed>> call(GetHomeFeedParams params) {
    return repository.getFeed(forceRefresh: params.forceRefresh);
  }
}

class GetHomeFeedParams extends Equatable {
  const GetHomeFeedParams({this.forceRefresh = false});
  final bool forceRefresh;
  @override
  List<Object?> get props => [forceRefresh];
}

class RefreshHomeFeed implements UseCase<HomeFeed, NoParams> {
  const RefreshHomeFeed(this.repository);
  final HomeRepository repository;

  @override
  Future<Either<Failure, HomeFeed>> call(NoParams params) {
    return repository.refreshFeed();
  }
}

class GetRecommendations implements UseCase<List<HomeItem>, GetRecommendationsParams> {
  const GetRecommendations(this.repository);
  final HomeRepository repository;

  @override
  Future<Either<Failure, List<HomeItem>>> call(GetRecommendationsParams params) {
    return repository.getRecommendations(limit: params.limit);
  }
}

class GetRecommendationsParams extends Equatable {
  const GetRecommendationsParams({this.limit = 20});
  final int limit;
  @override
  List<Object?> get props => [limit];
}

// ════════════════════════════════════════════════
// Project Lyra — Recommendation Use Cases
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/recommendation_entities.dart';
import '../repositories/recommendation_repository.dart';

class GetRecommendations implements UseCase<RecommendationFeed, RecommendationContext?> {
  const GetRecommendations(this.repository);
  final RecommendationRepository repository;
  @override
  Future<Either<Failure, RecommendationFeed>> call(RecommendationContext? context) =>
      repository.getRecommendations(context: context);
}

class RecordInteraction implements UseCaseVoid<RecordInteractionParams> {
  const RecordInteraction(this.repository);
  final RecommendationRepository repository;
  @override
  Future<Either<Failure, void>> call(RecordInteractionParams params) =>
      repository.recordInteraction(itemId: params.itemId, interactionType: params.interactionType);
}

class RecordInteractionParams extends Equatable {
  const RecordInteractionParams({required this.itemId, required this.interactionType});
  final String itemId;
  final String interactionType;
  @override
  List<Object?> get props => [itemId, interactionType];
}

class DismissRecommendation implements UseCaseVoid<String> {
  const DismissRecommendation(this.repository);
  final RecommendationRepository repository;
  @override
  Future<Either<Failure, void>> call(String id) => repository.dismissRecommendation(id);
}

class GetTrending implements UseCase<List<Recommendation>, GetTrendingParams> {
  const GetTrending(this.repository);
  final RecommendationRepository repository;
  @override
  Future<Either<Failure, List<Recommendation>>> call(GetTrendingParams params) =>
      repository.getTrending(contentType: params.contentType, limit: params.limit);
}

class GetTrendingParams extends Equatable {
  const GetTrendingParams({this.contentType, this.limit = 20});
  final String? contentType;
  final int limit;
  @override
  List<Object?> get props => [contentType, limit];
}

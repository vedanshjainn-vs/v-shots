// ════════════════════════════════════════════════
// Project Lyra — Recommendation Repository Interface
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/recommendation_entities.dart';

typedef Result<T> = Either<Failure, T>;

abstract class RecommendationRepository {
  Future<Result<RecommendationFeed>> getRecommendations({RecommendationContext? context});
  Future<Result<List<Recommendation>>> getSimilar({required String itemId, required String contentType, int limit = 10});
  Future<Result<void>> recordInteraction({required String itemId, required String interactionType});
  Future<Result<void>> dismissRecommendation(String recommendationId);
  Future<Result<List<Recommendation>>> getTrending({String? contentType, int limit = 20});
}

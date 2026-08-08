// ════════════════════════════════════════════════
// Project Lyra — Recommendation Repository Implementation
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import '../../../../core/cache/cache_key.dart';
import '../../../../core/cache/cache_manager.dart';
import '../../../../core/cache/policies/cache_policy.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/mapper/failure_mapper.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/recommendation_entities.dart';
import '../../domain/repositories/recommendation_repository.dart';
import '../datasources/remote/recommendation_remote_datasource.dart';
import '../models/recommendation_models.dart';

class RecommendationRepositoryImpl implements RecommendationRepository {
  RecommendationRepositoryImpl({
    required this.remoteDataSource,
    required this.cacheManager,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final RecommendationRemoteDataSource remoteDataSource;
  final CacheManager cacheManager;
  final AppLogger _logger;

  @override
  Future<Either<Failure, RecommendationFeed>> getRecommendations({RecommendationContext? context}) async {
    try {
      // Check cache first.
      final key = CacheKey(namespace: 'recommendations', id: 'feed');
      final cached = cacheManager.getRaw(key);
      if (cached != null) {
        _logger.d('RecommendationRepo: Cache hit');
        // TODO(team): Deserialize from cache.
      }

      final feed = await remoteDataSource.getRecommendations(
        context: context != null ? {'mood': context.mood, 'activity': context.activity} : null,
      );

      // Cache the result.
      await cacheManager.put<RecommendationFeedModel>(
        key: key,
        data: feed,
        toJson: (data) => data.toJson(),
        ttl: CachePolicy.dynamic.maxAge,
      );

      return Right(feed.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<Recommendation>>> getSimilar({required String itemId, required String contentType, int limit = 10}) async {
    try {
      final items = await remoteDataSource.getSimilar(itemId: itemId, contentType: contentType, limit: limit);
      return Right(items.map((i) => i.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> recordInteraction({required String itemId, required String interactionType}) async {
    try {
      await remoteDataSource.recordInteraction(itemId: itemId, interactionType: interactionType);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> dismissRecommendation(String recommendationId) async {
    try {
      await remoteDataSource.dismissRecommendation(recommendationId);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<Recommendation>>> getTrending({String? contentType, int limit = 20}) async {
    try {
      final items = await remoteDataSource.getTrending(contentType: contentType, limit: limit);
      return Right(items.map((i) => i.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }
}

// ════════════════════════════════════════════════
// Project Lyra — Home Repository Implementation
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import '../../../../core/cache/cache_key.dart';
import '../../../../core/cache/cache_manager.dart';
import '../../../../core/cache/policies/cache_policy.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/mapper/failure_mapper.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/home_entities.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/local/home_local_datasource.dart';
import '../datasources/remote/home_remote_datasource.dart';

/// Concrete implementation of [HomeRepository].
///
/// Offline-first: checks cache before network.
/// Integrates with CacheManager, EventBus, and telemetry.
class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.cacheManager,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final HomeRemoteDataSource remoteDataSource;
  final HomeLocalDataSource localDataSource;
  final CacheManager cacheManager;
  final AppLogger _logger;

  @override
  Future<Either<Failure, HomeFeed>> getFeed({bool forceRefresh = false}) async {
    try {
      // Check cache first (unless force refresh).
      if (!forceRefresh) {
        final cached = await localDataSource.getCachedFeed();
        if (cached != null) {
          _logger.d('HomeRepo: Cache hit for feed');
          return Right(cached.toEntity());
        }
      }

      // Fetch from remote.
      _logger.d('HomeRepo: Fetching feed from remote');
      final feedModel = await remoteDataSource.getFeed();

      // Cache the result.
      await localDataSource.cacheFeed(feedModel);

      return Right(feedModel.toEntity());
    } catch (e, st) {
      _logger.e('HomeRepo: getFeed failed', error: e, stackTrace: st);
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, HomeFeed>> refreshFeed() async {
    try {
      final feedModel = await remoteDataSource.getFeed();
      await localDataSource.cacheFeed(feedModel);
      return Right(feedModel.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<HomeItem>>> getRecommendations({int limit = 20}) async {
    try {
      final items = await remoteDataSource.getRecommendations(limit: limit);
      return Right(items.map((i) => i.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<HomeItem>>> getContinueListening() async {
    try {
      final items = await remoteDataSource.getContinueListening();
      return Right(items.map((i) => i.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<BannerItem>>> getBanners() async {
    try {
      final banners = await remoteDataSource.getBanners();
      return Right(banners.map((b) => b.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }
}

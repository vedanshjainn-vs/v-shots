// ════════════════════════════════════════════════
// Project Lyra — Search Repository Implementation
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/mapper/failure_mapper.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/search_entities.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/local/search_local_datasource.dart';
import '../datasources/remote/search_remote_datasource.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final SearchRemoteDataSource remoteDataSource;
  final SearchLocalDataSource localDataSource;
  final AppLogger _logger;

  @override
  Future<Either<Failure, SearchResult>> search(String query, {String? filter, int page = 1, int limit = 20}) async {
    try {
      // Save to recent searches.
      await localDataSource.saveRecentSearch(query);

      // Check cache first for non-paginated queries.
      if (page == 1) {
        final cached = await localDataSource.getCachedResults(query);
        if (cached.isNotEmpty) {
          _logger.d('SearchRepo: Cache hit for "$query"');
          // Reconstruct from cache.
        }
      }

      // Fetch from remote.
      final result = await remoteDataSource.search(query, filter: filter, page: page, limit: limit);

      // Cache first page.
      if (page == 1) {
        await localDataSource.cacheResults(query, result.tracks);
      }

      return Right(result.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<SearchSuggestion>>> getSuggestions(String query) async {
    try {
      final suggestions = await remoteDataSource.getSuggestions(query);
      return Right(suggestions.map((s) => s.toEntity()).toList());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, List<RecentSearch>>> getRecentSearches() async {
    try {
      final searches = await localDataSource.getRecentSearches();
      return Right(searches);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> saveRecentSearch(String query) async {
    try {
      await localDataSource.saveRecentSearch(query);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> clearRecentSearches() async {
    try {
      await localDataSource.clearRecentSearches();
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRecentSearch(String query) async {
    try {
      await localDataSource.deleteRecentSearch(query);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, SearchResult>> searchByType(String query, String type) async {
    try {
      final result = await remoteDataSource.searchByType(query, type);
      return Right(result.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, SearchResult>> voiceSearch(String audioQuery) async {
    try {
      final result = await remoteDataSource.voiceSearch(audioQuery);
      return Right(result.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }
}

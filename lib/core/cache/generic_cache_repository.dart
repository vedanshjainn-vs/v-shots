// ════════════════════════════════════════════════
// Project Lyra — Generic Cache Repository
// ════════════════════════════════════════════════
//
// Base class for repositories that need offline-first
// caching. Handles the full Memory → Disk → Network
// flow automatically.
//
// Feature repositories extend this class.
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import '../error/failures.dart';
import '../logging/app_logger.dart';
import 'cache_key.dart';
import 'cache_manager.dart';
import 'policies/cache_policy.dart';

/// A base repository that implements offline-first caching.
///
/// Extend this class and implement [fetchFromNetwork] to get
/// automatic Memory → Disk → Network data flow.
///
/// ```dart
/// class TrackRepository extends CacheRepository<Track> {
///   TrackRepository({required this.api, required super.cacheManager});
///   final TrackApi api;
///
///   @override
///   Future<Track> fetchFromNetwork(String id) => api.getTrack(id);
///
///   @override
///   Map<String, dynamic> toJson(Track data) => data.toJson();
///
///   @override
///   Track fromJson(Map<String, dynamic> json) => Track.fromJson(json);
///
///   @override
///   String get namespace => 'tracks';
/// }
/// ```
abstract class CacheRepository<T> {
  /// Creates a cache repository.
  CacheRepository({
    required this.cacheManager,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  /// The cache manager handling storage layers.
  final CacheManager cacheManager;

  final AppLogger _logger;

  /// Cache namespace for this entity type (e.g., 'tracks').
  String get namespace;

  /// Default cache policy for this repository.
  CachePolicy get defaultPolicy => CachePolicy.userSpecific;

  /// Fetch a single item from the network.
  Future<T> fetchFromNetwork(String id);

  /// Fetch a list from the network.
  Future<List<T>> fetchListFromNetwork({int page = 1, int limit = 20, String? query});

  /// Serialize an item to JSON for caching.
  Map<String, dynamic> toJson(T data);

  /// Deserialize an item from JSON.
  T fromJson(Map<String, dynamic> json);

  // ── Read Operations ──────────────────────────

  /// Get a single item with cache-first strategy.
  ///
  /// Returns [Either<Failure, T>].
  Future<Either<Failure, T>> getItem(String id, {CachePolicy? policy}) async {
    final key = CacheKey.item(namespace, id);
    final effectivePolicy = policy ?? defaultPolicy;

    try {
      final result = await cacheManager.get<T>(
        key: key,
        policy: effectivePolicy,
        fromNetwork: () => fetchFromNetwork(id),
        fromJson: fromJson,
        toJson: toJson,
      );

      if (result == null) {
        return Left(NotFoundFailure(message: '$namespace:$id not found'));
      }

      return Right(result);
    } catch (e, st) {
      _logger.e('CacheRepository.getItem failed', error: e, stackTrace: st);
      return Left(_mapError(e));
    }
  }

  /// Get a list with cache-first strategy.
  Future<Either<Failure, List<T>>> getList({
    int page = 1,
    int limit = 20,
    String? query,
    CachePolicy? policy,
  }) async {
    final key = query != null
        ? CacheKey.search(query)
        : CacheKey.collection(namespace, query: 'page_$page');
    final effectivePolicy = policy ?? defaultPolicy;

    try {
      final result = await cacheManager.get<List<T>>(
        key: key,
        policy: effectivePolicy,
        fromNetwork: () => fetchListFromNetwork(page: page, limit: limit, query: query),
        fromJson: (json) => (json['items'] as List)
            .map((item) => fromJson(item as Map<String, dynamic>))
            .toList(),
        toJson: (data) => {'items': data.map(toJson).toList()},
      );

      return Right(result ?? []);
    } catch (e, st) {
      _logger.e('CacheRepository.getList failed', error: e, stackTrace: st);
      return Left(_mapError(e));
    }
  }

  // ── Write Operations ─────────────────────────

  /// Manually cache an item.
  Future<void> cacheItem(String id, T data, {Duration? ttl}) async {
    final key = CacheKey.item(namespace, id);
    await cacheManager.put<T>(
      key: key,
      data: data,
      toJson: toJson,
      ttl: ttl,
    );
  }

  /// Invalidate a specific item.
  Future<void> invalidateItem(String id) async {
    final key = CacheKey.item(namespace, id);
    await cacheManager.invalidate(key);
  }

  /// Invalidate all items in this namespace.
  Future<void> invalidateAll() async {
    await cacheManager.invalidateNamespace(namespace);
  }

  Failure _mapError(Object error) {
    if (error is Failure) return error;
    return UnknownFailure(message: error.toString());
  }
}

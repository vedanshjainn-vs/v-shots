// ════════════════════════════════════════════════
// Project Lyra — Cache Serializer
// ════════════════════════════════════════════════
//
// Generic serialization for cache entries.
// Supports JSON and raw bytes. Models implement
// the [Cacheable] mixin for easy serialization.
// ════════════════════════════════════════════════

import 'dart:convert';

import '../../../core/logging/app_logger.dart';

/// A cache entry wrapper that stores data with metadata.
class CacheEntry<T> {
  /// Creates a cache entry.
  const CacheEntry({
    required this.data,
    required this.cachedAt,
    required this.key,
    this.etag,
    this.metadata = const {},
  });

  /// The cached data.
  final T data;

  /// When this entry was cached.
  final DateTime cachedAt;

  /// The cache key for this entry.
  final String key;

  /// ETag for conditional network requests.
  final String? etag;

  /// Additional metadata (content type, version, etc.).
  final Map<String, dynamic> metadata;

  /// Whether this entry has expired based on a max age.
  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(cachedAt) > maxAge;
  }

  /// Creates a copy with updated fields.
  CacheEntry<T> copyWith({
    T? data,
    DateTime? cachedAt,
    String? etag,
    Map<String, dynamic>? metadata,
  }) {
    return CacheEntry<T>(
      data: data ?? this.data,
      cachedAt: cachedAt ?? this.cachedAt,
      key: key,
      etag: etag ?? this.etag,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Serializes and deserializes cache entries.
///
/// For models using Freezed/json_serializable, provide
/// [toJson] and [fromJson] factories.
class CacheSerializer {
  CacheSerializer({AppLogger? logger}) : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  /// Serialize an object to a JSON string.
  String toJson<T>(T data, Map<String, dynamic> Function(T) toJsonFn) {
    try {
      return jsonEncode(toJsonFn(data));
    } catch (e, st) {
      _logger.e('CacheSerializer.toJson failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Deserialize a JSON string to an object.
  T? fromJson<T>(String json, T Function(Map<String, dynamic>) fromJsonFn) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return fromJsonFn(map);
    } catch (e, st) {
      _logger.e('CacheSerializer.fromJson failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Serialize a list of objects to JSON.
  String toJsonList<T>(List<T> data, Map<String, dynamic> Function(T) toJsonFn) {
    try {
      return jsonEncode(data.map(toJsonFn).toList());
    } catch (e, st) {
      _logger.e('CacheSerializer.toJsonList failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Deserialize a JSON string to a list of objects.
  List<T>? fromJsonList<T>(String json, T Function(Map<String, dynamic>) fromJsonFn) {
    try {
      final list = jsonDecode(json) as List;
      return list.map((item) => fromJsonFn(item as Map<String, dynamic>)).toList();
    } catch (e, st) {
      _logger.e('CacheSerializer.fromJsonList failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Serialize a cache entry with metadata.
  String serializeEntry<T>(
    CacheEntry<T> entry,
    Map<String, dynamic> Function(T) toJsonFn,
  ) {
    return jsonEncode({
      'data': toJsonFn(entry.data),
      'cachedAt': entry.cachedAt.toIso8601String(),
      'key': entry.key,
      'etag': entry.etag,
      'metadata': entry.metadata,
    });
  }

  /// Deserialize a cache entry from JSON.
  CacheEntry<T>? deserializeEntry<T>(
    String json,
    T Function(Map<String, dynamic>) fromJsonFn,
  ) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return CacheEntry<T>(
        data: fromJsonFn(map['data'] as Map<String, dynamic>),
        cachedAt: DateTime.parse(map['cachedAt'] as String),
        key: map['key'] as String,
        etag: map['etag'] as String?,
        metadata: (map['metadata'] as Map<String, dynamic>?) ?? {},
      );
    } catch (e, st) {
      _logger.e('CacheSerializer.deserializeEntry failed', error: e, stackTrace: st);
      return null;
    }
  }
}

/// Mixin for models that can be cached.
///
/// ```dart
/// @freezed
/// class Track with _$Track, Cacheable<Track> {
///   const factory Track({...}) = _Track;
///   factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);
///
///   @override
///   Map<String, dynamic> toCacheJson() => toJson();
///   factory Track.fromCacheJson(Map<String, dynamic> json) => Track.fromJson(json);
/// }
/// ```
mixin Cacheable<T> {
  /// Serialize to a JSON-compatible map for caching.
  Map<String, dynamic> toCacheJson();
}

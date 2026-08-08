// ════════════════════════════════════════════════
// Project Lyra — Cache Interceptor
// ════════════════════════════════════════════════
//
// HTTP-level caching via Dio interceptor.
// Supports ETag and Cache-Control headers.
// Integrates with the 3-tier cache system.
// ════════════════════════════════════════════════

import 'dart:convert';

import 'package:dio/dio.dart';

import '../../cache/cache_key.dart';
import '../../cache/cache_manager.dart';
import '../../cache/policies/cache_policy.dart';
import '../../logging/app_logger.dart';

/// Dio interceptor for HTTP-level caching.
///
/// Handles:
/// - ETag-based conditional requests (If-None-Match)
/// - Cache-Control header parsing
/// - 304 Not Modified responses
/// - Response caching in the 3-tier cache
class LyraCacheInterceptor extends Interceptor {
  LyraCacheInterceptor({
    required this.cacheManager,
    this.defaultPolicy = CachePolicy.dynamic,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final CacheManager cacheManager;
  final CachePolicy defaultPolicy;
  final AppLogger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Skip caching for non-GET requests.
    if (options.method.toUpperCase() != 'GET') {
      handler.next(options);
      return;
    }

    // Skip if explicitly disabled.
    if (options.extra['noCache'] == true) {
      handler.next(options);
      return;
    }

    final key = _cacheKey(options);

    // Check for cached ETag.
    final cached = cacheManager.getRaw(key);
    if (cached != null) {
      try {
        final map = jsonDecode(cached) as Map<String, dynamic>;
        final etag = map['_etag'] as String?;
        if (etag != null) {
          options.headers['If-None-Match'] = etag;
          _logger.d('CacheInterceptor: Sending ETag for ${options.uri}');
        }
      } catch (_) {
        // Not a JSON cache entry — skip ETag.
      }
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Only cache GET responses.
    if (response.requestOptions.method.toUpperCase() != 'GET') {
      handler.next(response);
      return;
    }

    // Handle 304 Not Modified.
    if (response.statusCode == 304) {
      _logger.d('CacheInterceptor: 304 for ${response.requestOptions.uri}');
      final key = _cacheKey(response.requestOptions);
      final cached = cacheManager.getRaw(key);

      if (cached != null) {
        try {
          final map = jsonDecode(cached) as Map<String, dynamic>;
          final data = map['_data'];
          handler.resolve(Response(
            data: data,
            statusCode: 200,
            requestOptions: response.requestOptions,
          ));
          return;
        } catch (_) {
          // Fall through to pass original response.
        }
      }
    }

    // Cache successful responses.
    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      _cacheResponse(response);
    }

    handler.next(response);
  }

  void _cacheResponse(Response response) {
    try {
      final key = _cacheKey(response.requestOptions);
      final etag = response.headers.value('etag');
      final cacheControl = response.headers.value('cache-control');

      Duration? ttl;
      if (cacheControl != null) {
        ttl = _parseCacheControl(cacheControl);
      }

      final cacheData = jsonEncode({
        '_data': response.data,
        '_etag': etag,
        '_cachedAt': DateTime.now().toIso8601String(),
      });

      cacheManager.putRaw(key, cacheData, ttl: ttl);
    } catch (e) {
      _logger.w('CacheInterceptor: Failed to cache response');
    }
  }

  CacheKey _cacheKey(RequestOptions options) {
    return CacheKey(
      namespace: 'http',
      id: options.uri.toString(),
    );
  }

  Duration? _parseCacheControl(String header) {
    final maxAgeMatch = RegExp(r'max-age=(\d+)').firstMatch(header);
    if (maxAgeMatch != null) {
      final seconds = int.tryParse(maxAgeMatch.group(1)!);
      if (seconds != null) return Duration(seconds: seconds);
    }

    if (header.contains('no-cache') || header.contains('no-store')) {
      return Duration.zero;
    }

    return null;
  }
}

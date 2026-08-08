// ════════════════════════════════════════════════
// Project Lyra — Retry Interceptor
// ════════════════════════════════════════════════
//
// Retries failed requests with exponential backoff.
// Respects Retry-After headers from rate-limited APIs.
// ════════════════════════════════════════════════

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

import '../../logging/app_logger.dart';

/// Retries failed requests with exponential backoff.
///
/// Configurable max retries and backoff multiplier.
/// Does NOT retry 4xx client errors (except 429).
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 10),
  });

  final Dio dio;
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;

  final _logger = AppLogger.instance;
  final _random = Random();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = err.requestOptions._retryCount;

    if (!_shouldRetry(err) || retryCount >= maxRetries) {
      handler.next(err);
      return;
    }

    final delay = _calculateDelay(err, retryCount);
    _logger.d(
      'Retry ${retryCount + 1}/$maxRetries for '
      '${err.requestOptions.method} ${err.requestOptions.uri} '
      'in ${delay.inMilliseconds}ms',
    );

    // Increment retry count on the request options.
    err.requestOptions._retryCount = retryCount + 1;

    await Future<void>.delayed(delay);

    try {
      final response = await dio.fetch(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _shouldRetry(DioException err) {
    // Retry on network errors, timeouts, and 429 / 5xx.
    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        true,
      DioExceptionType.badResponse =>
        _isRetryableStatusCode(err.response?.statusCode),
      _ => false,
    };
  }

  bool _isRetryableStatusCode(int? statusCode) {
    if (statusCode == null) return false;
    return statusCode == 429 || statusCode >= 500;
  }

  Duration _calculateDelay(DioException err, int retryCount) {
    // Check for Retry-After header first.
    final retryAfter = err.response?.headers.value('Retry-After');
    if (retryAfter != null) {
      final seconds = int.tryParse(retryAfter);
      if (seconds != null) {
        return Duration(seconds: seconds).clamp(Duration.zero, maxDelay);
      }
    }

    // Exponential backoff with jitter.
    final exponentialMs = baseDelay.inMilliseconds * pow(2, retryCount);
    final jitterMs = _random.nextInt(baseDelay.inMilliseconds);
    final totalMs = exponentialMs + jitterMs;

    return Duration(
      milliseconds: totalMs.toInt().clamp(0, maxDelay.inMilliseconds),
    );
  }
}

/// Extension to track retry count on request options.
extension _RetryCountExtension on RequestOptions {
  static const _retryCountKey = '_lyra_retry_count';

  int get _retryCount => (extra[_retryCountKey] as int?) ?? 0;

  set _retryCount(int count) {
    extra[_retryCountKey] = count;
  }
}

// ════════════════════════════════════════════════
// Project Lyra — Failure Mapper
// ════════════════════════════════════════════════
//
// Maps exceptions to typed failures.
// Single source of truth for error translation.
// ════════════════════════════════════════════════

import 'package:dio/dio.dart';

import '../../logging/app_logger.dart';
import '../failure.dart';

/// Maps exceptions to [Failure] objects.
///
/// Used by repositories to translate data-layer
/// exceptions into domain-layer failures.
///
/// ```dart
/// try {
///   final data = await api.fetch();
/// } catch (e) {
///   return Left(FailureMapper.map(e));
/// }
/// ```
abstract final class FailureMapper {
  static final _logger = AppLogger.instance;

  /// Map any exception to a [Failure].
  static Failure map(Object exception, [StackTrace? stackTrace]) {
    _logger.e('FailureMapper: ${exception.runtimeType}',
        error: exception, stackTrace: stackTrace);

    if (exception is Failure) return exception;

    if (exception is DioException) return _mapDio(exception);

    if (exception is FormatException) {
      return SerializationFailure(message: exception.message);
    }

    if (exception is TimeoutException) {
      return const TimeoutFailure();
    }

    return UnknownFailure(
      message: exception.toString(),
      originalError: exception,
    );
  }

  static Failure _mapDio(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const TimeoutFailure(),
      DioExceptionType.connectionError => const NetworkFailure(),
      DioExceptionType.badResponse => _mapBadResponse(e),
      DioExceptionType.cancel => const ServerFailure(
          message: 'Request cancelled', code: 'CANCELLED'),
      _ => UnknownFailure(message: e.message ?? 'Unknown error'),
    };
  }

  static Failure _mapBadResponse(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final message = _extractMessage(data) ?? 'Server error';

    return switch (status) {
      400 => ValidationFailure(message: message, code: '400'),
      401 => const UnauthorizedFailure(),
      403 => const ForbiddenFailure(),
      404 => const NotFoundFailure(),
      409 => ConflictFailure(message: message),
      429 => RateLimitFailure(
          message: message,
          retryAfter: _parseRetryAfter(e.response?.headers)),
      >= 500 => ServerFailure(
          message: message, statusCode: status, isRetryable: true),
      _ => ServerFailure(message: message, statusCode: status),
    };
  }

  static String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ?? data['error'] as String?;
    }
    if (data is String) return data;
    return null;
  }

  static Duration? _parseRetryAfter(Headers? headers) {
    final value = headers?.value('Retry-After');
    if (value == null) return null;
    final seconds = int.tryParse(value);
    return seconds != null ? Duration(seconds: seconds) : null;
  }
}

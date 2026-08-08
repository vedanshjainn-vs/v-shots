// ════════════════════════════════════════════════
// Project Lyra — Error Handler
// ════════════════════════════════════════════════
//
// Maps exceptions to failures. Single source of
// truth for error translation across the app.
// ════════════════════════════════════════════════

import 'package:dio/dio.dart';

import '../logging/app_logger.dart';
import 'exceptions.dart';
import 'failures.dart';

/// Centralized error handler.
///
/// Maps [AppException] → [Failure] and logs the error.
/// Repositories call this in their catch blocks.
abstract final class ErrorHandler {
  static final _logger = AppLogger.instance;

  /// Maps an exception to a [Failure], logging along the way.
  static Failure handleException(Object exception, [StackTrace? stackTrace]) {
    _logger.e(
      'ErrorHandler: ${exception.runtimeType}',
      error: exception,
      stackTrace: stackTrace,
    );

    if (exception is AppException) {
      return _mapAppException(exception);
    }

    if (exception is DioException) {
      return _mapDioException(exception);
    }

    return UnknownFailure(message: exception.toString());
  }

  /// Wraps a repository call in try-catch and returns [Either<Failure, T>].
  /// Requires `dartz` package for `Either`.
  ///
  /// Usage:
  /// ```dart
  /// final result = await ErrorHandler.guard(() => dataSource.fetch());
  /// ```
  static Future<T> guard<T>(
    Future<T> Function() call,
  ) async {
    try {
      return await call();
    } on AppException catch (e, st) {
      throw handleException(e, st);
    } on DioException catch (e, st) {
      throw handleException(e, st);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── Private mappers ──────────────────────────

  static Failure _mapAppException(AppException exception) {
    return switch (exception) {
      ServerException e => ServerFailure(
          message: e.message,
          code: e.code,
          statusCode: e.statusCode,
        ),
      NetworkException() => NetworkFailure(message: exception.message),
      TimeoutException() => ServerFailure(
          message: exception.message,
          code: 'TIMEOUT',
        ),
      AuthException() => AuthFailure(message: exception.message, code: exception.code),
      TokenExpiredException() => AuthFailure(
          message: exception.message,
          code: 'TOKEN_EXPIRED',
        ),
      CacheException() => CacheFailure(message: exception.message),
      SerializationException() => ServerFailure(
          message: exception.message,
          code: 'PARSE_ERROR',
        ),
      PermissionException() => PermissionFailure(message: exception.message),
      NotFoundException() => NotFoundFailure(message: exception.message),
      RateLimitException e => RateLimitFailure(
          message: exception.message,
          retryAfter: e.retryAfter,
        ),
      PaymentException() => PaymentFailure(message: exception.message),
      UnknownException() => UnknownFailure(message: exception.message),
    };
  }

  static Failure _mapDioException(DioException exception) {
    return switch (exception.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const ServerFailure(message: 'Connection timed out', code: 'TIMEOUT'),
      DioExceptionType.connectionError => const NetworkFailure(),
      DioExceptionType.badResponse => _mapBadResponse(exception),
      DioExceptionType.cancel => const ServerFailure(
          message: 'Request cancelled',
          code: 'CANCELLED',
        ),
      _ => UnknownFailure(message: exception.message ?? 'Unknown error'),
    };
  }

  static Failure _mapBadResponse(DioException exception) {
    final statusCode = exception.response?.statusCode;
    final message = exception.response?.data?.toString() ?? 'Server error';

    return switch (statusCode) {
      401 => const AuthFailure(message: 'Unauthorized', code: '401'),
      403 => const AuthFailure(message: 'Forbidden', code: '403'),
      404 => const NotFoundFailure(message: 'Not found', code: '404'),
      429 => const RateLimitFailure(message: 'Rate limited', code: '429'),
      >= 500 => ServerFailure(message: message, statusCode: statusCode),
      _ => ServerFailure(message: message, statusCode: statusCode),
    };
  }
}

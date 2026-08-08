// ════════════════════════════════════════════════
// Project Lyra — Exceptions
// ════════════════════════════════════════════════
//
// Application-level exceptions thrown by data
// sources and services. Caught by repositories
// and mapped to [Failure] objects.
// ════════════════════════════════════════════════

/// Base exception for all application errors.
///
/// All custom exceptions should extend this class.
sealed class AppException implements Exception {
  const AppException({
    required this.message,
    this.code,
    this.originalException,
    this.stackTrace,
  });

  final String message;
  final String? code;
  final Object? originalException;
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Server returned an error response.
class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.code,
    super.originalException,
    super.stackTrace,
    this.statusCode,
  });

  final int? statusCode;
}

/// Network connection failed.
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'No internet connection',
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Request timed out.
class TimeoutException extends AppException {
  const TimeoutException({
    super.message = 'Request timed out',
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Authentication failed.
class AuthException extends AppException {
  const AuthException({
    super.message = 'Authentication failed',
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Token expired — needs refresh.
class TokenExpiredException extends AppException {
  const TokenExpiredException({
    super.message = 'Session expired',
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Local cache / storage error.
class CacheException extends AppException {
  const CacheException({
    super.message = 'Cache error',
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// JSON parsing / deserialization failed.
class SerializationException extends AppException {
  const SerializationException({
    super.message = 'Data parsing error',
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Permission denied by user.
class PermissionException extends AppException {
  const PermissionException({
    super.message = 'Permission denied',
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Content not found (404).
class NotFoundException extends AppException {
  const NotFoundException({
    super.message = 'Content not found',
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Rate limited by server.
class RateLimitException extends AppException {
  const RateLimitException({
    super.message = 'Too many requests',
    super.code,
    super.originalException,
    super.stackTrace,
    this.retryAfter,
  });

  final Duration? retryAfter;
}

/// Payment / subscription error.
class PaymentException extends AppException {
  const PaymentException({
    super.message = 'Payment failed',
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

/// Unexpected / unknown error.
class UnknownException extends AppException {
  const UnknownException({
    super.message = 'An unexpected error occurred',
    super.code,
    super.originalException,
    super.stackTrace,
  });
}

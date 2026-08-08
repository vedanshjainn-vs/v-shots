// ════════════════════════════════════════════════
// Project Lyra — Failure Classes
// ════════════════════════════════════════════════
//
// Domain-layer failure types. Returned by
// repositories via Either<Failure, T>.
// UI reads these to show appropriate messages.
// ════════════════════════════════════════════════

import 'package:equatable/equatable.dart';

/// Base failure class for the domain layer.
///
/// Failures are the domain-layer counterpart to [AppException].
/// They travel from repositories → use cases → presentation.
abstract class Failure extends Equatable {
  const Failure({
    required this.message,
    this.code,
  });

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.code,
    this.statusCode,
  });

  final int? statusCode;

  @override
  List<Object?> get props => [message, code, statusCode];
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection. Please check your network.',
    super.code,
  });
}

class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Unable to load cached data',
    super.code,
  });
}

class AuthFailure extends Failure {
  const AuthFailure({
    super.message = 'Authentication failed',
    super.code,
  });
}

class PermissionFailure extends Failure {
  const PermissionFailure({
    super.message = 'Permission required',
    super.code,
  });
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = 'Content not found',
    super.code,
  });
}

class RateLimitFailure extends Failure {
  const RateLimitFailure({
    super.message = 'Too many requests. Please try again later.',
    super.code,
    this.retryAfter,
  });

  final Duration? retryAfter;

  @override
  List<Object?> get props => [message, code, retryAfter];
}

class PaymentFailure extends Failure {
  const PaymentFailure({
    super.message = 'Payment could not be processed',
    super.code,
  });
}

class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'Something went wrong',
    super.code,
  });
}

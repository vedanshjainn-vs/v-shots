// ════════════════════════════════════════════════
// Project Lyra — Failure Hierarchy
// ════════════════════════════════════════════════
//
// Complete failure hierarchy for all domains.
// Every feature maps exceptions to these failures.
// UI reads failures to show appropriate messages.
// ════════════════════════════════════════════════

import 'package:equatable/equatable.dart';

/// Base failure class for the entire application.
///
/// All custom failures extend this class.
/// Failures travel: Data → Domain → Presentation.
abstract class Failure extends Equatable {
  const Failure({
    required this.message,
    this.code,
    this.isRetryable = false,
    this.metadata = const {},
  });

  /// Human-readable error message.
  final String message;

  /// Machine-readable error code.
  final String? code;

  /// Whether the operation can be retried.
  final bool isRetryable;

  /// Additional context about the failure.
  final Map<String, dynamic> metadata;

  @override
  List<Object?> get props => [message, code, isRetryable];
}

// ── Network Failures ──────────────────────────

class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection',
    super.code,
    super.isRetryable = true,
  });
}

class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.code,
    this.statusCode,
    super.isRetryable,
  });

  final int? statusCode;

  @override
  List<Object?> get props => [message, code, statusCode, isRetryable];
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({
    super.message = 'Request timed out',
    super.code,
    super.isRetryable = true,
  });
}

class RateLimitFailure extends Failure {
  const RateLimitFailure({
    super.message = 'Too many requests',
    super.code,
    this.retryAfter,
    super.isRetryable = true,
  });

  final Duration? retryAfter;

  @override
  List<Object?> get props => [message, code, retryAfter];
}

// ── Auth Failures ─────────────────────────────

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({
    super.message = 'Please sign in to continue',
    super.code,
  });
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure({
    super.message = 'You don\'t have permission to access this',
    super.code,
  });
}

class TokenExpiredFailure extends Failure {
  const TokenExpiredFailure({
    super.message = 'Session expired',
    super.code,
  });
}

class AccountDisabledFailure extends Failure {
  const AccountDisabledFailure({
    super.message = 'Account has been disabled',
    super.code,
  });
}

// ── Data Failures ─────────────────────────────

class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Unable to load cached data',
    super.code,
  });
}

class DatabaseFailure extends Failure {
  const DatabaseFailure({
    super.message = 'Database error',
    super.code,
    super.isRetryable = true,
  });
}

class SerializationFailure extends Failure {
  const SerializationFailure({
    super.message = 'Data parsing error',
    super.code,
  });
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = 'Content not found',
    super.code,
  });
}

class ConflictFailure extends Failure {
  const ConflictFailure({
    super.message = 'Data conflict detected',
    super.code,
    this.localVersion,
    this.serverVersion,
  });

  final dynamic localVersion;
  final dynamic serverVersion;
}

// ── Validation Failures ───────────────────────

class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.code,
    this.fieldErrors = const {},
  });

  final Map<String, List<String>> fieldErrors;

  @override
  List<Object?> get props => [message, code, fieldErrors];
}

// ── Feature-Specific Failures ─────────────────

class DownloadFailure extends Failure {
  const DownloadFailure({
    super.message = 'Download failed',
    super.code,
    super.isRetryable = true,
    this.downloadId,
  });

  final String? downloadId;
}

class PlaybackFailure extends Failure {
  const PlaybackFailure({
    super.message = 'Playback error',
    super.code,
    this.trackId,
  });

  final String? trackId;
}

class AIFailure extends Failure {
  const AIFailure({
    super.message = 'AI service error',
    super.code,
    super.isRetryable = true,
    this.provider,
  });

  final String? provider;
}

class PremiumRequiredFailure extends Failure {
  const PremiumRequiredFailure({
    super.message = 'This feature requires Premium',
    super.code,
  });
}

class PermissionFailure extends Failure {
  const PermissionFailure({
    super.message = 'Permission required',
    super.code,
    this.permissionName,
  });

  final String? permissionName;
}

// ── Catch-all ─────────────────────────────────

class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'Something went wrong',
    super.code,
    this.originalError,
  });

  final Object? originalError;
}

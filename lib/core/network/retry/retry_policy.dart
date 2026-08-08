// ════════════════════════════════════════════════
// Project Lyra — Retry Policy
// ════════════════════════════════════════════════
//
// Configurable retry strategies with exponential
// backoff, jitter, and per-status-code rules.
// ════════════════════════════════════════════════

import 'dart:math';

/// Configuration for request retry behavior.
class RetryPolicy {
  const RetryPolicy({
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.jitter = true,
    this.retryableStatusCodes = const {408, 429, 500, 502, 503, 504},
    this.retryableMethods = const {'GET', 'HEAD', 'OPTIONS'},
  });

  /// Maximum number of retry attempts.
  final int maxRetries;

  /// Base delay for exponential backoff.
  final Duration baseDelay;

  /// Maximum delay cap.
  final Duration maxDelay;

  /// Whether to add random jitter to delays.
  final bool jitter;

  /// HTTP status codes that should be retried.
  final Set<int> retryableStatusCodes;

  /// HTTP methods that are safe to retry.
  final Set<String> retryableMethods;

  /// Predefined policies.
  static const RetryPolicy conservative = RetryPolicy(
    maxRetries: 2,
    baseDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 10),
  );

  static const RetryPolicy aggressive = RetryPolicy(
    maxRetries: 5,
    baseDelay: Duration(milliseconds: 250),
    maxDelay: Duration(seconds: 60),
  );

  static const RetryPolicy none = RetryPolicy(maxRetries: 0);

  /// Calculate delay for a given retry attempt.
  Duration getDelay(int attempt) {
    if (attempt <= 0) return Duration.zero;

    final random = Random();
    final exponentialMs = baseDelay.inMilliseconds * pow(2, attempt - 1);
    final jitterMs = jitter ? random.nextInt(baseDelay.inMilliseconds) : 0;
    final totalMs = (exponentialMs + jitterMs).toInt();

    return Duration(
      milliseconds: totalMs.clamp(0, maxDelay.inMilliseconds),
    );
  }

  /// Whether a request should be retried.
  bool shouldRetry(int? statusCode, String method, int attempt) {
    if (attempt >= maxRetries) return false;
    if (!retryableMethods.contains(method.toUpperCase())) return false;
    if (statusCode != null && !retryableStatusCodes.contains(statusCode)) return false;
    return true;
  }

  /// Whether to retry based on Retry-After header.
  Duration? parseRetryAfter(String? header) {
    if (header == null) return null;

    final seconds = int.tryParse(header);
    if (seconds != null) {
      return Duration(seconds: seconds).clamp(Duration.zero, maxDelay);
    }

    return null;
  }
}

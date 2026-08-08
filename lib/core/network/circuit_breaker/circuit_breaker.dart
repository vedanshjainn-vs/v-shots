// ════════════════════════════════════════════════
// Project Lyra — Circuit Breaker
// ════════════════════════════════════════════════
//
// Prevents cascading failures by stopping requests
// to failing services. Three states:
// - Closed: normal operation
// - Open: requests fail fast
// - Half-Open: testing recovery
// ════════════════════════════════════════════════

import 'dart:async';

import '../../logging/app_logger.dart';

/// State of the circuit breaker.
enum CircuitState {
  /// Normal operation — requests pass through.
  closed,

  /// Failing fast — requests rejected immediately.
  open,

  /// Testing recovery — limited requests allowed.
  halfOpen,
}

/// Circuit breaker configuration.
class CircuitBreakerConfig {
  const CircuitBreakerConfig({
    this.failureThreshold = 5,
    this.successThreshold = 3,
    this.timeout = const Duration(seconds: 30),
    this.halfOpenMaxCalls = 3,
  });

  /// Number of failures before opening the circuit.
  final int failureThreshold;

  /// Number of successes in half-open before closing.
  final int successThreshold;

  /// How long the circuit stays open before trying half-open.
  final Duration timeout;

  /// Maximum concurrent calls in half-open state.
  final int halfOpenMaxCalls;
}

/// Circuit breaker implementation.
///
/// Prevents cascading failures by failing fast when
/// a service is unavailable.
///
/// ```dart
/// final breaker = CircuitBreaker(
///   name: 'supabase',
///   config: CircuitBreakerConfig(failureThreshold: 5),
/// );
///
/// final result = await breaker.execute(() => api.fetchData());
/// ```
class CircuitBreaker {
  CircuitBreaker({
    required this.name,
    this.config = const CircuitBreakerConfig(),
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final String name;
  final CircuitBreakerConfig config;
  final AppLogger _logger;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  int _successCount = 0;
  int _halfOpenCalls = 0;
  DateTime? _lastFailureTime;
  DateTime? _openedAt;

  /// Current circuit state.
  CircuitState get state => _state;

  /// Whether the circuit is allowing requests.
  bool get isAvailable => _state != CircuitState.open;

  /// Execute a function through the circuit breaker.
  ///
  /// Throws [CircuitBreakerOpenException] if the circuit is open.
  Future<T> execute<T>(Future<T> Function() operation) async {
    _checkState();

    if (_state == CircuitState.open) {
      throw CircuitBreakerOpenException(name);
    }

    if (_state == CircuitState.halfOpen) {
      _halfOpenCalls++;
    }

    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  void _checkState() {
    if (_state == CircuitState.open && _openedAt != null) {
      if (DateTime.now().difference(_openedAt!) > config.timeout) {
        _logger.d('CircuitBreaker[$name]: Transitioning to half-open');
        _state = CircuitState.halfOpen;
        _halfOpenCalls = 0;
        _successCount = 0;
      }
    }
  }

  void _onSuccess() {
    if (_state == CircuitState.halfOpen) {
      _successCount++;
      if (_successCount >= config.successThreshold) {
        _logger.i('CircuitBreaker[$name]: Recovery confirmed, closing circuit');
        _state = CircuitState.closed;
        _failureCount = 0;
        _successCount = 0;
        _halfOpenCalls = 0;
      }
    } else {
      _failureCount = 0;
    }
  }

  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_state == CircuitState.halfOpen) {
      _logger.w('CircuitBreaker[$name]: Failure in half-open, reopening');
      _state = CircuitState.open;
      _openedAt = DateTime.now();
    } else if (_failureCount >= config.failureThreshold) {
      _logger.w('CircuitBreaker[$name]: Threshold reached, opening circuit');
      _state = CircuitState.open;
      _openedAt = DateTime.now();
    }
  }

  /// Reset the circuit breaker to closed state.
  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _successCount = 0;
    _halfOpenCalls = 0;
    _lastFailureTime = null;
    _openedAt = null;
  }
}

/// Exception thrown when the circuit is open.
class CircuitBreakerOpenException implements Exception {
  const CircuitBreakerOpenException(this.serviceName);

  final String serviceName;

  @override
  String toString() =>
      'Circuit breaker for "$serviceName" is open. Service unavailable.';
}

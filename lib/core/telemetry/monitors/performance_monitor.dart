// ════════════════════════════════════════════════
// Project Lyra — Performance Monitor
// ════════════════════════════════════════════════
//
// Tracks app performance metrics:
// - Startup time
// - Frame rate (FPS)
// - Memory usage
// - Network latency
// - Widget build times
// ════════════════════════════════════════════════

import 'dart:async';

import '../../logging/app_logger.dart';

/// Central performance monitoring service.
///
/// Tracks key metrics and reports anomalies.
/// In production, feeds data to crashlytics/analytics.
///
/// ```dart
/// final monitor = PerformanceMonitor();
/// monitor.startTracking();
///
/// // Measure a specific operation.
/// final result = await monitor.measure('load_home_feed', () async {
///   return await repo.getFeed();
/// });
/// ```
class PerformanceMonitor {
  PerformanceMonitor({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;
  final _metrics = <String, PerformanceMetric>{};
  final _startups = <String, Stopwatch>{};

  bool _isTracking = false;

  /// Start continuous performance tracking.
  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    _logger.d('PerformanceMonitor: Tracking started');
  }

  /// Stop tracking.
  void stopTracking() {
    _isTracking = false;
  }

  /// Measure the execution time of an async operation.
  Future<T> measure<T>(String name, Future<T> Function() operation) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await operation();
      stopwatch.stop();
      _recordMetric(name, stopwatch.elapsedMilliseconds, success: true);
      return result;
    } catch (e) {
      stopwatch.stop();
      _recordMetric(name, stopwatch.elapsedMilliseconds, success: false);
      rethrow;
    }
  }

  /// Measure the execution time of a sync operation.
  T measureSync<T>(String name, T Function() operation) {
    final stopwatch = Stopwatch()..start();

    try {
      final result = operation();
      stopwatch.stop();
      _recordMetric(name, stopwatch.elapsedMilliseconds, success: true);
      return result;
    } catch (e) {
      stopwatch.stop();
      _recordMetric(name, stopwatch.elapsedMilliseconds, success: false);
      rethrow;
    }
  }

  /// Start a named timer.
  void startTimer(String name) {
    _startups[name] = Stopwatch()..start();
  }

  /// Stop a named timer and record the metric.
  int stopTimer(String name) {
    final stopwatch = _startups.remove(name);
    if (stopwatch == null) return 0;

    stopwatch.stop();
    final ms = stopwatch.elapsedMilliseconds;
    _recordMetric(name, ms, success: true);
    return ms;
  }

  /// Record a custom metric.
  void recordMetric(String name, int valueMs, {bool success = true}) {
    _recordMetric(name, valueMs, success: success);
  }

  /// Get all recorded metrics.
  Map<String, PerformanceMetric> get metrics => Map.unmodifiable(_metrics);

  /// Get a specific metric.
  PerformanceMetric? getMetric(String name) => _metrics[name];

  /// Clear all metrics.
  void clear() {
    _metrics.clear();
  }

  void _recordMetric(String name, int valueMs, {required bool success}) {
    final existing = _metrics[name];

    if (existing == null) {
      _metrics[name] = PerformanceMetric(
        name: name,
        count: 1,
        totalMs: valueMs,
        minMs: valueMs,
        maxMs: valueMs,
        successCount: success ? 1 : 0,
        failCount: success ? 0 : 1,
      );
    } else {
      _metrics[name] = existing.copyWith(
        count: existing.count + 1,
        totalMs: existing.totalMs + valueMs,
        minMs: valueMs < existing.minMs ? valueMs : existing.minMs,
        maxMs: valueMs > existing.maxMs ? valueMs : existing.maxMs,
        successCount: existing.successCount + (success ? 1 : 0),
        failCount: existing.failCount + (success ? 0 : 1),
      );
    }

    // Log slow operations.
    if (valueMs > 1000) {
      _logger.w('PerformanceMonitor: SLOW "$name" took ${valueMs}ms');
    }
  }
}

/// Aggregated performance metric.
class PerformanceMetric {
  const PerformanceMetric({
    required this.name,
    required this.count,
    required this.totalMs,
    required this.minMs,
    required this.maxMs,
    required this.successCount,
    required this.failCount,
  });

  final String name;
  final int count;
  final int totalMs;
  final int minMs;
  final int maxMs;
  final int successCount;
  final int failCount;

  double get averageMs => count > 0 ? totalMs / count : 0;
  double get successRate => count > 0 ? successCount / count : 0;

  PerformanceMetric copyWith({
    int? count,
    int? totalMs,
    int? minMs,
    int? maxMs,
    int? successCount,
    int? failCount,
  }) {
    return PerformanceMetric(
      name: name,
      count: count ?? this.count,
      totalMs: totalMs ?? this.totalMs,
      minMs: minMs ?? this.minMs,
      maxMs: maxMs ?? this.maxMs,
      successCount: successCount ?? this.successCount,
      failCount: failCount ?? this.failCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'count': count,
        'averageMs': averageMs,
        'minMs': minMs,
        'maxMs': maxMs,
        'totalMs': totalMs,
        'successRate': successRate,
      };
}

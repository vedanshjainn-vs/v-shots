// ════════════════════════════════════════════════
// Project Lyra — Provider Metrics
// ════════════════════════════════════════════════
//
// Tracks provider performance metrics:
// - Latency
// - Success/failure rates
// - Failover count
// - Cache hits
// - Provider usage
// ════════════════════════════════════════════════

import '../../logging/app_logger.dart';

/// Tracks metrics for all music providers.
class ProviderMetrics {
  ProviderMetrics({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;
  final Map<String, _ProviderStats> _stats = {};
  int _failoverCount = 0;
  int _cacheHits = 0;
  int _totalRequests = 0;

  /// Record a successful request.
  void recordSuccess({
    required String providerId,
    required String operation,
    required int latencyMs,
  }) {
    _totalRequests++;
    _getStats(providerId).recordSuccess(operation, latencyMs);
  }

  /// Record a failed request.
  void recordFailure({
    required String providerId,
    required String operation,
    required String error,
    required int latencyMs,
  }) {
    _totalRequests++;
    _getStats(providerId).recordFailure(operation, error);
  }

  /// Record a failover event.
  void recordFailover({required String from, required String to}) {
    _failoverCount++;
    _logger.d('ProviderMetrics: Failover from $from to $to');
  }

  /// Record a cache hit.
  void recordCacheHit(String operation) {
    _cacheHits++;
  }

  /// Get a snapshot of all metrics.
  ProviderMetricsSnapshot get snapshot {
    return ProviderMetricsSnapshot(
      totalRequests: _totalRequests,
      failoverCount: _failoverCount,
      cacheHits: _cacheHits,
      cacheHitRate: _totalRequests > 0 ? _cacheHits / _totalRequests : 0,
      providerStats: Map.fromEntries(
        _stats.entries.map((e) => MapEntry(e.key, e.value.snapshot)),
      ),
    );
  }

  /// Reset all metrics.
  void reset() {
    _stats.clear();
    _failoverCount = 0;
    _cacheHits = 0;
    _totalRequests = 0;
  }

  _ProviderStats _getStats(String providerId) {
    return _stats.putIfAbsent(providerId, () => _ProviderStats());
  }
}

class _ProviderStats {
  int _successCount = 0;
  int _failureCount = 0;
  int _totalLatencyMs = 0;
  final Map<String, int> _operationCounts = {};
  final List<String> _recentErrors = [];

  void recordSuccess(String operation, int latencyMs) {
    _successCount++;
    _totalLatencyMs += latencyMs;
    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;
  }

  void recordFailure(String operation, String error) {
    _failureCount++;
    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;
    _recentErrors.add(error);
    if (_recentErrors.length > 10) _recentErrors.removeAt(0);
  }

  ProviderStatsSnapshot get snapshot {
    final total = _successCount + _failureCount;
    return ProviderStatsSnapshot(
      successCount: _successCount,
      failureCount: _failureCount,
      successRate: total > 0 ? _successCount / total : 0,
      averageLatencyMs: _successCount > 0 ? _totalLatencyMs / _successCount : 0,
      operationCounts: Map.from(_operationCounts),
      recentErrors: List.from(_recentErrors),
    );
  }
}

/// Snapshot of all provider metrics.
class ProviderMetricsSnapshot {
  const ProviderMetricsSnapshot({
    required this.totalRequests,
    required this.failoverCount,
    required this.cacheHits,
    required this.cacheHitRate,
    required this.providerStats,
  });

  final int totalRequests;
  final int failoverCount;
  final int cacheHits;
  final double cacheHitRate;
  final Map<String, ProviderStatsSnapshot> providerStats;
}

/// Snapshot of a single provider's stats.
class ProviderStatsSnapshot {
  const ProviderStatsSnapshot({
    required this.successCount,
    required this.failureCount,
    required this.successRate,
    required this.averageLatencyMs,
    required this.operationCounts,
    required this.recentErrors,
  });

  final int successCount;
  final int failureCount;
  final double successRate;
  final double averageLatencyMs;
  final Map<String, int> operationCounts;
  final List<String> recentErrors;
}

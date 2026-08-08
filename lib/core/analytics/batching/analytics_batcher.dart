// ════════════════════════════════════════════════
// Project Lyra — Analytics Batcher
// ════════════════════════════════════════════════
//
// Batches analytics events to reduce network
// calls and battery usage. Flushes on:
// - Batch size threshold
// - Timer interval
// - App backgrounding
// ════════════════════════════════════════════════

import 'dart:async';

import '../../logging/app_logger.dart';
import '../events/analytics_event.dart';

/// Batches analytics events for efficient delivery.
///
/// Collects events in a buffer and flushes them
/// in batches to reduce network overhead.
///
/// ```dart
/// final batcher = AnalyticsBatcher(
///   onFlush: (events) => analyticsService.sendBatch(events),
/// );
/// batcher.track(event);
/// ```
class AnalyticsBatcher {
  AnalyticsBatcher({
    this.maxBatchSize = 50,
    this.flushInterval = const Duration(seconds: 30),
    this.maxBufferSize = 500,
    required this.onFlush,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance {
    _startFlushTimer();
  }

  final int maxBatchSize;
  final Duration flushInterval;
  final int maxBufferSize;
  final Future<void> Function(List<AnalyticsEvent> events) onFlush;
  final AppLogger _logger;

  final List<AnalyticsEvent> _buffer = [];
  Timer? _flushTimer;
  bool _isFlushing = false;

  /// Add an event to the batch buffer.
  void track(AnalyticsEvent event) {
    _buffer.add(event);

    // Drop oldest events if buffer is full.
    if (_buffer.length > maxBufferSize) {
      _buffer.removeAt(0);
    }

    // Flush if batch size reached.
    if (_buffer.length >= maxBatchSize) {
      flush();
    }
  }

  /// Flush all buffered events.
  Future<void> flush() async {
    if (_buffer.isEmpty || _isFlushing) return;

    _isFlushing = true;
    final batch = List<AnalyticsEvent>.from(_buffer);
    _buffer.clear();

    try {
      await onFlush(batch);
      _logger.d('AnalyticsBatcher: Flushed ${batch.length} events');
    } catch (e, st) {
      _logger.e('AnalyticsBatcher: Flush failed', error: e, stackTrace: st);
      // Re-add failed events to buffer.
      _buffer.insertAll(0, batch);
    } finally {
      _isFlushing = false;
    }
  }

  void _startFlushTimer() {
    _flushTimer = Timer.periodic(flushInterval, (_) => flush());
  }

  /// Number of events in the buffer.
  int get bufferLength => _buffer.length;

  /// Dispose the batcher.
  void dispose() {
    _flushTimer?.cancel();
    flush();
  }
}

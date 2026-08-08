// ════════════════════════════════════════════════
// Project Lyra — Request Deduplication
// ════════════════════════════════════════════════
//
// Prevents duplicate in-flight requests.
// If the same GET request is already in progress,
// the second caller shares the same response.
// ════════════════════════════════════════════════

import 'dart:async';

import 'package:dio/dio.dart';

import '../../logging/app_logger.dart';

/// Deduplicates identical in-flight requests.
///
/// When multiple callers request the same URL simultaneously,
/// only one network call is made. All callers receive the
/// same response.
///
/// ```dart
/// final deduplicator = RequestDeduplicator();
/// // Both calls share the same network request.
/// final result1 = deduplicator.execute(options, () => dio.fetch(options));
/// final result2 = deduplicator.execute(options, () => dio.fetch(options));
/// ```
class RequestDeduplicator {
  RequestDeduplicator({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  /// In-flight requests: key → Completer<Response>.
  final Map<String, Completer<Response>> _inFlight = {};

  /// Number of deduplicated requests.
  int _deduplicatedCount = 0;

  /// Total deduplication savings.
  int get deduplicatedCount => _deduplicatedCount;

  /// Execute a request with deduplication.
  ///
  /// If an identical request is already in flight,
  /// returns the same response without making a new call.
  Future<Response> execute(
    RequestOptions options,
    Future<Response> Function() request,
  ) async {
    // Only deduplicate GET requests.
    if (options.method.toUpperCase() != 'GET') {
      return request();
    }

    // Skip if explicitly disabled.
    if (options.extra['noDedup'] == true) {
      return request();
    }

    final key = _requestKey(options);

    // If an identical request is already in flight, wait for it.
    if (_inFlight.containsKey(key)) {
      _deduplicatedCount++;
      _logger.d('Deduplicator: Sharing response for $key');
      return _inFlight[key]!.future;
    }

    // Start a new request.
    final completer = Completer<Response>();
    _inFlight[key] = completer;

    try {
      final response = await request();
      completer.complete(response);
      return response;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Generate a unique key for a request.
  String _requestKey(RequestOptions options) {
    final uri = options.uri.toString();
    final headers = options.headers.toString();
    return '$uri|$headers';
  }

  /// Cancel all in-flight deduplicated requests.
  void cancelAll() {
    for (final completer in _inFlight.values) {
      if (!completer.isCompleted) {
        completer.completeError(CancelledException('Cancelled by deduplicator'));
      }
    }
    _inFlight.clear();
  }

  /// Number of currently in-flight requests.
  int get inFlightCount => _inFlight.length;
}

/// Exception for cancelled requests.
class CancelledException implements Exception {
  const CancelledException(this.message);
  final String message;

  @override
  String toString() => 'CancelledException: $message';
}

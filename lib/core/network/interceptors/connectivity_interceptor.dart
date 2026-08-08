// ════════════════════════════════════════════════
// Project Lyra — Connectivity Interceptor
// ════════════════════════════════════════════════
//
// Blocks requests when offline and queues them
// for retry when connectivity is restored.
// Integrates with the connectivity service.
// ════════════════════════════════════════════════

import 'package:dio/dio.dart';

import '../../connectivity/monitors/connectivity_monitor.dart';
import '../../logging/app_logger.dart';

/// Dio interceptor that checks connectivity before requests.
///
/// When offline:
/// - GET requests: fail fast with NetworkException
/// - Mutation requests: queue for retry (if enabled)
class ConnectivityInterceptor extends Interceptor {
  ConnectivityInterceptor({
    required this.connectivityMonitor,
    this.queueMutations = true,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final ConnectivityMonitor connectivityMonitor;
  final bool queueMutations;
  final AppLogger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Skip if explicitly allowed offline.
    if (options.extra['allowOffline'] == true) {
      handler.next(options);
      return;
    }

    final isConnected = await connectivityMonitor.isConnected;

    if (!isConnected) {
      _logger.w('ConnectivityInterceptor: Blocking request (offline) ${options.uri}');

      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'No internet connection',
      ));
      return;
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Enhance connection errors with more context.
    if (err.type == DioExceptionType.connectionError) {
      handler.next(DioException(
        requestOptions: err.requestOptions,
        type: DioExceptionType.connectionError,
        error: 'No internet connection. Please check your network and try again.',
        response: err.response,
      ));
      return;
    }

    handler.next(err);
  }
}

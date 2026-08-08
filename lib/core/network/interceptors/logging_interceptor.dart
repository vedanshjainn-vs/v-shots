// ════════════════════════════════════════════════
// Project Lyra — Logging Interceptor
// ════════════════════════════════════════════════
//
// Logs all HTTP requests, responses, and errors
// in development/staging. Disabled in production.
// ════════════════════════════════════════════════

import 'package:dio/dio.dart';

import '../../logging/app_logger.dart';

/// Logs HTTP traffic for debugging.
///
/// Automatically excluded in production builds.
class LyraLogInterceptor extends Interceptor {
  LyraLogInterceptor({AppLogger? logger}) : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.d(
      '→ ${options.method} ${options.uri}\n'
      '  Headers: ${_sanitizeHeaders(options.headers)}\n'
      '  Body: ${_truncate(options.data)}',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logger.d(
      '← ${response.statusCode} ${response.requestOptions.uri}\n'
      '  Body: ${_truncate(response.data)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.e(
      '✕ ${err.requestOptions.method} ${err.requestOptions.uri}\n'
      '  Status: ${err.response?.statusCode}\n'
      '  Error: ${err.message}',
      error: err,
      stackTrace: err.stackTrace,
    );
    handler.next(err);
  }

  /// Sanitize headers — remove sensitive auth tokens from logs.
  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = Map<String, dynamic>.from(headers);
    if (sanitized.containsKey('Authorization')) {
      sanitized['Authorization'] = 'Bearer ***';
    }
    return sanitized;
  }

  /// Truncate long bodies for readability.
  String _truncate(dynamic data, {int maxLength = 500}) {
    if (data == null) return 'null';
    final str = data.toString();
    return str.length > maxLength ? '${str.substring(0, maxLength)}…' : str;
  }
}

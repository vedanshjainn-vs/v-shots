// ════════════════════════════════════════════════
// Project Lyra — Auth Interceptor
// ════════════════════════════════════════════════
//
// Injects auth tokens, handles token refresh,
// and triggers re-auth on 401 responses.
// ════════════════════════════════════════════════

import 'package:dio/dio.dart';

import '../../../config/constants/api_constants.dart';
import '../../logging/app_logger.dart';

/// Attaches the Bearer token to every request and
/// handles automatic token refresh on 401.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.dio});

  final Dio dio;
  final _logger = AppLogger.instance;

  // TODO(team): Inject token repository via Riverpod.
  // For now, this is a scaffold.

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // TODO(team): Read token from secure storage.
    // final token = _tokenRepository.accessToken;
    // if (token != null) {
    //   options.headers[ApiConstants.headerAuth] =
    //       '${ApiConstants.headerBearer} $token';
    // }

    // Always attach request ID for tracing.
    options.headers[ApiConstants.headerRequestId] =
        _generateRequestId();

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      _logger.w('Auth interceptor: 401 received, attempting token refresh');

      // TODO(team): Implement token refresh logic.
      // 1. Call refresh endpoint
      // 2. Update stored tokens
      // 3. Retry original request
      // 4. If refresh fails → force logout

      // For now, pass through.
      handler.next(err);
      return;
    }

    handler.next(err);
  }

  String _generateRequestId() {
    return '${DateTime.now().millisecondsSinceEpoch}';
  }
}

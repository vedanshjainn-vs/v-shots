// ════════════════════════════════════════════════
// Project Lyra — Dio HTTP Client
// ════════════════════════════════════════════════
//
// Pre-configured Dio instance with interceptors
// for auth, logging, retry, and caching.
// ════════════════════════════════════════════════

import 'package:dio/dio.dart';

import '../../config/constants/app_constants.dart';
import '../../config/environment/env.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

/// Factory that creates and configures a [Dio] client.
///
/// Each feature can request its own Dio instance or share one
/// via Riverpod provider injection.
abstract final class DioClient {
  /// Creates a fully configured [Dio] instance.
  ///
  /// [baseUrl] defaults to the current environment's API URL.
  /// [extraInterceptors] allows features to add their own.
  static Dio create({
    String? baseUrl,
    List<Interceptor>? extraInterceptors,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? Env.instance.apiBaseUrl,
        connectTimeout: AppConstants.connectionTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        sendTimeout: AppConstants.sendTimeout,
        contentType: 'application/json',
        responseType: ResponseType.json,
        headers: {
          'Accept': 'application/json',
          'X-Platform': 'android',
        },
      ),
    );

    // Interceptors are executed in order.
    dio.interceptors.addAll([
      AuthInterceptor(dio: dio),
      RetryInterceptor(dio: dio),
      if (Env.instance.enableLogging) LyraLogInterceptor(),
      ...?extraInterceptors,
    ]);

    return dio;
  }
}

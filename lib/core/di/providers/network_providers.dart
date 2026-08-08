// ════════════════════════════════════════════════
// Project Lyra — Network Providers
// ════════════════════════════════════════════════
//
// Riverpod providers for network-related services.
// Features override these for testing.
// ════════════════════════════════════════════════

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/dio_client.dart';
import '../../network/network_info.dart';

/// Base Dio client (shared across features).
final baseDioProvider = Provider<Dio>((ref) {
  return DioClient.create();
});

/// Network info provider.
final baseNetworkInfoProvider = Provider<NetworkInfo>((ref) {
  final info = NetworkInfoImpl();
  ref.onDispose(info.dispose);
  return info;
});

/// Creates a feature-specific Dio client with custom interceptors.
///
/// Usage:
/// ```dart
/// final dio = ref.watch(featureDioProvider(interceptors: [MyInterceptor()]));
/// ```
final featureDioProvider = Provider.family<Dio, List<Interceptor>?>((ref, interceptors) {
  return DioClient.create(extraInterceptors: interceptors);
});

// ════════════════════════════════════════════════
// Project Lyra — Core Providers
// ════════════════════════════════════════════════
//
// Riverpod providers for core app-level concerns.
// Package info, connectivity status, app lifecycle.
// ════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../enums/connection_status.dart';
import '../../logging/app_logger.dart';
import '../../network/network_info.dart';

/// App package info (version, build number, etc.)
final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// Current connectivity status (reactive).
final connectivityProvider = StreamProvider<ConnectionStatus>((ref) {
  final networkInfo = ref.watch(baseNetworkInfoProvider);
  return networkInfo.onConnectivityChanged;
});

/// Whether the device is currently connected to the internet.
final isConnectedProvider = FutureProvider<bool>((ref) {
  final networkInfo = ref.watch(baseNetworkInfoProvider);
  return networkInfo.isConnected;
});

/// App logger singleton.
final loggerProvider = Provider<AppLogger>((ref) {
  return AppLogger.instance;
});

// Import needed provider from network_providers.
import 'network_providers.dart';

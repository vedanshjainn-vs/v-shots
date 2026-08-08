// ════════════════════════════════════════════════
// Project Lyra — Connectivity Mixin
// ════════════════════════════════════════════════
//
// Monitors connectivity changes and provides
// offline/online callbacks for notifiers.
// ════════════════════════════════════════════════

import 'dart:async';

import '../../enums/connection_status.dart';
import '../../network/network_info.dart';

/// Mixin for connectivity-aware notifiers.
///
/// ```dart
/// class MyNotifier extends StateNotifier<...> with ConnectivityMixin {
///   MyNotifier({required NetworkInfo networkInfo}) {
///     initConnectivity(networkInfo);
///   }
///
///   @override
///   void onConnected() => refreshData();
///
///   @override
///   void onDisconnected() => showOfflineBanner();
/// }
/// ```
mixin ConnectivityMixin {
  StreamSubscription<ConnectionStatus>? _connectivitySub;
  ConnectionStatus _connectionStatus = ConnectionStatus.unknown;

  ConnectionStatus get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus.isConnected;
  bool get isDisconnected => _connectionStatus.isDisconnected;
  bool get isWifi => _connectionStatus.isWifi;
  bool get isMobile => _connectionStatus.isMobile;

  /// Initialize connectivity monitoring.
  void initConnectivity(NetworkInfo networkInfo) {
    _connectivitySub = networkInfo.onConnectivityChanged.listen((status) {
      final wasConnected = _connectionStatus.isConnected;
      _connectionStatus = status;

      if (!wasConnected && status.isConnected) {
        onConnected();
      } else if (wasConnected && !status.isConnected) {
        onDisconnected();
      }
    });
  }

  /// Called when the device comes back online.
  void onConnected() {}

  /// Called when the device goes offline.
  void onDisconnected() {}

  /// Dispose connectivity subscription.
  void disposeConnectivity() {
    _connectivitySub?.cancel();
  }
}

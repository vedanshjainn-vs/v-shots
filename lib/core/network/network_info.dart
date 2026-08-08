// ════════════════════════════════════════════════
// Project Lyra — Network Info
// ════════════════════════════════════════════════
//
// Monitors connectivity status in real-time.
// Uses connectivity_plus for cross-platform checks.
// ════════════════════════════════════════════════

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../enums/connection_status.dart';

/// Abstraction for network connectivity checking.
///
/// Allows mocking in tests.
abstract class NetworkInfo {
  /// Check if device is currently connected.
  Future<bool> get isConnected;

  /// Stream of connectivity changes.
  Stream<ConnectionStatus> get onConnectivityChanged;

  /// Current connection status.
  Future<ConnectionStatus> get connectionStatus;

  /// Dispose resources.
  void dispose();
}

/// Production implementation using [Connectivity].
class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final _controller = StreamController<ConnectionStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  Stream<ConnectionStatus> get onConnectivityChanged {
    _subscription ??= _connectivity.onConnectivityChanged.listen((results) {
      _controller.add(_mapResults(results));
    });
    return _controller.stream;
  }

  @override
  Future<ConnectionStatus> get connectionStatus async {
    final results = await _connectivity.checkConnectivity();
    return _mapResults(results);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }

  ConnectionStatus _mapResults(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return ConnectionStatus.disconnected;
    }

    if (results.contains(ConnectivityResult.wifi)) {
      return ConnectionStatus.wifi;
    }

    if (results.contains(ConnectivityResult.mobile)) {
      return ConnectionStatus.mobile;
    }

    return ConnectionStatus.connected;
  }
}

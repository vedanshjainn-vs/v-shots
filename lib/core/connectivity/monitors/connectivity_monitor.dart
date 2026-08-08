// ════════════════════════════════════════════════
// Project Lyra — Connectivity Monitor
// ════════════════════════════════════════════════
//
// Advanced connectivity monitoring with:
// - Real-time status stream
// - Network quality estimation
// - Auto-reconnect detection
// - Integration with sync engine
// ════════════════════════════════════════════════

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../enums/connection_status.dart';
import '../../events/bus/app_event_bus.dart';
import '../../events/types/app_event.dart';
import '../../logging/app_logger.dart';

/// Quality of the network connection.
enum NetworkQuality {
  /// No connection.
  none,

  /// Poor connection (< 1 Mbps).
  poor,

  /// Moderate connection (1-5 Mbps).
  moderate,

  /// Good connection (5-20 Mbps).
  good,

  /// Excellent connection (> 20 Mbps).
  excellent,
}

/// Advanced connectivity monitoring service.
///
/// Provides real-time connectivity status, quality estimation,
/// and auto-reconnect detection. Integrates with the event
/// bus for app-wide connectivity events.
///
/// ```dart
/// final monitor = ConnectivityMonitor(eventBus: eventBus);
/// await monitor.initialize();
///
/// if (await monitor.isConnected) {
///   // Fetch data.
/// }
///
/// monitor.statusStream.listen((status) {
///   // React to connectivity changes.
/// });
/// ```
class ConnectivityMonitor {
  ConnectivityMonitor({
    Connectivity? connectivity,
    AppEventBus? eventBus,
    AppLogger? logger,
  })  : _connectivity = connectivity ?? Connectivity(),
        _eventBus = eventBus,
        _logger = logger ?? AppLogger.instance;

  final Connectivity _connectivity;
  final AppEventBus? _eventBus;
  final AppLogger _logger;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _qualityController = StreamController<NetworkQuality>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  ConnectionStatus _currentStatus = ConnectionStatus.unknown;
  NetworkQuality _currentQuality = NetworkQuality.none;
  DateTime? _lastConnectedAt;
  DateTime? _lastDisconnectedAt;

  /// Stream of connectivity status changes.
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  /// Stream of network quality changes.
  Stream<NetworkQuality> get qualityStream => _qualityController.stream;

  /// Current connectivity status.
  ConnectionStatus get currentStatus => _currentStatus;

  /// Current network quality.
  NetworkQuality get currentQuality => _currentQuality;

  /// Whether the device is currently connected.
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Whether the device is on WiFi.
  Future<bool> get isWifi async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  /// Duration since last connected.
  Duration? get offlineDuration {
    if (_lastDisconnectedAt == null) return null;
    return DateTime.now().difference(_lastDisconnectedAt!);
  }

  /// Initialize connectivity monitoring.
  Future<void> initialize() async {
    // Check initial status.
    final results = await _connectivity.checkConnectivity();
    _updateStatus(_mapResults(results));

    // Listen for changes.
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(_mapResults(results));
    });

    _logger.d('ConnectivityMonitor: Initialized');
  }

  /// Estimate network quality (basic heuristic).
  Future<NetworkQuality> estimateQuality() async {
    if (!await isConnected) return NetworkQuality.none;

    // TODO(team): Implement actual bandwidth measurement.
    // For now, estimate based on connection type.
    final results = await _connectivity.checkConnectivity();

    if (results.contains(ConnectivityResult.wifi)) {
      return NetworkQuality.good;
    } else if (results.contains(ConnectivityResult.mobile)) {
      return NetworkQuality.moderate;
    }

    return NetworkQuality.poor;
  }

  void _updateStatus(ConnectionStatus newStatus) {
    final wasConnected = _currentStatus.isConnected;
    _currentStatus = newStatus;

    _statusController.add(newStatus);

    if (!wasConnected && newStatus.isConnected) {
      _lastConnectedAt = DateTime.now();
      _logger.i('ConnectivityMonitor: Back online');
      _eventBus?.emit(const ConnectivityRestoredEvent());
    } else if (wasConnected && !newStatus.isConnected) {
      _lastDisconnectedAt = DateTime.now();
      _logger.w('ConnectivityMonitor: Gone offline');
      _eventBus?.emit(const ConnectivityLostEvent());
    }
  }

  ConnectionStatus _mapResults(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return ConnectionStatus.disconnected;
    }
    if (results.contains(ConnectivityResult.wifi)) return ConnectionStatus.wifi;
    if (results.contains(ConnectivityResult.mobile)) return ConnectionStatus.mobile;
    return ConnectionStatus.connected;
  }

  /// Dispose resources.
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
    _qualityController.close();
  }
}

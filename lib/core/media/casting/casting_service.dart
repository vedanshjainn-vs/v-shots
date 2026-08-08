// ════════════════════════════════════════════════
// Project Lyra — Casting Service
// ════════════════════════════════════════════════
//
// Abstraction for casting audio to external devices.
// Supports Chromecast, AirPlay, and DLNA.
// Architecture only — no implementation yet.
// ════════════════════════════════════════════════

/// Type of casting device.
enum CastDeviceType {
  chromecast,
  airplay,
  dlna,
  bluetooth,
  androidAuto,
  carplay,
}

/// A discovered casting device.
class CastDevice {
  const CastDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isConnected = false,
    this.metadata = const {},
  });

  final String id;
  final String name;
  final CastDeviceType type;
  final bool isConnected;
  final Map<String, dynamic> metadata;
}

/// Status of a casting session.
enum CastSessionStatus {
  disconnected,
  connecting,
  connected,
  playing,
  paused,
  buffering,
  error,
}

/// Abstract casting service interface.
///
/// Implement for Chromecast, AirPlay, DLNA, etc.
///
/// ```dart
/// final cast = CastingService();
/// final devices = await cast.discoverDevices();
/// await cast.connect(devices.first);
/// await cast.castTrack(track);
/// ```
abstract class CastingService {
  /// Whether casting is available on this device.
  Future<bool> get isAvailable;

  /// Discover available casting devices.
  Future<List<CastDevice>> discoverDevices();

  /// Stream of discovered devices.
  Stream<List<CastDevice>> get devicesStream;

  /// Connect to a casting device.
  Future<bool> connect(CastDevice device);

  /// Disconnect from the current device.
  Future<void> disconnect();

  /// Current connection status.
  Stream<CastSessionStatus> get statusStream;

  /// Currently connected device.
  CastDevice? get connectedDevice;

  /// Cast a track to the connected device.
  Future<bool> castTrack({
    required String url,
    required String title,
    String? artist,
    String? artUrl,
  });

  /// Control playback on the cast device.
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);

  /// Set volume on the cast device.
  Future<void> setVolume(double volume);

  /// Dispose resources.
  void dispose();
}

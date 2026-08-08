// ════════════════════════════════════════════════
// Project Lyra — Bluetooth Service
// ════════════════════════════════════════════════
//
// Bluetooth audio device management.
// Handles connection, media controls, and
// device-specific audio routing.
// Architecture only — no implementation yet.
// ════════════════════════════════════════════════

/// Type of Bluetooth audio device.
enum BluetoothDeviceType {
  headset,
  earbuds,
  speaker,
  car,
  unknown,
}

/// A connected Bluetooth audio device.
class BluetoothAudioDevice {
  const BluetoothAudioDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isConnected = false,
    this.supportsA2DP = false,
    this.supportsAVRCP = false,
    this.batteryLevel,
  });

  final String id;
  final String name;
  final BluetoothDeviceType type;
  final bool isConnected;
  final bool supportsA2DP;
  final bool supportsAVRCP;
  final int? batteryLevel;
}

/// Abstract Bluetooth audio service interface.
abstract class BluetoothAudioService {
  /// Whether Bluetooth is enabled.
  Future<bool> get isEnabled;

  /// Currently connected audio device.
  BluetoothAudioDevice? get connectedDevice;

  /// Stream of connection changes.
  Stream<BluetoothAudioDevice?> get connectionStream;

  /// Stream of media button events.
  Stream<BluetoothMediaEvent> get mediaEventStream;

  /// Enable Bluetooth.
  Future<bool> enable();

  /// Get paired devices.
  Future<List<BluetoothAudioDevice>> getPairedDevices();
}

/// Media button events from Bluetooth devices.
enum BluetoothMediaEvent {
  play,
  pause,
  next,
  previous,
  stop,
  fastForward,
  rewind,
}

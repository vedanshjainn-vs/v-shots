// ════════════════════════════════════════════════
// Project Lyra — Connection Status Enum
// ════════════════════════════════════════════════

/// Network connectivity status.
enum ConnectionStatus {
  /// Connected via WiFi.
  wifi,

  /// Connected via mobile data.
  mobile,

  /// Connected (type unknown).
  connected,

  /// No network connection.
  disconnected,

  /// Connection status not yet determined.
  unknown;

  bool get isConnected => this != disconnected && this != unknown;
  bool get isDisconnected => this == disconnected;
  bool get isWifi => this == wifi;
  bool get isMobile => this == mobile;

  /// Whether downloading should proceed
  /// (WiFi-only preference check).
  bool get canDownload => isConnected; // Extend with WiFi-only check.
}

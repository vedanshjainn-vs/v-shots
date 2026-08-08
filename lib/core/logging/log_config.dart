// ════════════════════════════════════════════════
// Project Lyra — Log Configuration
// ════════════════════════════════════════════════

/// Static configuration for the logger.
abstract final class LogConfig {
  /// Number of method calls to show in stack trace.
  static const int methodCount = 2;

  /// Number of method calls to show for errors.
  static const int errorMethodCount = 8;

  /// Max line width before wrapping.
  static const int lineLength = 100;

  /// Whether to show timestamps.
  static const bool showTimestamp = true;

  /// Whether to show log level.
  static const bool showLevel = true;

  /// Custom tag prefix for all logs.
  static const String tag = '[Lyra]';
}

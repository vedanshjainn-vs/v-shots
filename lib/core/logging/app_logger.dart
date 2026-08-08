// ════════════════════════════════════════════════
// Project Lyra — Application Logger
// ════════════════════════════════════════════════
//
// Structured logging via the `logger` package.
// Conditional output based on build flavor.
// Production: logs to Crashlytics only.
// ════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../../config/environment/env.dart';
import '../../config/environment/flavors.dart';
import 'log_config.dart';

/// Centralized logger for the entire application.
///
/// Usage:
/// ```dart
/// AppLogger.instance.d('User logged in', error: user);
/// AppLogger.instance.e('API failed', error: error, stackTrace: st);
/// ```
class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  late final Logger _logger = Logger(
    printer: _createPrinter(),
    level: _resolveLevel(),
    output: ConsoleOutput(),
  );

  /// Verbose / trace logs — very detailed.
  void v(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// Debug logs — development only.
  void d(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Info logs — general operational events.
  void i(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Warning logs — recoverable issues.
  void w(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Error logs — failures that need attention.
  void e(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Fatal / WTF logs — critical failures.
  void f(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  // ── Configuration ────────────────────────────

  Level _resolveLevel() {
    if (Env.instance.flavor.isProduction) return Level.warning;
    if (kReleaseMode) return Level.info;
    return Level.debug;
  }

  LogPrinter _createPrinter() {
    if (Env.instance.flavor.isProduction) {
      return PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 8,
        lineLength: 80,
        colors: false,
        printEmojis: false,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      );
    }

    return PrettyPrinter(
      methodCount: LogConfig.methodCount,
      errorMethodCount: LogConfig.errorMethodCount,
      lineLength: LogConfig.lineLength,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    );
  }
}

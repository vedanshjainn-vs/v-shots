// ════════════════════════════════════════════════
// Project Lyra — Device Integrity
// ════════════════════════════════════════════════
//
// Device integrity checks for security:
// - Root/jailbreak detection
// - Emulator detection
// - Debug mode detection
// - Device fingerprinting
// ════════════════════════════════════════════════

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../../logging/app_logger.dart';

/// Device integrity assessment.
///
/// Checks whether the device is trustworthy
/// before performing sensitive operations.
///
/// ```dart
/// final integrity = DeviceIntegrity();
/// final result = await integrity.assess();
/// if (result.isTrusted) {
///   // Proceed with sensitive operation.
/// }
/// ```
class DeviceIntegrity {
  DeviceIntegrity({
    DeviceInfoPlugin? deviceInfo,
    AppLogger? logger,
  })  : _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
        _logger = logger ?? AppLogger.instance;

  final DeviceInfoPlugin _deviceInfo;
  final AppLogger _logger;

  /// Perform a full integrity assessment.
  Future<IntegrityResult> assess() async {
    final checks = <IntegrityCheck>[];

    checks.add(await _checkRoot());
    checks.add(await _checkEmulator());
    checks.add(_checkDebugMode());

    final isTrusted = checks.every((c) => c.status == IntegrityStatus.pass);
    final warnings = checks.where((c) => c.status == IntegrityStatus.warning).toList();
    final failures = checks.where((c) => c.status == IntegrityStatus.fail).toList();

    return IntegrityResult(
      isTrusted: isTrusted,
      checks: checks,
      warnings: warnings.length,
      failures: failures.length,
    );
  }

  /// Get device fingerprint for analytics.
  Future<String> getDeviceFingerprint() async {
    try {
      final android = await _deviceInfo.androidInfo;
      final raw = '${android.model}:${android.brand}:${android.id}';
      return EncryptionService.sha256Hash(raw);
    } catch (e) {
      return 'unknown';
    }
  }

  Future<IntegrityCheck> _checkRoot() async {
    // Check for common root indicators.
    final rootPaths = [
      '/system/app/Superuser.apk',
      '/system/xbin/su',
      '/system/bin/su',
      '/sbin/su',
    ];

    for (final path in rootPaths) {
      if (await File(path).exists()) {
        return const IntegrityCheck(
          name: 'Root Detection',
          status: IntegrityStatus.fail,
          message: 'Device appears to be rooted',
        );
      }
    }

    return const IntegrityCheck(
      name: 'Root Detection',
      status: IntegrityStatus.pass,
    );
  }

  Future<IntegrityCheck> _checkEmulator() async {
    try {
      final android = await _deviceInfo.androidInfo;

      final isEmulator = android.isPhysicalDevice == false ||
          android.model.toLowerCase().contains('sdk') ||
          android.model.toLowerCase().contains('emulator') ||
          android.product.toLowerCase().contains('sdk');

      return IntegrityCheck(
        name: 'Emulator Detection',
        status: isEmulator ? IntegrityStatus.warning : IntegrityStatus.pass,
        message: isEmulator ? 'Running on emulator' : null,
      );
    } catch (e) {
      return const IntegrityCheck(
        name: 'Emulator Detection',
        status: IntegrityStatus.pass,
      );
    }
  }

  IntegrityCheck _checkDebugMode() {
    const isDebug = bool.fromEnvironment('dart.vm.product') == false;

    return IntegrityCheck(
      name: 'Debug Mode',
      status: isDebug ? IntegrityStatus.warning : IntegrityStatus.pass,
      message: isDebug ? 'Running in debug mode' : null,
    );
  }
}

/// Result of a device integrity assessment.
class IntegrityResult {
  const IntegrityResult({
    required this.isTrusted,
    required this.checks,
    required this.warnings,
    required this.failures,
  });

  /// Whether the device passed all integrity checks.
  final bool isTrusted;

  /// All individual checks performed.
  final List<IntegrityCheck> checks;

  /// Number of warning-level issues.
  final int warnings;

  /// Number of failure-level issues.
  final int failures;
}

/// A single integrity check result.
class IntegrityCheck {
  const IntegrityCheck({
    required this.name,
    required this.status,
    this.message,
  });

  final String name;
  final IntegrityStatus status;
  final String? message;
}

/// Status of an integrity check.
enum IntegrityStatus {
  /// Check passed — device is trustworthy.
  pass,

  /// Non-critical issue detected.
  warning,

  /// Critical issue — device is not trustworthy.
  fail,
}

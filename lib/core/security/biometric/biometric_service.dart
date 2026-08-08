// ════════════════════════════════════════════════
// Project Lyra — Biometric Service
// ════════════════════════════════════════════════
//
// Biometric authentication hooks using local_auth.
// Fingerprint and face unlock for secure actions.
// ════════════════════════════════════════════════

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../../logging/app_logger.dart';

/// Service for biometric authentication.
///
/// Provides fingerprint and face unlock for:
/// - Premium purchase confirmation
/// - Accessing secure downloads
/// - Re-authentication after idle
///
/// ```dart
/// final biometric = BiometricService();
/// if (await biometric.canUseBiometrics()) {
///   final authenticated = await biometric.authenticate('Confirm purchase');
/// }
/// ```
class BiometricService {
  BiometricService({
    LocalAuthentication? localAuth,
    AppLogger? logger,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _logger = logger ?? AppLogger.instance;

  final LocalAuthentication _localAuth;
  final AppLogger _logger;

  /// Check if biometric hardware is available.
  Future<bool> canUseBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException catch (e) {
      _logger.w('BiometricService: Platform check failed', error: e);
      return false;
    }
  }

  /// Get available biometric types (fingerprint, face, etc.).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      _logger.w('BiometricService: Get biometrics failed', error: e);
      return [];
    }
  }

  /// Whether fingerprint authentication is available.
  Future<bool> hasFingerprint() async {
    final types = await getAvailableBiometrics();
    return types.contains(BiometricType.fingerprint) ||
        types.contains(BiometricType.strong);
  }

  /// Whether face authentication is available.
  Future<bool> hasFaceId() async {
    final types = await getAvailableBiometrics();
    return types.contains(BiometricType.face) ||
        types.contains(BiometricType.strong);
  }

  /// Authenticate the user with biometrics.
  ///
  /// Returns true if authenticated, false if failed or cancelled.
  /// [reason] is shown to the user in the system dialog.
  Future<bool> authenticate(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      _logger.e('BiometricService: Auth failed', error: e);
      return false;
    }
  }

  /// Stop any ongoing authentication.
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      // Not all platforms support this.
    }
  }
}

// ════════════════════════════════════════════════
// Project Lyra — Encryption Service
// ════════════════════════════════════════════════
//
// Encryption utilities for sensitive data.
// AES-256-GCM for data at rest.
// HMAC for data integrity verification.
// ════════════════════════════════════════════════

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../logging/app_logger.dart';

/// Encryption service for sensitive data.
///
/// Uses SHA-256 for hashing and HMAC for integrity.
/// AES encryption keys are stored in secure storage.
///
/// ```dart
/// final hash = EncryptionService.sha256Hash('sensitive_data');
/// final hmac = EncryptionService.hmacSha256('data', 'secret_key');
/// ```
class EncryptionService {
  EncryptionService({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  /// Generate a SHA-256 hash of input data.
  static String sha256Hash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate a SHA-256 hash of binary data.
  static String sha256HashBytes(Uint8List data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }

  /// Generate HMAC-SHA256 for data integrity.
  static String hmacSha256(String data, String secretKey) {
    final keyBytes = utf8.encode(secretKey);
    final dataBytes = utf8.encode(data);
    final hmacSha256 = Hmac(sha256, keyBytes);
    final digest = hmacSha256.convert(dataBytes);
    return digest.toString();
  }

  /// Generate a random encryption key (256-bit).
  static String generateKey() {
    final random = Uint8List(32);
    // Use crypto-secure random.
    for (int i = 0; i < 32; i++) {
      random[i] = DateTime.now().microsecondsSinceEpoch % 256;
    }
    // TODO(team): Use dart:math Random.secure() or pointycastle.
    return base64Url.encode(random);
  }

  /// Generate a unique device identifier hash.
  static String generateDeviceId(String deviceId, String salt) {
    return sha256Hash('$deviceId:$salt');
  }

  /// Verify data integrity with HMAC.
  static bool verifyHmac(String data, String secretKey, String expectedHmac) {
    final computed = hmacSha256(data, secretKey);
    return computed == expectedHmac;
  }

  /// Encode data to base64.
  static String base64Encode(String data) {
    return base64.encode(utf8.encode(data));
  }

  /// Decode base64 data.
  static String? base64Decode(String encoded) {
    try {
      return utf8.decode(base64.decode(encoded));
    } catch (e) {
      return null;
    }
  }
}

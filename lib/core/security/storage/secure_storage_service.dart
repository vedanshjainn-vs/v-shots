// ════════════════════════════════════════════════
// Project Lyra — Secure Storage Service
// ════════════════════════════════════════════════
//
// Abstraction over flutter_secure_storage.
// Encrypts tokens, credentials, and sensitive data.
// Platform-keychain backed on Android.
// ════════════════════════════════════════════════

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../logging/app_logger.dart';

/// Service for securely storing sensitive data.
///
/// Uses Android Keystore (encrypted SharedPreferences)
/// for hardware-backed encryption.
///
/// **Never store tokens in SharedPreferences or Hive.**
///
/// ```dart
/// final secure = SecureStorageService();
/// await secure.writeToken('access_token', 'eyJ...');
/// final token = await secure.readToken('access_token');
/// ```
class SecureStorageService {
  SecureStorageService({
    FlutterSecureStorage? storage,
    AppLogger? logger,
  })  : _storage = storage ?? _createDefaultStorage(),
        _logger = logger ?? AppLogger.instance;

  final FlutterSecureStorage _storage;
  final AppLogger _logger;

  /// Creates the default secure storage configuration.
  static FlutterSecureStorage _createDefaultStorage() {
    return const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        // Use Android Keystore for encryption.
        keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
        storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
      ),
    );
  }

  // ── Read Operations ──────────────────────────

  /// Read a value by key. Returns null if not found.
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e, st) {
      _logger.e('SecureStorage.read failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Read an access token.
  Future<String?> readToken(String key) => read(key);

  /// Read a boolean value.
  Future<bool?> readBool(String key) async {
    final value = await read(key);
    if (value == null) return null;
    return value == 'true';
  }

  /// Read an integer value.
  Future<int?> readInt(String key) async {
    final value = await read(key);
    if (value == null) return null;
    return int.tryParse(value);
  }

  /// Read all stored key-value pairs.
  Future<Map<String, String>> readAll() async {
    try {
      return await _storage.readAll();
    } catch (e, st) {
      _logger.e('SecureStorage.readAll failed', error: e, stackTrace: st);
      return {};
    }
  }

  /// Check if a key exists.
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e, st) {
      _logger.e('SecureStorage.containsKey failed', error: e, stackTrace: st);
      return false;
    }
  }

  // ── Write Operations ─────────────────────────

  /// Write a value securely.
  Future<bool> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return true;
    } catch (e, st) {
      _logger.e('SecureStorage.write failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Write a token.
  Future<bool> writeToken(String key, String token) => write(key, token);

  /// Write a boolean value.
  Future<bool> writeBool(String key, bool value) => write(key, value.toString());

  /// Write an integer value.
  Future<bool> writeInt(String key, int value) => write(key, value.toString());

  // ── Delete Operations ────────────────────────

  /// Delete a specific key.
  Future<bool> delete(String key) async {
    try {
      await _storage.delete(key: key);
      return true;
    } catch (e, st) {
      _logger.e('SecureStorage.delete failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Delete all stored data. Use on logout.
  Future<bool> deleteAll() async {
    try {
      await _storage.deleteAll();
      return true;
    } catch (e, st) {
      _logger.e('SecureStorage.deleteAll failed', error: e, stackTrace: st);
      return false;
    }
  }
}

/// Well-known secure storage keys.
abstract final class SecureStorageKeys {
  static const String accessToken = 'lyra_access_token';
  static const String refreshToken = 'lyra_refresh_token';
  static const String tokenExpiry = 'lyra_token_expiry';
  static const String userId = 'lyra_user_id';
  static const String sessionId = 'lyra_session_id';
  static const String deviceId = 'lyra_device_id';
  static const String supabaseAccessToken = 'lyra_supabase_access_token';
  static const String supabaseRefreshToken = 'lyra_supabase_refresh_token';
  static const String encryptionKey = 'lyra_encryption_key';
  static const String biometricEnabled = 'lyra_biometric_enabled';
}

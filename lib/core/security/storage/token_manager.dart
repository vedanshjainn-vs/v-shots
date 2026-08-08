// ════════════════════════════════════════════════
// Project Lyra — Token Manager
// ════════════════════════════════════════════════
//
// Manages auth tokens lifecycle:
// - Secure storage (never in plain text)
// - Automatic expiry detection
// - Refresh coordination
// - Token pair management (access + refresh)
// ════════════════════════════════════════════════

import 'dart:convert';

import '../../logging/app_logger.dart';
import 'secure_storage_service.dart';

/// Manages authentication tokens securely.
///
/// Tokens are always stored in [SecureStorageService]
/// (Android Keystore), never in SharedPreferences.
///
/// ```dart
/// final tokenManager = TokenManager(secureStorage: secureStorage);
/// await tokenManager.saveTokens(accessToken: '...', refreshToken: '...');
/// final token = await tokenManager.getAccessToken();
/// ```
class TokenManager {
  TokenManager({
    required SecureStorageService secureStorage,
    AppLogger? logger,
  })  : _secureStorage = secureStorage,
        _logger = logger ?? AppLogger.instance;

  final SecureStorageService _secureStorage;
  final AppLogger _logger;

  // ── Token Storage ────────────────────────────

  /// Save a token pair (access + refresh).
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    DateTime? accessTokenExpiry,
  }) async {
    await Future.wait([
      _secureStorage.writeToken(SecureStorageKeys.accessToken, accessToken),
      _secureStorage.writeToken(SecureStorageKeys.refreshToken, refreshToken),
      if (accessTokenExpiry != null)
        _secureStorage.write(
          SecureStorageKeys.tokenExpiry,
          accessTokenExpiry.toIso8601String(),
        ),
    ]);

    _logger.d('TokenManager: Tokens saved securely');
  }

  /// Get the access token.
  Future<String?> getAccessToken() async {
    return _secureStorage.readToken(SecureStorageKeys.accessToken);
  }

  /// Get the refresh token.
  Future<String?> getRefreshToken() async {
    return _secureStorage.readToken(SecureStorageKeys.refreshToken);
  }

  /// Get the access token expiry.
  Future<DateTime?> getAccessTokenExpiry() async {
    final expiryStr = await _secureStorage.read(SecureStorageKeys.tokenExpiry);
    if (expiryStr == null) return null;
    return DateTime.tryParse(expiryStr);
  }

  // ── Token State ──────────────────────────────

  /// Whether any tokens exist.
  Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Whether the access token has expired.
  ///
  /// Returns true if expired or within [bufferMinutes] of expiry.
  Future<bool> isAccessTokenExpired({int bufferMinutes = 5}) async {
    final expiry = await getAccessTokenExpiry();
    if (expiry == null) return true;

    final bufferedExpiry = expiry.subtract(Duration(minutes: bufferMinutes));
    return DateTime.now().isAfter(bufferedExpiry);
  }

  /// Whether the token needs refresh.
  Future<bool> needsRefresh() async {
    return isAccessTokenExpired(bufferMinutes: 5);
  }

  // ── Token Extraction ─────────────────────────

  /// Extract the user ID from the JWT payload.
  Future<String?> extractUserId() async {
    final token = await getAccessToken();
    if (token == null) return null;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      // Pad base64 string.
      final padded = payload + '=' * (4 - payload.length % 4);
      final decoded = utf8.decode(base64Url.decode(padded));
      final map = jsonDecode(decoded) as Map<String, dynamic>;

      return (map['sub'] ?? map['user_id']) as String?;
    } catch (e) {
      _logger.w('TokenManager: Failed to extract user ID from JWT');
      return null;
    }
  }

  /// Extract token expiry from JWT claims.
  Future<DateTime?> extractExpiry() async {
    final token = await getAccessToken();
    if (token == null) return null;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final padded = payload + '=' * (4 - payload.length % 4);
      final decoded = utf8.decode(base64Url.decode(padded));
      final map = jsonDecode(decoded) as Map<String, dynamic>;

      final exp = map['exp'] as int?;
      if (exp == null) return null;

      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (e) {
      _logger.w('TokenManager: Failed to extract expiry from JWT');
      return null;
    }
  }

  // ── Token Cleanup ────────────────────────────

  /// Clear all tokens. Use on logout.
  Future<void> clearTokens() async {
    await Future.wait([
      _secureStorage.delete(SecureStorageKeys.accessToken),
      _secureStorage.delete(SecureStorageKeys.refreshToken),
      _secureStorage.delete(SecureStorageKeys.tokenExpiry),
    ]);

    _logger.d('TokenManager: Tokens cleared');
  }
}

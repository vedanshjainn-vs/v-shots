// ════════════════════════════════════════════════
// Project Lyra — Auth Local Data Source
// ════════════════════════════════════════════════

import '../../../../../core/logging/app_logger.dart';
import '../../../../../core/security/storage/secure_storage_service.dart';
import '../../../../../core/security/storage/token_manager.dart';
import '../../models/auth_models.dart';

/// Local data source for authentication.
///
/// Stores tokens in secure storage (Android Keystore).
/// Never stores tokens in SharedPreferences.
abstract class AuthLocalDataSource {
  Future<void> saveSession(SessionModel session);
  Future<SessionModel?> getSession();
  Future<void> clearSession();
  Future<void> saveUser(UserModel user);
  Future<UserModel?> getUser();
  Future<void> clearUser();
  Future<bool> hasSession();
}

/// Secure storage implementation of [AuthLocalDataSource].
class SecureStorageAuthLocalDataSource implements AuthLocalDataSource {
  SecureStorageAuthLocalDataSource({
    required this.secureStorage,
    required this.tokenManager,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final SecureStorageService secureStorage;
  final TokenManager tokenManager;
  final AppLogger _logger;

  static const String _sessionKey = 'auth_session';
  static const String _userKey = 'auth_user';

  @override
  Future<void> saveSession(SessionModel session) async {
    try {
      await tokenManager.saveTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        accessTokenExpiry: DateTime.tryParse(session.expiresAt),
      );
      await secureStorage.write(_sessionKey, session.toJson().toString());
      _logger.d('AuthLocal: Session saved');
    } catch (e, st) {
      _logger.e('AuthLocal: saveSession failed', error: e, stackTrace: st);
    }
  }

  @override
  Future<SessionModel?> getSession() async {
    try {
      final accessToken = await tokenManager.getAccessToken();
      final refreshToken = await tokenManager.getRefreshToken();
      final expiry = await tokenManager.getAccessTokenExpiry();
      final userId = await tokenManager.extractUserId();

      if (accessToken == null || refreshToken == null) return null;

      return SessionModel(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: (expiry ?? DateTime.now()).toIso8601String(),
        userId: userId ?? '',
      );
    } catch (e, st) {
      _logger.e('AuthLocal: getSession failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<void> clearSession() async {
    await tokenManager.clearTokens();
    await secureStorage.delete(_sessionKey);
    _logger.d('AuthLocal: Session cleared');
  }

  @override
  Future<void> saveUser(UserModel user) async {
    // Store user in secure storage (not SharedPreferences).
    await secureStorage.write(_userKey, user.toJson().toString());
  }

  @override
  Future<UserModel?> getUser() async {
    // TODO(team): Deserialize from secure storage.
    return null;
  }

  @override
  Future<void> clearUser() async {
    await secureStorage.delete(_userKey);
  }

  @override
  Future<bool> hasSession() async {
    return tokenManager.hasTokens();
  }
}

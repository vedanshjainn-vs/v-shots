// ════════════════════════════════════════════════
// V Shots — Auth Remote Data Source
// ════════════════════════════════════════════════

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/logging/app_logger.dart';
import '../../../../../core/supabase/supabase_client.dart';
import '../../models/auth_models.dart';

/// Remote data source for authentication.
abstract class AuthRemoteDataSource {
  Future<UserModel> loginWithEmail({required String email, required String password});
  Future<UserModel> registerWithEmail({required String email, required String password, String? displayName});
  Future<UserModel> loginWithGoogle();
  Future<UserModel> loginWithApple();
  Future<UserModel> loginWithPhone({required String phoneNumber, required String verificationCode});
  Future<void> sendPhoneVerification(String phoneNumber);
  Future<UserModel> loginAnonymously();
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
  Future<SessionModel> refreshToken(String refreshToken);
  Future<UserModel> updateProfile({String? displayName, String? avatarUrl, String? phoneNumber});
  Future<void> sendPasswordReset(String email);
  Future<void> deleteAccount();
  Stream<UserModel?> get authStateChanges;
}

/// Supabase implementation of [AuthRemoteDataSource].
class SupabaseAuthRemoteDataSource implements AuthRemoteDataSource {
  SupabaseAuthRemoteDataSource({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;
  final _supabase = LyraSupabase.instance;

  @override
  Future<UserModel> loginWithEmail({required String email, required String password}) async {
    try {
      final response = await _supabase.signInWithEmail(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Login failed');
      }

      return _mapUser(response.user!);
    } catch (e, st) {
      _logger.e('AuthRemote: loginWithEmail failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _supabase.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );

      if (response.user == null) {
        throw Exception('Registration failed');
      }

      return _mapUser(response.user!);
    } catch (e, st) {
      _logger.e('AuthRemote: registerWithEmail failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<UserModel> loginWithGoogle() async {
    try {
      await _supabase.signInWithGoogle();

      // Wait for auth state change
      await Future.delayed(const Duration(seconds: 2));

      final user = _supabase.client.auth.currentUser;
      if (user == null) {
        throw Exception('Google login failed');
      }

      return _mapUser(user);
    } catch (e, st) {
      _logger.e('AuthRemote: loginWithGoogle failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<UserModel> loginWithApple() async {
    // TODO: Implement Apple Sign-In
    throw UnimplementedError('Apple Sign-In not implemented yet');
  }

  @override
  Future<UserModel> loginWithPhone({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    // TODO: Implement Phone Sign-In
    throw UnimplementedError('Phone Sign-In not implemented yet');
  }

  @override
  Future<void> sendPhoneVerification(String phoneNumber) async {
    // TODO: Implement Phone Verification
    throw UnimplementedError('Phone Verification not implemented yet');
  }

  @override
  Future<UserModel> loginAnonymously() async {
    try {
      final response = await _supabase.client.auth.signInAnonymously();

      if (response.user == null) {
        throw Exception('Anonymous login failed');
      }

      return _mapUser(response.user!);
    } catch (e, st) {
      _logger.e('AuthRemote: loginAnonymously failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _supabase.signOut();
    } catch (e, st) {
      _logger.e('AuthRemote: logout failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) return null;
      return _mapUser(user);
    } catch (e, st) {
      _logger.e('AuthRemote: getCurrentUser failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<SessionModel> refreshToken(String refreshToken) async {
    try {
      final response = await _supabase.client.auth.refreshSession();

      if (response.session == null) {
        throw Exception('Token refresh failed');
      }

      return SessionModel(
        accessToken: response.session!.accessToken,
        refreshToken: response.session!.refreshToken ?? '',
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          response.session!.expiresAt! * 1000,
        ).toIso8601String(),
        userId: response.session!.user.id,
      );
    } catch (e, st) {
      _logger.e('AuthRemote: refreshToken failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<UserModel> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? phoneNumber,
  }) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final updates = <String, dynamic>{};
      if (displayName != null) updates['display_name'] = displayName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      if (updates.isNotEmpty) {
        await _supabase.client.auth.updateUser(
          UserAttributes(data: updates),
        );
      }

      // Update profile in database
      await _supabase.update(
        table: 'profiles',
        data: {
          if (displayName != null) 'display_name': displayName,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        },
        id: user.id,
      );

      return (await getCurrentUser())!;
    } catch (e, st) {
      _logger.e('AuthRemote: updateProfile failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _supabase.resetPassword(email);
    } catch (e, st) {
      _logger.e('AuthRemote: sendPasswordReset failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> deleteAccount() async {
    // TODO: Implement account deletion
    throw UnimplementedError('Account deletion not implemented yet');
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return _supabase.client.auth.onAuthStateChange.map((data) {
      if (data.session?.user == null) return null;
      return _mapUser(data.session!.user);
    });
  }

  UserModel _mapUser(User user) {
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String? ??
          user.email?.split('@').first,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      isEmailVerified: user.emailConfirmedAt != null,
      isAnonymous: user.isAnonymous,
      createdAt: user.createdAt,
    );
  }
}

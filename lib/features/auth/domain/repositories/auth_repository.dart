// ════════════════════════════════════════════════
// Project Lyra — Auth Repository Interface
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/auth_entities.dart';

/// Abstract auth repository — domain layer contract.
///
/// Implemented by [AuthRepositoryImpl] in the data layer.
abstract class AuthRepository {
  /// Login with email and password.
  Future<Result<LyraUser>> loginWithEmail({
    required String email,
    required String password,
  });

  /// Register with email and password.
  Future<Result<LyraUser>> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  /// Login with Google.
  Future<Result<LyraUser>> loginWithGoogle();

  /// Login with Apple.
  Future<Result<LyraUser>> loginWithApple();

  /// Login with phone number.
  Future<Result<LyraUser>> loginWithPhone({
    required String phoneNumber,
    required String verificationCode,
  });

  /// Send phone verification code.
  Future<Result<void>> sendPhoneVerification(String phoneNumber);

  /// Anonymous login (guest mode).
  Future<Result<LyraUser>> loginAnonymously();

  /// Logout current user.
  Future<Result<void>> logout();

  /// Get the currently authenticated user.
  Future<Result<LyraUser?>> getCurrentUser();

  /// Restore session from stored tokens.
  Future<Result<LyraUser?>> restoreSession();

  /// Refresh the authentication token.
  Future<Result<AuthToken>> refreshToken();

  /// Update user profile.
  Future<Result<LyraUser>> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? phoneNumber,
  });

  /// Send password reset email.
  Future<Result<void>> sendPasswordReset(String email);

  /// Delete the current user's account.
  Future<Result<void>> deleteAccount();

  /// Stream of auth state changes.
  Stream<LyraUser?> get authStateChanges;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated;

  /// Current user (cached).
  LyraUser? get currentUser;
}

/// Type alias for Result.
typedef Result<T> = Either<Failure, T>;

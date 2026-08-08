// ════════════════════════════════════════════════
// Project Lyra — Auth Use Cases
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/auth_entities.dart';
import '../repositories/auth_repository.dart';

/// Login with email and password.
class LoginWithEmail implements UseCase<LyraUser, LoginParams> {
  const LoginWithEmail(this.repository);
  final AuthRepository repository;

  @override
  Future<Either<Failure, LyraUser>> call(LoginParams params) {
    return repository.loginWithEmail(email: params.email, password: params.password);
  }
}

class LoginParams extends Equatable {
  const LoginParams({required this.email, required this.password});
  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// Register with email and password.
class RegisterWithEmail implements UseCase<LyraUser, RegisterParams> {
  const RegisterWithEmail(this.repository);
  final AuthRepository repository;

  @override
  Future<Either<Failure, LyraUser>> call(RegisterParams params) {
    return repository.registerWithEmail(
      email: params.email,
      password: params.password,
      displayName: params.displayName,
    );
  }
}

class RegisterParams extends Equatable {
  const RegisterParams({required this.email, required this.password, this.displayName});
  final String email;
  final String password;
  final String? displayName;

  @override
  List<Object?> get props => [email, password, displayName];
}

/// Login with Google.
class LoginWithGoogle implements UseCase<LyraUser, NoParams> {
  const LoginWithGoogle(this.repository);
  final AuthRepository repository;

  @override
  Future<Either<Failure, LyraUser>> call(NoParams params) {
    return repository.loginWithGoogle();
  }
}

/// Login with Apple.
class LoginWithApple implements UseCase<LyraUser, NoParams> {
  const LoginWithApple(this.repository);
  final AuthRepository repository;

  @override
  Future<Either<Failure, LyraUser>> call(NoParams params) {
    return repository.loginWithApple();
  }
}

/// Login anonymously.
class LoginAnonymously implements UseCase<LyraUser, NoParams> {
  const LoginAnonymously(this.repository);
  final AuthRepository repository;

  @override
  Future<Either<Failure, LyraUser>> call(NoParams params) {
    return repository.loginAnonymously();
  }
}

/// Logout.
class Logout implements UseCaseVoid<NoParams> {
  const Logout(this.repository);
  final AuthRepository repository;

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return repository.logout();
  }
}

/// Get current user.
class GetCurrentUser implements UseCase<LyraUser?, NoParams> {
  const GetCurrentUser(this.repository);
  final AuthRepository repository;

  @override
  Future<Either<Failure, LyraUser?>> call(NoParams params) {
    return repository.getCurrentUser();
  }
}

/// Restore session.
class RestoreSession implements UseCase<LyraUser?, NoParams> {
  const RestoreSession(this.repository);
  final AuthRepository repository;

  @override
  Future<Either<Failure, LyraUser?>> call(NoParams params) {
    return repository.restoreSession();
  }
}

/// Refresh token.
class RefreshToken implements UseCase<AuthToken, NoParams> {
  const RefreshToken(this.repository);
  final AuthRepository repository;

  @override
  Future<Either<Failure, AuthToken>> call(NoParams params) {
    return repository.refreshToken();
  }
}

/// Update profile.
class UpdateProfile implements UseCase<LyraUser, UpdateProfileParams> {
  const UpdateProfile(this.repository);
  final AuthRepository repository;

  @override
  Future<Either<Failure, LyraUser>> call(UpdateProfileParams params) {
    return repository.updateProfile(
      displayName: params.displayName,
      avatarUrl: params.avatarUrl,
      phoneNumber: params.phoneNumber,
    );
  }
}

class UpdateProfileParams extends Equatable {
  const UpdateProfileParams({this.displayName, this.avatarUrl, this.phoneNumber});
  final String? displayName;
  final String? avatarUrl;
  final String? phoneNumber;

  @override
  List<Object?> get props => [displayName, avatarUrl, phoneNumber];
}

/// Delete account.
class DeleteAccount implements UseCaseVoid<NoParams> {
  const DeleteAccount(this.repository);
  final AuthRepository repository;

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return repository.deleteAccount();
  }
}

/// Send password reset.
class SendPasswordReset implements UseCaseVoid<String> {
  const SendPasswordReset(this.repository);
  final AuthRepository repository;

  @override
  Future<Either<Failure, void>> call(String email) {
    return repository.sendPasswordReset(email);
  }
}

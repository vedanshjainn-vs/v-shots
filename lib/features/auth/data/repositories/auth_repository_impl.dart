// ════════════════════════════════════════════════
// Project Lyra — Auth Repository Implementation
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/mapper/failure_mapper.dart';
import '../../../../core/events/bus/app_event_bus.dart';
import '../../../../core/events/types/app_event.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/auth_entities.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local/auth_local_datasource.dart';
import '../datasources/remote/auth_remote_datasource.dart';

/// Concrete implementation of [AuthRepository].
///
/// Coordinates between remote (Supabase) and local (secure storage)
/// data sources. Handles caching, error mapping, and events.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.eventBus,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final AppEventBus eventBus;
  final AppLogger _logger;

  LyraUser? _cachedUser;

  @override
  LyraUser? get currentUser => _cachedUser;

  @override
  bool get isAuthenticated => _cachedUser != null;

  @override
  Stream<LyraUser?> get authStateChanges => remoteDataSource.authStateChanges
      .map((model) => model?.toEntity());

  @override
  Future<Either<Failure, LyraUser>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userModel = await remoteDataSource.loginWithEmail(
        email: email,
        password: password,
      );
      final user = userModel.toEntity();
      _cachedUser = user;
      eventBus.emit(UserSignedInEvent(userId: user.id, method: 'email'));
      return Right(user);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, LyraUser>> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final userModel = await remoteDataSource.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      final user = userModel.toEntity();
      _cachedUser = user;
      eventBus.emit(UserSignedInEvent(userId: user.id, method: 'email'));
      return Right(user);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, LyraUser>> loginWithGoogle() async {
    try {
      final userModel = await remoteDataSource.loginWithGoogle();
      final user = userModel.toEntity();
      _cachedUser = user;
      eventBus.emit(UserSignedInEvent(userId: user.id, method: 'google'));
      return Right(user);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, LyraUser>> loginWithApple() async {
    try {
      final userModel = await remoteDataSource.loginWithApple();
      final user = userModel.toEntity();
      _cachedUser = user;
      eventBus.emit(UserSignedInEvent(userId: user.id, method: 'apple'));
      return Right(user);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, LyraUser>> loginWithPhone({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    try {
      final userModel = await remoteDataSource.loginWithPhone(
        phoneNumber: phoneNumber,
        verificationCode: verificationCode,
      );
      final user = userModel.toEntity();
      _cachedUser = user;
      eventBus.emit(UserSignedInEvent(userId: user.id, method: 'phone'));
      return Right(user);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> sendPhoneVerification(String phoneNumber) async {
    try {
      await remoteDataSource.sendPhoneVerification(phoneNumber);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, LyraUser>> loginAnonymously() async {
    try {
      final userModel = await remoteDataSource.loginAnonymously();
      final user = userModel.toEntity();
      _cachedUser = user;
      eventBus.emit(UserSignedInEvent(userId: user.id, method: 'anonymous'));
      return Right(user);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await remoteDataSource.logout();
      await localDataSource.clearSession();
      await localDataSource.clearUser();
      _cachedUser = null;
      eventBus.emit(const UserSignedOutEvent());
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, LyraUser?>> getCurrentUser() async {
    try {
      if (_cachedUser != null) return Right(_cachedUser);

      final userModel = await remoteDataSource.getCurrentUser();
      if (userModel != null) {
        _cachedUser = userModel.toEntity();
      }
      return Right(_cachedUser);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, LyraUser?>> restoreSession() async {
    try {
      final hasSession = await localDataSource.hasSession();
      if (!hasSession) return const Right(null);

      final userModel = await remoteDataSource.getCurrentUser();
      if (userModel != null) {
        _cachedUser = userModel.toEntity();
      }
      return Right(_cachedUser);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, AuthToken>> refreshToken() async {
    try {
      final session = await localDataSource.getSession();
      if (session == null) return const Left(UnauthorizedFailure());

      final sessionModel = await remoteDataSource.refreshToken(session.refreshToken);
      await localDataSource.saveSession(sessionModel);

      return Right(AuthToken(
        accessToken: sessionModel.accessToken,
        refreshToken: sessionModel.refreshToken,
        expiresAt: DateTime.parse(sessionModel.expiresAt),
      ));
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, LyraUser>> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? phoneNumber,
  }) async {
    try {
      final userModel = await remoteDataSource.updateProfile(
        displayName: displayName,
        avatarUrl: avatarUrl,
        phoneNumber: phoneNumber,
      );
      final user = userModel.toEntity();
      _cachedUser = user;
      return Right(user);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordReset(String email) async {
    try {
      await remoteDataSource.sendPasswordReset(email);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    try {
      await remoteDataSource.deleteAccount();
      await localDataSource.clearSession();
      await localDataSource.clearUser();
      _cachedUser = null;
      eventBus.emit(const UserSignedOutEvent(reason: 'account_deleted'));
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }
}

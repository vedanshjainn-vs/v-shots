// ════════════════════════════════════════════════
// Project Lyra — Profile Repository Implementation
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';

import '../../../../core/cache/cache_key.dart';
import '../../../../core/cache/cache_manager.dart';
import '../../../../core/cache/policies/cache_policy.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/mapper/failure_mapper.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/profile_entities.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/remote/profile_remote_datasource.dart';
import '../models/profile_models.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.cacheManager,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final ProfileRemoteDataSource remoteDataSource;
  final CacheManager cacheManager;
  final AppLogger _logger;

  @override
  Future<Either<Failure, UserProfile>> getProfile(String userId) async {
    try {
      // Check cache first.
      final key = CacheKey(namespace: 'profiles', id: userId);
      final cached = cacheManager.getRaw(key);
      if (cached != null) {
        _logger.d('ProfileRepo: Cache hit for $userId');
        // TODO(team): Deserialize from cache.
      }

      final profile = await remoteDataSource.getProfile(userId);

      // Cache the result.
      await cacheManager.put<UserProfileModel>(
        key: key,
        data: profile,
        toJson: (data) => data.toJson(),
        ttl: CachePolicy.userSpecific.maxAge,
      );

      return Right(profile.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> getCurrentProfile() async {
    try {
      final profile = await remoteDataSource.getCurrentProfile();
      return Right(profile.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? location,
    bool? isPublic,
  }) async {
    try {
      final profile = await remoteDataSource.updateProfile(
        displayName: displayName,
        avatarUrl: avatarUrl,
        bio: bio,
        location: location,
        isPublic: isPublic,
      );

      // Invalidate cache.
      await cacheManager.invalidate(CacheKey(namespace: 'profiles', id: profile.id));

      return Right(profile.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> uploadAvatar(String filePath) async {
    try {
      // TODO(team): Implement avatar upload.
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAvatar() async {
    try {
      await remoteDataSource.deleteAvatar();
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> followUser(String userId) async {
    try {
      final profile = await remoteDataSource.followUser(userId);
      return Right(profile.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> unfollowUser(String userId) async {
    try {
      final profile = await remoteDataSource.unfollowUser(userId);
      return Right(profile.toEntity());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st));
    }
  }

  @override
  Future<bool> isFollowing(String userId) async {
    return remoteDataSource.isFollowing(userId);
  }
}

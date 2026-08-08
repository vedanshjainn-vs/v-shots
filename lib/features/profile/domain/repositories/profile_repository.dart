// ════════════════════════════════════════════════
// Project Lyra — Profile Repository Interface
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/profile_entities.dart';

typedef Result<T> = Either<Failure, T>;

abstract class ProfileRepository {
  Future<Result<UserProfile>> getProfile(String userId);
  Future<Result<UserProfile>> getCurrentProfile();
  Future<Result<UserProfile>> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? location,
    bool? isPublic,
  });
  Future<Result<void>> uploadAvatar(String filePath);
  Future<Result<void>> deleteAvatar();
  Future<Result<UserProfile>> followUser(String userId);
  Future<Result<UserProfile>> unfollowUser(String userId);
  Future<bool> isFollowing(String userId);
}

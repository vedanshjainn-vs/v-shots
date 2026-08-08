// ════════════════════════════════════════════════
// Project Lyra — Profile Use Cases
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/profile_entities.dart';
import '../repositories/profile_repository.dart';

class GetProfile implements UseCase<UserProfile, String> {
  const GetProfile(this.repository);
  final ProfileRepository repository;
  @override
  Future<Either<Failure, UserProfile>> call(String userId) => repository.getProfile(userId);
}

class GetCurrentProfile implements UseCase<UserProfile, NoParams> {
  const GetCurrentProfile(this.repository);
  final ProfileRepository repository;
  @override
  Future<Either<Failure, UserProfile>> call(NoParams params) => repository.getCurrentProfile();
}

class UpdateProfile implements UseCase<UserProfile, UpdateProfileParams> {
  const UpdateProfile(this.repository);
  final ProfileRepository repository;
  @override
  Future<Either<Failure, UserProfile>> call(UpdateProfileParams params) =>
      repository.updateProfile(
        displayName: params.displayName,
        avatarUrl: params.avatarUrl,
        bio: params.bio,
        location: params.location,
        isPublic: params.isPublic,
      );
}

class UpdateProfileParams extends Equatable {
  const UpdateProfileParams({this.displayName, this.avatarUrl, this.bio, this.location, this.isPublic});
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final bool? isPublic;
  @override
  List<Object?> get props => [displayName, avatarUrl, bio, location, isPublic];
}

class FollowUser implements UseCase<UserProfile, String> {
  const FollowUser(this.repository);
  final ProfileRepository repository;
  @override
  Future<Either<Failure, UserProfile>> call(String userId) => repository.followUser(userId);
}

class UnfollowUser implements UseCase<UserProfile, String> {
  const UnfollowUser(this.repository);
  final ProfileRepository repository;
  @override
  Future<Either<Failure, UserProfile>> call(String userId) => repository.unfollowUser(userId);
}

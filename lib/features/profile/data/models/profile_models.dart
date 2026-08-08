// ════════════════════════════════════════════════
// Project Lyra — Profile Data Models
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/profile_entities.dart';

part 'profile_models.freezed.dart';
part 'profile_models.g.dart';

@freezed
class UserProfileModel with _$UserProfileModel {
  const factory UserProfileModel({
    required String id,
    required String email,
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? location,
    @Default(0) int followersCount,
    @Default(0) int followingCount,
    @Default(0) int playlistCount,
    @Default(false) bool isPublic,
    String? createdAt,
    String? lastActiveAt,
    @Default({}) Map<String, dynamic> stats,
  }) = _UserProfileModel;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) => _$UserProfileModelFromJson(json);
}

/// Entity conversion extension.
extension UserProfileModelX on UserProfileModel {
  UserProfile toEntity() => UserProfile(
        id: id, email: email, displayName: displayName,
        avatarUrl: avatarUrl, bio: bio, location: location,
        followersCount: followersCount, followingCount: followingCount,
        playlistCount: playlistCount, isPublic: isPublic,
        createdAt: createdAt != null ? DateTime.tryParse(createdAt!) : null,
        lastActiveAt: lastActiveAt != null ? DateTime.tryParse(lastActiveAt!) : null,
        stats: stats,
      );
}

/// Convert entity to model.
extension UserProfileEntityX on UserProfile {
  UserProfileModel toModel() => UserProfileModel(
        id: id, email: email, displayName: displayName,
        avatarUrl: avatarUrl, bio: bio, location: location,
        followersCount: followersCount, followingCount: followingCount,
        playlistCount: playlistCount, isPublic: isPublic,
        createdAt: createdAt?.toIso8601String(),
        lastActiveAt: lastActiveAt?.toIso8601String(),
        stats: stats,
      );
}

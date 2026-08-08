// ════════════════════════════════════════════════
// Project Lyra — Profile Entities
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_entities.freezed.dart';
part 'profile_entities.g.dart';

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
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
    DateTime? createdAt,
    DateTime? lastActiveAt,
    @Default({}) Map<String, dynamic> stats,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
}

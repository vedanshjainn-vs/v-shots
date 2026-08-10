// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Profile Service (Supabase Profiles & Follows)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import '../backend/supabase_service.dart';
import '../models/profile_model.dart';

class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  ProfileModel _currentLocalProfile = const ProfileModel(
    id: 'self',
    username: 'vshots_creator',
    fullName: 'V Shots Creator',
    avatarUrl:
        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&q=80',
    bio: 'Creating short visual vibes & synth wave music on V Shots 🎬✨',
    followersCount: 1420,
    followingCount: 280,
    shotsCount: 12,
  );

  /// Get current user profile
  Future<ProfileModel> getCurrentProfile() async {
    final user = SupabaseService.currentUser;
    if (!SupabaseService.isAvailable || user == null) {
      return _currentLocalProfile;
    }

    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        return _currentLocalProfile.copyWith(
          id: user.id,
          username: user.userMetadata?['username'] as String? ??
              'user_${user.id.substring(0, 6)}',
          fullName: user.userMetadata?['full_name'] as String? ??
              user.email ??
              'V Shots User',
          avatarUrl: user.userMetadata?['avatar_url'] as String? ?? '',
        );
      }

      // Count shots, followers, following
      final shotsCount = await SupabaseService.client
          .from('shots')
          .select('id')
          .eq('user_id', user.id);
      final followersCount = await SupabaseService.client
          .from('follows')
          .select('follower_id')
          .eq('following_id', user.id);
      final followingCount = await SupabaseService.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', user.id);

      final profile = ProfileModel.fromJson(response).copyWith(
        shotsCount: (shotsCount as List).length,
        followersCount: (followersCount as List).length,
        followingCount: (followingCount as List).length,
      );
      _currentLocalProfile = profile;
      return profile;
    } catch (e) {
      debugPrint('[ProfileService] getCurrentProfile error: $e');
      return _currentLocalProfile;
    }
  }

  /// Get profile by user id
  Future<ProfileModel?> getProfileById(String userId) async {
    if (!SupabaseService.isAvailable) {
      return _currentLocalProfile;
    }

    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      final currentUserId = SupabaseService.currentUser?.id;
      bool isFollowing = false;
      if (currentUserId != null && currentUserId != userId) {
        final followCheck = await SupabaseService.client
            .from('follows')
            .select('follower_id')
            .eq('follower_id', currentUserId)
            .eq('following_id', userId)
            .maybeSingle();
        isFollowing = followCheck != null;
      }

      return ProfileModel.fromJson(response).copyWith(isFollowing: isFollowing);
    } catch (e) {
      debugPrint('[ProfileService] getProfileById error: $e');
      return null;
    }
  }

  /// Update current profile details
  Future<ProfileModel> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    final user = SupabaseService.currentUser;
    _currentLocalProfile = _currentLocalProfile.copyWith(
      fullName: fullName,
      username: username,
      bio: bio,
      avatarUrl: avatarUrl,
    );

    if (!SupabaseService.isAvailable || user == null) {
      return _currentLocalProfile;
    }

    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (fullName != null) updates['full_name'] = fullName;
      if (username != null) updates['username'] = username;
      if (bio != null) updates['bio'] = bio;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      final response = await SupabaseService.client
          .from('profiles')
          .update(updates)
          .eq('id', user.id)
          .select()
          .single();

      final updated = ProfileModel.fromJson(response);
      _currentLocalProfile = updated;
      return updated;
    } catch (e) {
      debugPrint('[ProfileService] updateProfile error: $e');
      return _currentLocalProfile;
    }
  }

  /// Toggle Follow user
  Future<bool> toggleFollow(String targetUserId,
      {required bool currentFollowingState}) async {
    final currentUser = SupabaseService.currentUser;
    final targetState = !currentFollowingState;

    if (!SupabaseService.isAvailable || currentUser == null) {
      return targetState;
    }

    try {
      if (targetState) {
        await SupabaseService.client.from('follows').insert({
          'follower_id': currentUser.id,
          'following_id': targetUserId,
        });
      } else {
        await SupabaseService.client
            .from('follows')
            .delete()
            .eq('follower_id', currentUser.id)
            .eq('following_id', targetUserId);
      }
      return targetState;
    } catch (e) {
      debugPrint('[ProfileService] toggleFollow error: $e');
      return currentFollowingState;
    }
  }

  /// Upload avatar image to Supabase Storage
  Future<String?> uploadAvatar(Uint8List bytes, String fileExtension) async {
    if (!SupabaseService.isAvailable) return null;
    final user = SupabaseService.currentUser;
    if (user == null) return null;

    final fileName =
        '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    try {
      await SupabaseService.client.storage.from('avatars').uploadBinary(
            fileName,
            bytes,
          );

      final publicUrl =
          SupabaseService.client.storage.from('avatars').getPublicUrl(fileName);
      await updateProfile(avatarUrl: publicUrl);
      return publicUrl;
    } catch (e) {
      debugPrint('[ProfileService] uploadAvatar error: $e');
      return null;
    }
  }
}

// ════════════════════════════════════════════════
// Project Lyra — Profile Remote Data Source
// ════════════════════════════════════════════════

import 'dart:io';

import '../../../../../core/logging/app_logger.dart';
import '../models/profile_models.dart';

abstract class ProfileRemoteDataSource {
  Future<UserProfileModel> getProfile(String userId);
  Future<UserProfileModel> getCurrentProfile();
  Future<UserProfileModel> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? location,
    bool? isPublic,
  });
  Future<String> uploadAvatar(File imageFile);
  Future<void> deleteAvatar();
  Future<UserProfileModel> followUser(String userId);
  Future<UserProfileModel> unfollowUser(String userId);
  Future<bool> isFollowing(String userId);
}

class SupabaseProfileRemoteDataSource implements ProfileRemoteDataSource {
  SupabaseProfileRemoteDataSource({AppLogger? logger})
      : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  @override
  Future<UserProfileModel> getProfile(String userId) async {
    try {
      // TODO(team): Implement with Supabase.
      // final response = await supabase.from('profiles').select().eq('id', userId).single();
      // return UserProfileModel.fromJson(response);
      throw UnimplementedError();
    } catch (e, st) {
      _logger.e('ProfileRemote: getProfile failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<UserProfileModel> getCurrentProfile() async {
    try {
      // TODO(team): Implement with Supabase.
      // final userId = supabase.auth.currentUser!.id;
      // final response = await supabase.from('profiles').select().eq('id', userId).single();
      // return UserProfileModel.fromJson(response);
      throw UnimplementedError();
    } catch (e, st) {
      _logger.e('ProfileRemote: getCurrentProfile failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<UserProfileModel> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? location,
    bool? isPublic,
  }) async {
    try {
      // TODO(team): Implement with Supabase.
      // final updates = <String, dynamic>{};
      // if (displayName != null) updates['display_name'] = displayName;
      // if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      // if (bio != null) updates['bio'] = bio;
      // if (location != null) updates['location'] = location;
      // if (isPublic != null) updates['is_public'] = isPublic;
      // final response = await supabase.from('profiles')
      //     .update(updates)
      //     .eq('id', supabase.auth.currentUser!.id)
      //     .select().single();
      // return UserProfileModel.fromJson(response);
      throw UnimplementedError();
    } catch (e, st) {
      _logger.e('ProfileRemote: updateProfile failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<String> uploadAvatar(File imageFile) async {
    try {
      // TODO(team): Implement with Supabase Storage.
      // final userId = supabase.auth.currentUser!.id;
      // final path = 'avatars/$userId.jpg';
      // await supabase.storage.from('avatars').upload(path, imageFile);
      // final url = supabase.storage.from('avatars').getPublicUrl(path);
      // return url;
      return 'https://avatar.projectlyra.com/placeholder.jpg';
    } catch (e, st) {
      _logger.e('ProfileRemote: uploadAvatar failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> deleteAvatar() async {
    try {
      // TODO(team): Implement with Supabase Storage.
      _logger.d('ProfileRemote: Deleted avatar');
    } catch (e, st) {
      _logger.e('ProfileRemote: deleteAvatar failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<UserProfileModel> followUser(String userId) async {
    try {
      // TODO(team): Implement with Supabase.
      // await supabase.from('follows').insert({
      //   'follower_id': supabase.auth.currentUser!.id,
      //   'following_id': userId,
      // });
      throw UnimplementedError();
    } catch (e, st) {
      _logger.e('ProfileRemote: followUser failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<UserProfileModel> unfollowUser(String userId) async {
    try {
      // TODO(team): Implement with Supabase.
      // await supabase.from('follows')
      //     .delete()
      //     .eq('follower_id', supabase.auth.currentUser!.id)
      //     .eq('following_id', userId);
      throw UnimplementedError();
    } catch (e, st) {
      _logger.e('ProfileRemote: unfollowUser failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<bool> isFollowing(String userId) async {
    try {
      // TODO(team): Implement with Supabase.
      return false;
    } catch (e) {
      return false;
    }
  }
}

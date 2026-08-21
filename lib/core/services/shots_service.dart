// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Shots Service (Supabase Shots CRUD & Feed)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import '../backend/supabase_service.dart';
import '../models/comment_model.dart';
import '../models/profile_model.dart';
import '../models/shot_model.dart';

class ShotsService {
  ShotsService._();
  static final ShotsService instance = ShotsService._();

  // In-memory fallback / mock shots for offline or initial demo experience
  // Offline echo buffer only — starts empty, never ships fabricated
  // demo shots (removed 2026-08-21 for honesty).
  final List<ShotModel> _localShots = <ShotModel>[];

  /// Fetch primary feed of public shots. Returns an honest empty list when
  /// Supabase is unavailable or has no rows — never demo/mock shots.
  Future<List<ShotModel>> fetchFeed({int limit = 20, int offset = 0}) async {
    if (!SupabaseService.isAvailable) {
      return const [];
    }

    try {
      final currentUserId = SupabaseService.currentUser?.id;
      final response = await SupabaseService.client
          .from('shots')
          .select('*, profiles:user_id(*)')
          .eq('visibility', 'public')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final data = response as List<dynamic>;
      if (data.isEmpty) {
        return const [];
      }

      final shots = <ShotModel>[];
      for (final raw in data) {
        final json = raw as Map<String, dynamic>;
        final shotId = json['id'] as String;

        bool isLiked = false;
        bool isBookmarked = false;

        if (currentUserId != null) {
          final likeCheck = await SupabaseService.client
              .from('likes')
              .select('shot_id')
              .eq('user_id', currentUserId)
              .eq('shot_id', shotId)
              .maybeSingle();
          isLiked = likeCheck != null;

          final bookmarkCheck = await SupabaseService.client
              .from('bookmarks')
              .select('shot_id')
              .eq('user_id', currentUserId)
              .eq('shot_id', shotId)
              .maybeSingle();
          isBookmarked = bookmarkCheck != null;
        }

        shots.add(
          ShotModel.fromJson(
            json,
          ).copyWith(isLiked: isLiked, isBookmarked: isBookmarked),
        );
      }

      return shots;
    } catch (e) {
      debugPrint('[ShotsService] fetchFeed error: $e');
      return List<ShotModel>.from(_localShots);
    }
  }

  /// Fetch shots created by a specific user
  Future<List<ShotModel>> fetchUserShots(String userId) async {
    if (!SupabaseService.isAvailable) {
      return const [];
    }

    try {
      final response = await SupabaseService.client
          .from('shots')
          .select('*, profiles:user_id(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final data = response as List<dynamic>;
      return data
          .map((e) => ShotModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ShotsService] fetchUserShots error: $e');
      return <ShotModel>[];
    }
  }

  /// Create a new Shot
  Future<ShotModel?> createShot({
    required String caption,
    required String videoUrl,
    String? thumbnailUrl,
    int durationSeconds = 0,
    String visibility = 'public',
    List<String> tags = const <String>[],
  }) async {
    final currentUser = SupabaseService.currentUser;
    final userId = currentUser?.id ?? 'self';

    final newShot = ShotModel(
      id: 'shot-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      caption: caption,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl ??
          'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&q=80',
      durationSeconds: durationSeconds,
      visibility: visibility,
      tags: tags,
      creator: ProfileModel(
        id: userId,
        username: currentUser?.userMetadata?['username'] as String? ?? 'you',
        fullName: currentUser?.userMetadata?['full_name'] as String? ?? 'You',
        avatarUrl: currentUser?.userMetadata?['avatar_url'] as String? ?? '',
      ),
      createdAt: DateTime.now(),
    );

    if (!SupabaseService.isAvailable || currentUser == null) {
      _localShots.insert(0, newShot);
      return newShot;
    }

    try {
      final response = await SupabaseService.client
          .from('shots')
          .insert({
            'user_id': currentUser.id,
            'caption': caption,
            'video_url': videoUrl,
            'thumbnail_url': thumbnailUrl,
            'duration_seconds': durationSeconds,
            'visibility': visibility,
          })
          .select('*, profiles:user_id(*)')
          .single();

      return ShotModel.fromJson(response);
    } catch (e) {
      debugPrint('[ShotsService] createShot error: $e');
      _localShots.insert(0, newShot);
      return newShot;
    }
  }

  /// Toggle Like on a shot
  Future<bool> toggleLike(
    String shotId, {
    required bool currentLikedState,
  }) async {
    final currentUser = SupabaseService.currentUser;
    final targetState = !currentLikedState;

    if (!SupabaseService.isAvailable || currentUser == null) {
      final index = _localShots.indexWhere((s) => s.id == shotId);
      if (index != -1) {
        final s = _localShots[index];
        _localShots[index] = s.copyWith(
          isLiked: targetState,
          likeCount: targetState
              ? s.likeCount + 1
              : (s.likeCount > 0 ? s.likeCount - 1 : 0),
        );
      }
      return targetState;
    }

    try {
      if (targetState) {
        await SupabaseService.client.from('likes').insert({
          'user_id': currentUser.id,
          'shot_id': shotId,
        });
      } else {
        await SupabaseService.client
            .from('likes')
            .delete()
            .eq('user_id', currentUser.id)
            .eq('shot_id', shotId);
      }
      return targetState;
    } catch (e) {
      debugPrint('[ShotsService] toggleLike error: $e');
      return currentLikedState;
    }
  }

  /// Toggle Bookmark / Save on a shot
  Future<bool> toggleBookmark(
    String shotId, {
    required bool currentBookmarkState,
  }) async {
    final currentUser = SupabaseService.currentUser;
    final targetState = !currentBookmarkState;

    if (!SupabaseService.isAvailable || currentUser == null) {
      final index = _localShots.indexWhere((s) => s.id == shotId);
      if (index != -1) {
        final s = _localShots[index];
        _localShots[index] = s.copyWith(isBookmarked: targetState);
      }
      return targetState;
    }

    try {
      if (targetState) {
        await SupabaseService.client.from('bookmarks').insert({
          'user_id': currentUser.id,
          'shot_id': shotId,
        });
      } else {
        await SupabaseService.client
            .from('bookmarks')
            .delete()
            .eq('user_id', currentUser.id)
            .eq('shot_id', shotId);
      }
      return targetState;
    } catch (e) {
      debugPrint('[ShotsService] toggleBookmark error: $e');
      return currentBookmarkState;
    }
  }

  /// Fetch comments for a shot
  Future<List<CommentModel>> fetchComments(String shotId) async {
    if (!SupabaseService.isAvailable) {
      return <CommentModel>[
        CommentModel(
          id: 'mock-c1',
          shotId: shotId,
          userId: 'user-1',
          body: 'This looks incredible! Loving the smooth dark mode vibes 🔥',
          author: const ProfileModel(
            id: 'user-1',
            username: 'alexdev',
            fullName: 'Alex River',
            avatarUrl:
                'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&q=80',
          ),
          createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
        ),
        CommentModel(
          id: 'mock-c2',
          shotId: shotId,
          userId: 'user-2',
          body:
              'What synth preset are you using here? That filter sweep is pure magic ✨',
          author: const ProfileModel(
            id: 'user-2',
            username: 'synthwave_queen',
            fullName: 'Elena Rostova',
            avatarUrl:
                'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&q=80',
          ),
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];
    }

    try {
      final response = await SupabaseService.client
          .from('comments')
          .select('*, profiles:user_id(*)')
          .eq('shot_id', shotId)
          .order('created_at', ascending: true);

      final data = response as List<dynamic>;
      return data
          .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ShotsService] fetchComments error: $e');
      return <CommentModel>[];
    }
  }

  /// Post a new comment
  Future<CommentModel?> postComment(String shotId, String body) async {
    final currentUser = SupabaseService.currentUser;
    final userId = currentUser?.id ?? 'self';

    final localComment = CommentModel(
      id: 'comm-${DateTime.now().millisecondsSinceEpoch}',
      shotId: shotId,
      userId: userId,
      body: body,
      author: ProfileModel(
        id: userId,
        username: currentUser?.userMetadata?['username'] as String? ?? 'you',
        fullName: currentUser?.userMetadata?['full_name'] as String? ?? 'You',
        avatarUrl: currentUser?.userMetadata?['avatar_url'] as String? ?? '',
      ),
      createdAt: DateTime.now(),
    );

    if (!SupabaseService.isAvailable || currentUser == null) {
      return localComment;
    }

    try {
      final response = await SupabaseService.client
          .from('comments')
          .insert({'shot_id': shotId, 'user_id': currentUser.id, 'body': body})
          .select('*, profiles:user_id(*)')
          .single();

      return CommentModel.fromJson(response);
    } catch (e) {
      debugPrint('[ShotsService] postComment error: $e');
      return localComment;
    }
  }

  /// Upload shot video or media file to Supabase Storage
  Future<String?> uploadShotMedia({
    required Uint8List bytes,
    required String fileExtension,
    String bucket = 'shots',
  }) async {
    if (!SupabaseService.isAvailable) {
      return null;
    }

    final currentUser = SupabaseService.currentUser;
    final userId = currentUser?.id ?? 'guest';
    final fileName =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    try {
      await SupabaseService.client.storage
          .from(bucket)
          .uploadBinary(fileName, bytes);

      final publicUrl =
          SupabaseService.client.storage.from(bucket).getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint('[ShotsService] uploadShotMedia error: $e');
      return null;
    }
  }
}

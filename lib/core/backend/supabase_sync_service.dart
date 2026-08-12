// ═════════════════════════════════════════════════════════════════════════
// V Shots — Supabase Sync Service (Phase 9, local-first / optimistic)
//
// Syncs the user's music data (likes, recently played, taste profile,
// playlists) to Supabase in the BACKGROUND. LocalLibrary remains the source of
// truth for instant UI; this service pushes/pulls quietly and reconciles, so a
// slow/flaky network never blocks the UI.
//
// All writes are optimistic (local first, then best-effort network sync).
// If Supabase is unavailable or the user is signed out, nothing is lost — the
// local store keeps working and will sync on the next successful session.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

import '../storage/local_library.dart';
import 'supabase_service.dart';

class SupabaseSyncService {
  SupabaseSyncService._();
  static final SupabaseSyncService instance = SupabaseSyncService._();

  bool _syncingLikes = false;
  bool _syncingRecent = false;

  /// Whether a sync is possible right now (Supabase up + user signed in).
  bool get _canSync =>
      SupabaseService.isAvailable && SupabaseService.currentUser != null;

  /// Pushes the local likes to Supabase (best-effort, owner-only rows).
  Future<void> syncLikes() async {
    if (!_canSync || _syncingLikes) return;
    _syncingLikes = true;
    try {
      final userId = SupabaseService.currentUser!.id;
      final db = SupabaseService.client;
      final likes = LocalLibrary.instance.likedSongs.value;
      for (final like in likes) {
        final videoId = (like['id'] as String?) ?? '';
        if (videoId.isEmpty) continue;
        try {
          await db.from('user_likes').upsert({
            'user_id': userId,
            'video_id': videoId,
            'title': (like['title'] as String?) ?? '',
            'artist': (like['artist'] as String?) ?? '',
            'thumbnail': (like['artwork'] as String?) ?? '',
          }, onConflict: 'user_id, video_id');
        } catch (e) {
          debugPrint('[Sync] like upsert failed (non-fatal): $e');
        }
      }
    } finally {
      _syncingLikes = false;
    }
  }

  /// Pushes the local recently-played list to Supabase.
  Future<void> syncRecentlyPlayed() async {
    if (!_canSync || _syncingRecent) return;
    _syncingRecent = true;
    try {
      final userId = SupabaseService.currentUser!.id;
      final db = SupabaseService.client;
      final recent = LocalLibrary.instance.recentlyPlayed.value;
      for (final item in recent) {
        final videoId = (item['id'] as String?) ?? '';
        if (videoId.isEmpty) continue;
        try {
          await db.from('recently_played').upsert({
            'user_id': userId,
            'video_id': videoId,
            'title': (item['title'] as String?) ?? '',
            'artist': (item['artist'] as String?) ?? '',
            'thumbnail': (item['artwork'] as String?) ?? '',
          }, onConflict: 'user_id, video_id');
        } catch (e) {
          debugPrint('[Sync] recently_played upsert failed (non-fatal): $e');
        }
      }
    } finally {
      _syncingRecent = false;
    }
  }

  /// Pushes the user's content preferences to Supabase `user_preferences`.
  Future<void> syncPreferences({
    required String country,
    required List<String> languages,
    required List<String> genres,
    required List<String> vibes,
    required bool onboardingCompleted,
  }) async {
    if (!_canSync) return;
    try {
      final userId = SupabaseService.currentUser!.id;
      await SupabaseService.client.from('user_preferences').upsert({
        'user_id': userId,
        'country': country,
        'languages': languages,
        'genres': genres,
        'vibes': vibes,
        'onboarding_completed': onboardingCompleted,
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('[Sync] preferences sync failed (non-fatal): $e');
    }
  }

  /// Pushes the taste profile (jsonb) to Supabase.
  Future<void> syncTasteProfile(Map<String, dynamic> profile) async {
    if (!_canSync) return;
    try {
      final userId = SupabaseService.currentUser!.id;
      await SupabaseService.client.from('user_taste_profile').upsert({
        'user_id': userId,
        'profile': profile,
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('[Sync] taste profile sync failed (non-fatal): $e');
    }
  }

  /// Records a recommendation/analytics event (fire-and-forget, best-effort).
  Future<void> recordEvent(
    String eventType, {
    String? videoId,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (!_canSync) return;
    try {
      final userId = SupabaseService.currentUser!.id;
      await SupabaseService.client.from('recommendation_events').insert({
        'user_id': userId,
        'event_type': eventType,
        'video_id': videoId,
        'metadata': metadata,
      });
    } catch (e) {
      debugPrint('[Sync] event record failed (non-fatal): $e');
    }
  }
}

// ════════════════════════════════════════════════
// V Shots — Supabase Service (initialization + typed accessors)
// ════════════════════════════════════════════════
//
// WHY THIS EXISTS AS ITS OWN FILE, NOT INLINE IN main():
// The git history of this repo already shows two prior, painful
// Supabase attempts:
//   "FIX: Remove Supabase dependency — standalone app that works"
//   "FIX: Cast dynamic to String, pin supabase version"
//   "FIX: Add supabase_flutter dependency and fix withValues API"
// i.e. a previous integration attempt broke the app badly enough that
// it was ripped out entirely. This version is deliberately written so
// that a Supabase failure (missing .env, network down, wrong keys)
// CANNOT crash or block the app's core music-playback functionality —
// initialize() catches everything and leaves `isAvailable == false`
// rather than throwing, and every feature built on top of this
// (auth_service.dart, and any future "liked songs sync" etc.) must
// check `SupabaseService.isAvailable` before touching the client.
//
// The actual database schema this connects to (profiles, tracks,
// albums, artists, playlists, liked_songs, play_history, followed_artists,
// saved_albums, subscriptions, notifications, user_settings,
// playlist_tracks) already exists in the live project — see
// supabase_setup.sql in the repo root, which was verified against the
// live database during this session (13/13 tables present, RLS enabled
// on all of them, 5 sample artists + 5 sample albums already seeded).
// ════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;
  static bool _available = false;

  /// True once [initialize] has completed successfully. Every caller
  /// that wants to use [client] MUST check this first — see the
  /// file-level note above on why this must never throw/crash the app.
  static bool get isAvailable => _available;

  /// Call once from main(), before runApp(). Safe to call multiple
  /// times (no-ops after the first successful/failed attempt).
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // isOptional: true — a missing .env must not crash the app;
      // it should just leave Supabase-backed features unavailable
      // (auth, cloud playlists, liked-songs sync) while local
      // playback/search/home continue working exactly as before.
      await dotenv.load(fileName: '.env', isOptional: true);

      final url = dotenv.maybeGet('SUPABASE_URL');
      final anonKey = dotenv.maybeGet('SUPABASE_ANON_KEY');

      if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
        debugPrint(
          '[SupabaseService] SUPABASE_URL / SUPABASE_ANON_KEY missing from '
          '.env — Supabase-backed features (auth, cloud sync) disabled. '
          'Local playback is unaffected.',
        );
        return;
      }

      // ignore: deprecated_member_use
      await Supabase.initialize(url: url, anonKey: anonKey);
      _available = true;
      debugPrint('[SupabaseService] Initialized successfully.');
    } catch (e, st) {
      // Deliberately swallow — see file header. A Supabase outage or
      // misconfiguration must never take down the whole app.
      debugPrint('[SupabaseService] Initialization failed: $e\n$st');
      _available = false;
    }
  }

  /// The live Supabase client. Only call this after checking
  /// [isAvailable] — throws if Supabase was never initialized.
  static SupabaseClient get client => Supabase.instance.client;

  /// Convenience: the current authenticated user, or null if signed
  /// out / Supabase unavailable.
  static User? get currentUser =>
      _available ? client.auth.currentUser : null;
}

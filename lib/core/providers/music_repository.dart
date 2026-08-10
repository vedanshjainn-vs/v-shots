// ════════════════════════════════════════════════
// V Shots — MusicRepository (the ONE thing UI code should depend on)
// ════════════════════════════════════════════════
//
// This is the top of the architecture diagram from this task's prompt:
//   UI -> MusicRepository -> ProviderManager -> YouTubeMusicProvider ->
//   existing YouTube implementation -> Stream Resolver -> just_audio
//
// WHY A REPOSITORY LAYER ON TOP OF ProviderManager AT ALL (rather than
// UI calling ProviderManager directly): ProviderManager's methods
// return `ProviderResult<ProviderTrack>`/`ProviderResult<List
// <ProviderTrack>>` — a typed shape internal to the provider layer.
// The rest of the app (LocalLibrary persistence, currentQueue,
// playTrack(), every screen) already works in terms of
// `Map<String, dynamic>` track records and cannot be changed without a
// large, risky rewrite this task explicitly forbids ("DO NOT rewrite
// main.dart unnecessarily... DO NOT replace working functionality").
// MusicRepository is the one seam that converts between the two: it
// calls ProviderManager, then converts `ProviderTrack` ->
// `Map<String, dynamic>` via `toTrackMap()` before returning to UI
// code. This keeps "UI never calls YoutubeExplode/sharedYt directly"
// literally true while changing nothing about the app's actual data
// flow/shape.
//
// SCOPE — what IS and ISN'T routed through this yet:
//   - Home's category search, Search screen's search, and Player's
//     stream resolution ARE routed through this (see main.dart's
//     `_search()` / `_SearchScreenState._search()` / `_play()` after
//     this task's UI changes).
//   - ForYouFeedService's recommendation logic (recency-weighted
//     scoring, similar-artist discovery, time-of-day buckets) is
//     real, non-trivial domain logic that lives in ForYouFeedService
//     on purpose — it now calls `MusicRepository.search()` instead of
//     `sharedYt.search.search()` directly (removing the direct
//     YouTube dependency from that file too), but the picking-a-query
//     logic itself stays in ForYouFeedService rather than being
//     absorbed into the provider layer, since that logic is
//     app-specific personalization, not "provider capability."
// ════════════════════════════════════════════════

import 'provider_manager.dart';
import 'provider_models.dart';

class MusicRepository {
  MusicRepository(this._manager);

  final ProviderManager _manager;

  /// Searches for tracks and returns them as the app's existing
  /// `Map<String, dynamic>` track shape — ready to hand straight to
  /// `playTrack()`, `currentQueue`, `LocalLibrary`, etc. Returns an
  /// empty list on failure (mirrors the exact behavior the old direct
  /// `sharedYt.search.search()` call sites already had in their own
  /// catch blocks) — callers that need to distinguish "search failed"
  /// from "genuinely zero results" should use [searchDetailed] instead
  /// (see SearchScreen's Phase 7 fix).
  Future<List<Map<String, dynamic>>> search(
    String query, {
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) async {
    final result = await _manager.search(
      query,
      limit: limit,
      maxDurationMinutes: maxDurationMinutes,
      minDurationMinutes: minDurationMinutes,
      excludeIds: excludeIds,
    );
    return result.orElse(const []).map((t) => t.toTrackMap()).toList();
  }

  /// Same as [search], but preserves the success/failure distinction
  /// so UI can show a real "search failed, try again" state instead of
  /// conflating it with "no results for this query" (Phase 7
  /// requirement: "genuine empty-results state").
  Future<({bool success, List<Map<String, dynamic>> tracks, String? error})>
  searchDetailed(
    String query, {
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) async {
    final result = await _manager.search(
      query,
      limit: limit,
      maxDurationMinutes: maxDurationMinutes,
      minDurationMinutes: minDurationMinutes,
      excludeIds: excludeIds,
    );
    return (
      success: result.isSuccess,
      tracks: result.orElse(const []).map((t) => t.toTrackMap()).toList(),
      error: result.error,
    );
  }

  Future<List<Map<String, dynamic>>> getTrending({int limit = 15}) async {
    final result = await _manager.getTrending(limit: limit);
    return result.orElse(const []).map((t) => t.toTrackMap()).toList();
  }

  Future<List<Map<String, dynamic>>> getRecommendations({
    required Set<String> excludeIds,
    int limit = 10,
  }) async {
    final result = await _manager.getRecommendations(
      excludeIds: excludeIds,
      limit: limit,
    );
    return result.orElse(const []).map((t) => t.toTrackMap()).toList();
  }

  /// Resolves a playable stream URL for [trackId] — routes through
  /// ProviderManager -> YouTubeMusicProvider -> the existing
  /// stream_resolver.dart. Returns null on failure (matches
  /// `resolveAudioStreamUrlLogged`'s own existing nullable-return
  /// contract, so call sites that already handle a null stream URL
  /// need no behavior change).
  Future<String?> getStream(String trackId) async {
    final result = await _manager.getStream(trackId);
    return result.isSuccess ? result.data : null;
  }

  Future<ProviderLyrics?> getLyrics({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  }) async {
    final result = await _manager.getLyrics(
      trackName: trackName,
      artistName: artistName,
      durationSeconds: durationSeconds,
    );
    return result.isSuccess ? result.data : null;
  }
}

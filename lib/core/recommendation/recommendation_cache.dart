// ════════════════════════════════════════════════
// V Shots — Recommendation Engine: Caching (Phase 7, Part T)
// ════════════════════════════════════════════════
//
// Caches ranked recommendation results AND the derived TasteProfile
// itself, per Part T's explicit instruction ("Cache: candidate
// results, ranked results, user preference profile... When user
// likes/skips/listens: invalidate or partially update the affected
// recommendation cache").
//
// Deliberately simple (in-memory, process-lifetime, short TTL) —
// matches `SearchCache`'s already-established pattern in this
// codebase exactly (same TTL philosophy, same "stale is fine, just
// avoid redundant recomputation" goal) rather than inventing a
// different caching approach for this one subsystem.
// ════════════════════════════════════════════════

import 'recommendation_scorer.dart';
import 'taste_profile.dart';

class _CachedFeed {
  _CachedFeed(this.tracks, this.expiresAt);
  final List<ScoredTrack> tracks;
  final DateTime expiresAt;
}

class RecommendationCache {
  RecommendationCache._();
  static final RecommendationCache instance = RecommendationCache._();

  static const Duration feedTtl = Duration(minutes: 5);
  static const Duration profileTtl = Duration(minutes: 2);

  final Map<String, _CachedFeed> _feedCache = {};
  TasteProfile? _cachedProfile;
  DateTime? _profileCachedAt;

  List<ScoredTrack>? getFeed(String key) {
    final entry = _feedCache[key];
    if (entry == null) return null;
    return entry.tracks;
  }

  bool isFeedFresh(String key) {
    final entry = _feedCache[key];
    if (entry == null) return false;
    return DateTime.now().isBefore(entry.expiresAt);
  }

  void setFeed(String key, List<ScoredTrack> tracks) {
    _feedCache[key] = _CachedFeed(tracks, DateTime.now().add(feedTtl));
  }

  TasteProfile? getCachedProfile() {
    if (_cachedProfile == null || _profileCachedAt == null) return null;
    if (DateTime.now().difference(_profileCachedAt!) > profileTtl) return null;
    return _cachedProfile;
  }

  void setCachedProfile(TasteProfile profile) {
    _cachedProfile = profile;
    _profileCachedAt = DateTime.now();
  }

  /// Lighter invalidation — clears only the derived TasteProfile
  /// cache, NOT already-fetched feed results. Used after a signal that
  /// should influence FUTURE scoring (a like/skip/completion) but
  /// where re-fetching tracks from the network for every single signal
  /// would be wasteful (Part T: "Do not rebuild everything
  /// unnecessarily"). Profile recompute itself is cheap (pure
  /// arithmetic over a bounded signal-event list, no network call —
  /// see TasteProfileBuilder), so invalidating it liberally costs
  /// little, while feed results (which DID cost a real network
  /// request) are preserved until their own TTL or an explicit
  /// [invalidateAll].
  void invalidateProfile() {
    _cachedProfile = null;
    _profileCachedAt = null;
  }

  /// Full invalidation — clears cached feeds AND the profile. Used
  /// when a signal should visibly change the NEXT feed the user sees
  /// (e.g. "Not Interested in this artist," which the user expects to
  /// take effect immediately, not after up to 5 stale minutes).
  void invalidateAll() {
    _feedCache.clear();
    invalidateProfile();
  }

  void clear() => invalidateAll();
}

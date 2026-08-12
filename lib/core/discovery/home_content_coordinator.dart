// ═════════════════════════════════════════════════════════════════════════
// V Shots — HomeContentCoordinator
//
// Coordinates LIVE Home content: per-section TTL cache, global cross-section
// deduplication, music-quality validation, and LIVE → CACHED_LIVE → FALLBACK
// source priority. Owns usedVideoIds/usedSongKeys/usedArtistKeys so the same
// song/artist does not repeat across Home sections (default: no overlap).
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../preferences/user_preferences.dart';
import '../providers/adapters/youtube/youtube_data_api_client.dart';
import '../providers/adapters/youtube/youtube_repository.dart';
import '../providers/provider_models.dart';
import '../recommendation/candidate_pool.dart';
import 'live_music_discovery_service.dart';

/// Normalizes a song key from artist + title so "Kesariya", "Kesariya Official
/// Video", etc. collapse to one key.
String normalizeSongKey(String artist, String title) {
  final a = artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  final t = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  final cleanTitle = t
      .replaceAll(
          RegExp(r'\b(official|lyric|lyrics|video|audio|hd|full|song)\b'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return '$a::$cleanTitle';
}

/// Metadata validation + music-quality filter (Phase 12).
class MusicValidator {
  static const _badKeywords = [
    'podcast',
    'reaction',
    'interview',
    'compilation',
    'mix 2026',
    'full album',
    'gaming',
    'news',
    'memes',
    'shorts',
    '#shorts',
    'tutorial',
  ];

  /// Returns true if the item looks like playable music, not a playlist/
  /// podcast/reaction/compilation/short.
  static bool isMusicCandidate(YouTubeVideoItem v) {
    if (v.id.isEmpty || v.title.isEmpty) return false;
    final lower = v.title.toLowerCase();
    if (_badKeywords.any(lower.contains)) return false;
    // Playable music should be reasonably short (not a 4-hour mix).
    if (v.durationSeconds > 900) return false; // > 15 min
    if (v.durationSeconds > 0 && v.durationSeconds < 30) return false; // shorts
    return true;
  }
}

class _SectionCache {
  _SectionCache(this.result, this.expiresAt);
  final HomeSectionResult result;
  final DateTime expiresAt;
}

class HomeContentCoordinator {
  HomeContentCoordinator({
    LiveMusicDiscoveryService? live,
    YouTubeRepository? repository,
  })  : _live = live ?? LiveMusicDiscoveryService(),
        _repo = repository ?? YouTubeRepository();

  final LiveMusicDiscoveryService _live;
  final YouTubeRepository _repo;
  final CandidatePool _pool = CandidatePool();

  // Per-section cache keyed by section title.
  final Map<String, _SectionCache> _cache = {};

  // Global cross-section dedup sets.
  final Set<String> _usedVideoIds = {};
  final Set<String> _usedSongKeys = {};
  final Set<String> _usedArtistKeys = {};

  /// Per-section TTLs (Phase 13).
  Duration ttlFor(String sectionTitle) {
    switch (sectionTitle) {
      case 'New Releases':
        return const Duration(minutes: 15);
      case "What's Hot":
        return const Duration(minutes: 15);
      case "India's Biggest Hits":
        return const Duration(minutes: 30);
      case 'Music Videos':
        return const Duration(minutes: 30);
      case 'Made For You':
        return const Duration(minutes: 60);
      default:
        return const Duration(minutes: 30);
    }
  }

  void reset() {
    _cache.clear();
    _usedVideoIds.clear();
    _usedSongKeys.clear();
    _usedArtistKeys.clear();
  }

  bool _isFresh(String title) {
    final c = _cache[title];
    if (c == null) return false;
    return DateTime.now().isBefore(c.expiresAt);
  }

  /// Returns cached result if fresh, else null.
  HomeSectionResult? cached(String title) =>
      _isFresh(title) ? _cache[title]!.result : null;

  /// Fetches a section live (or returns fresh cache). Skips items already used
  /// globally across sections (no-overlap default).
  Future<HomeSectionResult> fetchSection(
    String title, {
    required String intent,
    required UserPreferences prefs,
    int limit = 12,
    bool allowOverlap = false,
  }) async {
    // 1. Fresh cache? return cachedLive.
    final cached = this.cached(title);
    if (cached != null) return cached;

    // 2. Only attempt LIVE when a real API key is configured. Phase 24: never
    //    label content "live" unless it actually came from a current API call.
    if (_repo.isLive) {
      final live = await _fetchLive(title, intent, prefs, limit, allowOverlap);
      if (live.tracks.isNotEmpty) {
        _store(title, live);
        return live;
      }
    }

    // 3. Fallback (last resort): verified category catalog.
    final fb = await _fetchFallback(title, intent, prefs, limit, allowOverlap);
    _store(title, fb);
    return fb;
  }

  Future<HomeSectionResult> _fetchLive(
    String title,
    String intent,
    UserPreferences prefs,
    int limit,
    bool allowOverlap,
  ) async {
    final svc = _live;
    final queries = svc.buildLiveQueries(prefs, intent);
    final all = <YouTubeVideoItem>[];
    final seenInSection = <String>{};

    for (final q in queries.take(3)) {
      try {
        final page = await _repo.searchVideos(
          q,
          limit: limit.clamp(10, 50),
          regionCode: svc.regionCodeFor(prefs),
          relevanceLanguage: svc.relevanceLanguageFor(prefs),
          publishedAfter: intent == 'new releases' || title == 'New Releases'
              ? _publishedAfter(7)
              : null,
          videoEmbeddable: true,
          videoDuration: 'medium',
        );
        for (final v in page.items) {
          if (seenInSection.contains(v.id)) continue;
          if (!MusicValidator.isMusicCandidate(v)) continue;
          if (!allowOverlap && _usedVideoIds.contains(v.id)) continue;
          final key = normalizeSongKey(v.channelTitle, v.title);
          if (!allowOverlap && _usedSongKeys.contains(key)) continue;
          seenInSection.add(v.id);
          all.add(v);
        }
        if (all.length >= limit * 3) break;
      } catch (e) {
        debugPrint('[Home] live fetch error for $q: $e');
      }
    }

    // Dedup within section (song-key level) into a larger candidate pool.
    final songKeys = <String>{};
    final deduped = <YouTubeVideoItem>[];
    for (final v in all) {
      final key = normalizeSongKey(v.channelTitle, v.title);
      if (!songKeys.add(key)) continue;
      deduped.add(v);
      if (deduped.length >= limit * 4) break; // keep a large pool to rank from
    }

    // Phase 16/17: raw live results are NEVER treated as final — rank the pool
    // through the hybrid scorer (taste, similarity, behavior, freshness,
    // language, penalties + artist diversity) then take the top `limit`.
    final seed = _poolSeedFor(intent);
    final ranked = _pool.process(
      raw: deduped.map(_toProviderTrack).toList(),
      seed: seed,
      limit: limit,
      preferredLanguage: _langCodeFor(prefs),
    );
    final tracks = ranked.map((s) => s.track.toTrackMap()).toList();
    _registerUsed(tracks, allowOverlap);
    return HomeSectionResult(
      title: title,
      tracks: tracks,
      source: ContentSource.live,
      fetchedAt: DateTime.now(),
      query: queries.join(' | '),
      candidateCount: all.length,
      validCount: deduped.length,
      dedupedCount: tracks.length,
    );
  }

  Future<HomeSectionResult> _fetchFallback(
    String title,
    String intent,
    UserPreferences prefs,
    int limit,
    bool allowOverlap,
  ) async {
    // Use the repository's fallback (category-specific) via a bare search.
    try {
      final page = await _repo.searchVideos(intent, limit: limit);
      final valid = page.items.where(MusicValidator.isMusicCandidate).toList();
      final tracks = valid.map(_toTrack).toList();
      _registerUsed(tracks, allowOverlap);
      return HomeSectionResult(
        title: title,
        tracks: tracks,
        source: ContentSource.fallback,
        fetchedAt: DateTime.now(),
        query: '$intent songs official audio',
        candidateCount: valid.length,
        validCount: valid.length,
        dedupedCount: tracks.length,
      );
    } catch (e) {
      debugPrint('[Home] fallback error: $e');
      return HomeSectionResult(
          title: title, tracks: const [], source: ContentSource.fallback);
    }
  }

  void _registerUsed(List<Map<String, dynamic>> tracks, bool allowOverlap) {
    if (allowOverlap) return;
    for (final t in tracks) {
      final id = t['id'] as String? ?? '';
      final artist = t['artist'] as String? ?? '';
      final title = t['title'] as String? ?? '';
      if (id.isNotEmpty) _usedVideoIds.add(id);
      if (artist.isNotEmpty) _usedArtistKeys.add(artist.toLowerCase());
      if (artist.isNotEmpty || title.isNotEmpty) {
        _usedSongKeys.add(normalizeSongKey(artist, title));
      }
    }
  }

  void _store(String title, HomeSectionResult result) {
    _cache[title] = _SectionCache(result, DateTime.now().add(ttlFor(title)));
  }

  ProviderTrack _toProviderTrack(YouTubeVideoItem v) => ProviderTrack(
        id: v.id,
        title: v.title,
        artist: v.channelTitle,
        artworkUrl: v.thumbnailUrl,
        durationSeconds: v.durationSeconds,
      );

  /// A seed song for similarity ranking (derived from the section intent), or
  /// null for sections where similarity is less relevant.
  ProviderTrack? _poolSeedFor(String intent) {
    final l = intent.toLowerCase();
    if (l.contains('because') ||
        l.contains('listened') ||
        l.contains('similar')) {
      // No concrete seed available here; the Discover/similar paths provide one.
      return null;
    }
    return null;
  }

  /// Maps a preferred language name to a 2-letter code for the pool's language
  /// relevance check.
  String _langCodeFor(UserPreferences prefs) {
    const map = {
      'Hindi': 'hi',
      'Punjabi': 'pa',
      'English': 'en',
      'Tamil': 'ta',
      'Telugu': 'te',
    };
    final langs = prefs.languages.isNotEmpty
        ? prefs.languages
        : const <String>['English'];
    return map[langs.first] ?? 'en';
  }

  Map<String, dynamic> _toTrack(YouTubeVideoItem v) => {
        'id': v.id,
        'title': v.title,
        'artist': v.channelTitle,
        'artwork': v.thumbnailUrl,
        'duration': v.durationSeconds,
        'publishedAt': v.publishedAt?.toIso8601String(),
      };

  /// RFC3339 publishedAfter for [days] ago.
  String _publishedAfter(int days) {
    final d = DateTime.now().subtract(Duration(days: days)).toUtc();
    return d.toIso8601String();
  }
}

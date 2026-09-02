// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Discover Feed Engine (V Shots Discover Algorithm)
// ═════════════════════════════════════════════════════════════════════════════
//
// The Discover (For You) swipe feed algorithm. Goal per swipe:
//   "give the user a song they will want to listen to".
//
// CANDIDATE BUCKETS (adaptive weights, owner spec):
//   • Personal (taste)      — long-term taste + Music Intelligence V3
//   • Trending/Viral        — regional trending, taste-weighted
//   • Fresh                 — new releases with decay-based boost
//   • Exploration           — taste-ADJACENT, never random garbage
//
// Adaptive tiers by interaction maturity:
//   cold   (<10 signals)   → 40/25/20/15
//   warm   (<100 signals)  → 50/25/15/10
//   strong (≥100 signals)  → 65/15/10/10
//
// DISCOVER SCORE (0..1):
//   .30 taste + .15 recent behaviour + .15 artist/genre affinity
//   + .10 trending + .10 freshness + .05 popularity
//   + .05 completion-probability + .05 diversity + .05 exploration
//
// Guards: artist fatigue (no repeat within last 5 cards unless top-tier),
// song dedupe (session + excludeIds), genre cap via MusicRanker diversity,
// "why this song" reason attached to every card.
//
// The feed is DYNAMIC: batches of 10-20 candidates, re-ranked after every
// swipe via recordSwipe() — session behaviour immediately reshapes the
// next batch. Home CMS stays editorial/structured; this engine is
// Discover-only.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../music/music_ranker.dart';
import '../providers/music_repository.dart';
import '../recommendation/feed_intent.dart';
import '../recommendation/genre_classifier.dart';
import '../recommendation/music_recommendation_engine.dart';
import '../recommendation/recommendation_engine.dart';
import '../recommendation/recommendation_service.dart';
import '../remote_config/remote_config_service.dart';
import '../storage/local_library.dart';

/// Adaptive bucket weights. All values 0..1, sum == 1.
@immutable
class DiscoverWeights {
  const DiscoverWeights({
    required this.personal,
    required this.trending,
    required this.fresh,
    required this.exploration,
  });

  final double personal;
  final double trending;
  final double fresh;
  final double exploration;

  static const cold = DiscoverWeights(
    personal: 0.40,
    trending: 0.25,
    fresh: 0.20,
    exploration: 0.15,
  );
  static const warm = DiscoverWeights(
    personal: 0.50,
    trending: 0.25,
    fresh: 0.15,
    exploration: 0.10,
  );
  static const strong = DiscoverWeights(
    personal: 0.65,
    trending: 0.15,
    fresh: 0.10,
    exploration: 0.10,
  );
}

enum DiscoverBucket { personal, trending, fresh, exploration }

/// What the user did with a card — mirrors the owner's signal table.
enum DiscoverSwipeOutcome {
  /// Swiped away within ~3 seconds — strong negative.
  skippedImmediately,

  /// Listened 15s+ — positive.
  listenedShort,

  /// Listened 45s+ — strong positive.
  listenedLong,

  /// Let the song finish (or 90%+) — very strong positive.
  completed,

  /// Replayed the same song — extremely strong positive.
  replayed,

  /// Liked — very strong positive (also recorded by the tracker).
  liked,
}

class DiscoverFeedEngine {
  DiscoverFeedEngine({
    MusicRepository? repository,
    RecommendationEngine? recommendationEngine,
    MusicRecommendationEngine? musicEngine,
    @visibleForTesting Map<String, double>? artistScoresOverride,
  })  : _repository = repository,
        _recommendationEngine = recommendationEngine,
        _musicEngine = musicEngine,
        _artistScoresOverride = artistScoresOverride;

  final MusicRepository? _repository;
  final RecommendationEngine? _recommendationEngine;
  final MusicRecommendationEngine? _musicEngine;
  final Map<String, double>? _artistScoresOverride;

  /// Session memory — reshapes the very next batch after every swipe.
  final List<String> _recentArtists = [];
  final List<String> _recentGenres = [];
  final List<String> _sessionSongIds = [];
  int _sessionSignalCount = 0;

  int get sessionSignalCount => _sessionSignalCount;
  List<String> get recentArtistsWindow => List.unmodifiable(_recentArtists);

  Map<String, double> get _artistScores {
    final override = _artistScoresOverride;
    if (override != null) return override;
    return RecommendationService.instance.getRecencyWeightedArtistScores();
  }

  int get _tasteSignalCount => _artistScores.length + _sessionSignalCount;

  /// Adaptive weights by interaction maturity (owner tiers).
  DiscoverWeights adaptiveWeights() {
    final n = _tasteSignalCount;
    if (n < 10) return DiscoverWeights.cold;
    if (n < 100) return DiscoverWeights.warm;
    return DiscoverWeights.strong;
  }

  /// Long-term + current session artist sets (for recent-behaviour score).
  Set<String> get _activeArtists => {..._recentArtists, ..._artistScores.keys};

  Set<String> _activeGenres() {
    final out = <String>{..._recentGenres};
    for (final a in _artistScores.keys.take(8)) {
      out.addAll(GenreClassifier.instance.classify(title: '', artist: a));
    }
    return out;
  }

  // ── CANDIDATE POOLS ────────────────────────────────────────────────────────

  /// Generates the next swipe batch. [config] comes from the remote
  /// `discover_settings` row (defaults when absent); [excludeIds] prevents
  /// repeats across sessions. [languages]/[moods]/[regions] are the active
  /// Explore filters — when ANY filter is active the feed switches to
  /// FILTER-FIRST mode: every pool obeys the selected filters, so a Mood /
  /// Language / Genre pick actually shapes the feed instead of returning
  /// unrelated "random" songs.
  Future<List<Map<String, dynamic>>> nextBatch({
    required Set<String> excludeIds,
    int count = 12,
    List<String> languages = const [],
    List<String> moods = const [],
    List<String> regions = const [],
    Map<String, dynamic>? config,
  }) async {
    final cfg = config ?? RemoteConfigService.instance.discoverSettings;
    final enabled = Map<String, bool>.from(
      (cfg['enabled'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final filtersActive =
        languages.isNotEmpty || moods.isNotEmpty || regions.isNotEmpty;
    final weights = filtersActive
        ? _filterFirstWeights()
        : (_weightsFromConfig(cfg) ?? adaptiveWeights());
    final region = (cfg['region'] as String?)?.trim().isNotEmpty == true
        ? (cfg['region'] as String).trim()
        : 'IN';

    // Quotas per bucket from weights (proportional, min 1 when enabled).
    final quotas = <DiscoverBucket, int>{};
    int allocate(DiscoverBucket b, double w, bool on) {
      final q = on ? max(1, (count * w).round()) : 0;
      quotas[b] = q;
      return q;
    }

    allocate(
      DiscoverBucket.personal,
      weights.personal,
      enabled['personalization'] != false,
    );
    allocate(
      DiscoverBucket.trending,
      weights.trending,
      enabled['trending'] != false,
    );
    allocate(DiscoverBucket.fresh, weights.fresh, enabled['fresh'] != false);
    allocate(
      DiscoverBucket.exploration,
      weights.exploration,
      enabled['exploration'] != false,
    );
    // Rounding drift: give the remainder to personal (or trending).
    var total = quotas.values.fold(0, (a, b) => a + b);
    if (total < count) {
      quotas[DiscoverBucket.personal] =
          (quotas[DiscoverBucket.personal] ?? 0) + (count - total);
      total = count;
    }

    final candidates = <_ScoredCandidate>[];
    await Future.wait([
      if ((quotas[DiscoverBucket.personal] ?? 0) > 0)
        _personalPool(
          excludeIds,
          languages,
          moods,
          regions,
        ).then(candidates.addAll),
      if ((quotas[DiscoverBucket.trending] ?? 0) > 0)
        _trendingPool(
          excludeIds,
          region,
          filters: _filterTokens(languages, moods, regions),
        ).then(candidates.addAll),
      if ((quotas[DiscoverBucket.fresh] ?? 0) > 0)
        _freshPool(excludeIds, languages, moods).then(candidates.addAll),
      if ((quotas[DiscoverBucket.exploration] ?? 0) > 0)
        _explorationPool(
          excludeIds,
          cfg,
          filters: _filterTokens(languages, moods, regions),
        ).then(candidates.addAll),
    ]);

    // Fallback: pools empty (network hiccup) → one safe popular query so
    // Discover is NEVER blank.
    if (candidates.isEmpty) {
      final fallback = await _queryPool(
        filtersActive
            ? '${_filterTokens(languages, moods, regions).join(' ')} songs official audio'
            : 'top songs official audio',
        excludeIds,
        bucket: DiscoverBucket.trending,
        count: count,
      );
      candidates.addAll(fallback);
    }

    final ranked = _rankCandidates(candidates, excludeIds, quotas, count);
    return ranked;
  }

  /// Filter-first bucket weights: when the user picked a Mood / Language /
  /// Genre / Decade / Activity, the feed must be dominated by content that
  /// matches those picks (personal stays the top bucket but every pool gets
  /// the filter tokens applied to its queries).
  static DiscoverWeights _filterFirstWeights() => const DiscoverWeights(
        personal: 0.50,
        trending: 0.10,
        fresh: 0.25,
        exploration: 0.15,
      );

  static List<String> _filterTokens(
    List<String> languages,
    List<String> moods,
    List<String> regions,
  ) =>
      <String>[
        ...moods,
        ...languages,
        ...regions,
      ].where((t) => t.trim().isNotEmpty).toList();

  Future<List<_ScoredCandidate>> _personalPool(
    Set<String> excludeIds,
    List<String> languages,
    List<String> moods,
    List<String> regions,
  ) async {
    final filterTokens = _filterTokens(languages, moods, regions).join(' ');
    final out = <_ScoredCandidate>[];
    final music = _musicEngine;
    final rec = _recommendationEngine;

    // Engine calls run CONCURRENTLY (they are independent pools) — this is
    // the single biggest cold-start win: two slow engines overlap instead of
    // waiting one-after-another.
    final engineResults = await Future.wait([
      if (music != null)
        music
            .generateForYou(
              excludeIds: excludeIds,
              count: 24,
              languages: languages,
              moods: moods,
              regions: regions,
            )
            .then<List<_ScoredCandidate>>(
              (tracks) => tracks
                  .map(
                    (t) => _ScoredCandidate(
                      t,
                      DiscoverBucket.personal,
                      'music-engine',
                    ),
                  )
                  .toList(),
            )
            .catchError((Object e) {
          debugPrint('[DiscoverEngine] music engine pool failed: $e');
          return <_ScoredCandidate>[];
        }),
      if (rec != null)
        rec
            .generateFeed(
          intent: FeedIntent.forYou,
          excludeIds: excludeIds,
          count: 12,
          forceRefresh: true,
        )
            .then<List<_ScoredCandidate>>((scored) {
          final list = <_ScoredCandidate>[];
          for (final s in scored) {
            final map = s.track.toTrackMap();
            map['discoverSourceQuery'] = 'personal';
            list.add(
              _ScoredCandidate(
                map,
                DiscoverBucket.personal,
                'taste-engine',
              ),
            );
          }
          return list;
        }).catchError((Object e) {
          debugPrint('[DiscoverEngine] rec engine pool failed: $e');
          return <_ScoredCandidate>[];
        }),
    ]);
    for (final list in engineResults) {
      out.addAll(list);
    }

    // Seed-artist queries: songs of top artists (the "because you listened"
    // chain) — also used by cold users whose profile is building. Filter
    // tokens are appended so an active Mood/Language pick shapes these too.
    final topArtists = _artistScores.keys.take(3).toList();
    if (topArtists.isNotEmpty && _repository != null) {
      final seeds = await Future.wait(
        topArtists.map(
          (a) => _queryPool(
            filterTokens.isEmpty
                ? '$a songs official audio'
                : '$a $filterTokens songs official audio',
            excludeIds,
            bucket: DiscoverBucket.personal,
            count: 8,
            sourceQuery: '$a songs',
            seedArtist: a,
          ),
        ),
      );
      for (final list in seeds) {
        out.addAll(list);
      }
    }
    return out;
  }

  Future<List<_ScoredCandidate>> _trendingPool(
    Set<String> excludeIds,
    String region, {
    List<String> filters = const [],
  }) async {
    // Filter-first: trending is regional by definition, so when the user
    // picked a Mood/Language/Genre the trending slot ALSO follows the
    // filters instead of injecting unrelated popular videos.
    if (filters.isNotEmpty) {
      return _queryPool(
        'trending ${filters.join(' ')} songs official video',
        excludeIds,
        bucket: DiscoverBucket.trending,
        count: 8,
      );
    }
    final out = <_ScoredCandidate>[];
    final repo = _repository;
    // Real trending + query fallback run CONCURRENTLY.
    final both = await Future.wait<List<_ScoredCandidate>>([
      if (repo != null)
        repo
            .getTrending(limit: 15, region: region)
            .then<List<_ScoredCandidate>>(
              (trending) => trending
                  .map(
                    (t) => _ScoredCandidate(
                      t,
                      DiscoverBucket.trending,
                      'trending-$region',
                    ),
                  )
                  .toList(),
            )
            .catchError((Object e) {
          debugPrint('[DiscoverEngine] trending pool failed: $e');
          return <_ScoredCandidate>[];
        }),
      _queryPool(
        'trending songs official music video',
        excludeIds,
        bucket: DiscoverBucket.trending,
        count: 8,
      ),
    ]);
    for (final list in both) {
      out.addAll(list);
    }
    return out;
  }

  Future<List<_ScoredCandidate>> _freshPool(
    Set<String> excludeIds,
    List<String> languages,
    List<String> moods,
  ) async {
    final tokens = _filterTokens(languages, moods, const []);
    final q = tokens.isEmpty
        ? 'new music releases official audio'
        : 'new ${tokens.join(' ')} songs official audio';
    return _queryPool(
      q,
      excludeIds,
      bucket: DiscoverBucket.fresh,
      count: 12,
      sourceQuery: q,
    );
  }

  Future<List<_ScoredCandidate>> _explorationPool(
    Set<String> excludeIds,
    Map<String, dynamic> cfg, {
    List<String> filters = const [],
  }) async {
    // Filter-first: exploration STAYS INSIDE the picked theme (chill +
    // Hindi stays chill-Hindi adjacent) instead of wandering off.
    if (filters.isNotEmpty) {
      final tokens = filters.join(' ');
      final queries = <String>[
        '$tokens songs official audio',
        '$tokens playlist hits official audio',
        'best $tokens songs 2026 official audio',
      ];
      final lists = await Future.wait(
        queries.map(
          (q) => _queryPool(
            q,
            excludeIds,
            bucket: DiscoverBucket.exploration,
            count: 5,
            sourceQuery: q,
          ),
        ),
      );
      return lists.expand((l) => l).toList();
    }

    // Taste-ADJACENT: admin-configured exploration queries minus the user's
    // dominant genres — never pure random.
    final cfgList = ((cfg['explore_queries'] as List?) ?? const [])
        .whereType<String>()
        .toList();
    final defaultQueries = [
      'punjabi hit songs official audio',
      'telugu hit songs official audio',
      'english indie songs official audio',
      'lofi chill beats official audio',
      'hip hop rap official audio',
    ];
    final queries = cfgList.isNotEmpty ? cfgList : defaultQueries;
    final dominant = _activeGenres().map((g) => g.toLowerCase()).toSet();
    final adjacent = queries
        .where((q) {
          final tags = GenreClassifier.instance.classify(
            title: '',
            artist: '',
            sourceQuery: q,
          );
          return tags.isEmpty ||
              tags.any((t) => !dominant.contains(t.toLowerCase()));
        })
        .take(3)
        .toList();

    final lists = await Future.wait(
      adjacent.map(
        (q) => _queryPool(
          q,
          excludeIds,
          bucket: DiscoverBucket.exploration,
          count: 5,
          sourceQuery: q,
        ),
      ),
    );
    return lists.expand((l) => l).toList();
  }

  Future<List<_ScoredCandidate>> _queryPool(
    String query,
    Set<String> excludeIds, {
    required DiscoverBucket bucket,
    required int count,
    String? sourceQuery,
    String? seedArtist,
  }) async {
    final repo = _repository;
    if (repo == null) return const [];
    try {
      final tracks = await repo.search(
        query,
        limit: count,
        excludeIds: excludeIds,
      );
      return tracks.map((t) {
        final m = Map<String, dynamic>.from(t);
        m['discoverSourceQuery'] = sourceQuery ?? query;
        // The REAL seed artist (taste profile), used by _reasonFor so the
        // "Because you like X" chip names the artist the user listens to —
        // never the upload channel of the track itself.
        if (seedArtist != null && seedArtist.isNotEmpty) {
          m['discoverSeedArtist'] = seedArtist;
        }
        return _ScoredCandidate(m, bucket, sourceQuery ?? query);
      }).toList();
    } catch (e) {
      debugPrint('[DiscoverEngine] query pool failed ($query): $e');
      return const [];
    }
  }

  // ── SCORING ───────────────────────────────────────────────────────────────

  DiscoverWeights? _weightsFromConfig(Map<String, dynamic>? cfg) {
    final raw = (cfg?['weights'] as Map?)?.cast<String, dynamic>();
    if (raw == null) return null;
    final personal = double.tryParse('${raw['personal'] ?? ''}');
    final trending = double.tryParse('${raw['trending'] ?? ''}');
    final fresh = double.tryParse('${raw['fresh'] ?? ''}');
    final exploration = double.tryParse('${raw['exploration'] ?? ''}');
    if ([personal, trending, fresh, exploration].any((v) => v == null)) {
      return null;
    }
    final sum = personal! + trending! + fresh! + exploration!;
    if (sum <= 0) return null;
    return DiscoverWeights(
      personal: personal / sum,
      trending: trending / sum,
      fresh: fresh / sum,
      exploration: exploration / sum,
    );
  }

  double _log10(double v) => v <= 1 ? 0 : log(v) / ln10;

  /// Pure scoring — separated for unit tests.
  double scoreTrack(
    Map<String, dynamic> track, {
    required DiscoverBucket bucket,
    required Map<String, double> artistScores,
    required Set<String> activeArtists,
    required Set<String> activeGenres,
    required Set<String> recentArtists,
  }) {
    final artist = (track['artist'] as String?) ?? '';
    final artistKey = artist.trim().toLowerCase();
    final title = (track['title'] as String?) ?? '';
    final query = (track['discoverSourceQuery'] as String?) ?? '';
    final genres = GenreClassifier.instance.classify(
      title: title,
      artist: artist,
      sourceQuery: query,
    );

    // 1. Taste match (30%) — long-term artist/genre affinity.
    final maxArtistScore =
        artistScores.isEmpty ? 1.0 : artistScores.values.reduce(max);
    final artistTaste = artistScores[artist] ?? artistScores[artistKey] ?? 0.0;
    final artistMatch =
        maxArtistScore <= 0 ? 0.0 : artistTaste / maxArtistScore;
    final genreMatch = activeGenres.isEmpty
        ? 0.0
        : (genres.where(activeGenres.contains).length / max(1, genres.length));
    final taste = 0.7 * artistMatch + 0.3 * genreMatch;

    // 2. Recent behaviour (15%) — current-session artist/genre overlap.
    final recentArtistHit = recentArtists.any(
      (a) => a.trim().toLowerCase() == artistKey,
    );
    final recentGenreHit =
        genres.any(activeGenres.contains) && recentArtists.isNotEmpty;
    final recent = (recentArtistHit ? 0.8 : 0.0) + (recentGenreHit ? 0.2 : 0.0);

    // 3. Affinity (15%) — artist + genre affinity combined.
    final affinity = 0.6 * artistMatch + 0.4 * genreMatch;

    // 4. Trending (10%) — normalized view count.
    final views = (track['views'] as num?)?.toDouble() ?? 0;
    final trending = views <= 0 ? 0.3 : (_log10(views) / 9).clamp(0.0, 1.0);

    // 5. Freshness (10%) — release age decay 0..14 days.
    final age = (track['ageDays'] as num?)?.toDouble();
    final fresh =
        age == null ? 0.5 : (1 - (age.clamp(0, 14) / 14)).clamp(0.0, 1.0);

    // 6. Popularity (5%).
    final popularity = trending * 0.5;

    // 7. Completion probability (5%) — taste-proxy approximation.
    final completion = 0.3 + 0.7 * artistMatch;

    // 8. Diversity (5%) — bonus when artist is absent from the window.
    final diversity =
        recentArtists.any((a) => a.trim().toLowerCase() == artistKey)
            ? 0.0
            : 1.0;

    // 9. Exploration (5%) — bucket bonus.
    final exploration = bucket == DiscoverBucket.exploration ? 1.0 : 0.0;

    return 0.30 * taste +
        0.15 * recent +
        0.15 * affinity +
        0.10 * trending +
        0.10 * fresh +
        0.05 * popularity +
        0.05 * completion +
        0.05 * diversity +
        0.05 * exploration;
  }

  /// The "why this song" reason. Priority:
  ///   1. A genuine SEED artist (taste-profile artist whose query produced
  ///      this track) → "because you listened to X".
  ///   2. The track's artist matching the LONG-TERM taste profile (the same
  ///      honest signal). The session swipe window is deliberately NOT used:
  ///      swipe-inflated artist names (which for uploads are CHANNEL titles)
  ///      were producing "Because you like `<channel name>`" on every card
  ///      of that channel — the owner-reported bug.
  ///   3. Otherwise a bucket-based reason.
  String _reasonFor(
    Map<String, dynamic> track,
    DiscoverBucket bucket,
    Map<String, double> artistScores,
  ) {
    final seed = (track['discoverSeedArtist'] as String?)?.trim() ?? '';
    if (seed.isNotEmpty) {
      return 'because_you_listened_to_$seed';
    }
    final artist = (track['artist'] as String?) ?? '';
    final artistKey = artist.trim().toLowerCase();
    final inTasteProfile = artistKey.isNotEmpty &&
        (artistScores[artist] != null || artistScores[artistKey] != null);
    if (inTasteProfile) {
      return 'because_you_listened_to_$artist';
    }
    switch (bucket) {
      case DiscoverBucket.trending:
        return 'trending_in_india';
      case DiscoverBucket.fresh:
        return 'new_release';
      case DiscoverBucket.exploration:
        return 'something_new_for_you';
      case DiscoverBucket.personal:
        return 'similar_to_your_taste';
    }
  }

  List<Map<String, dynamic>> _rankCandidates(
    List<_ScoredCandidate> candidates,
    Set<String> excludeIds,
    Map<DiscoverBucket, int> quotas,
    int count,
  ) {
    final artistScores = _artistScores;
    final activeArtists = _activeArtists;
    final activeGenres = _activeGenres();
    final recent = _recentArtists.toSet();
    final scored = <_ScoredCandidate>[];

    for (final c in candidates) {
      final id = (c.track['id'] as String?) ?? '';
      if (id.isEmpty) continue;
      if (excludeIds.contains(id) || _sessionSongIds.contains(id)) continue;
      c.score = scoreTrack(
        c.track,
        bucket: c.bucket,
        artistScores: artistScores,
        activeArtists: activeArtists,
        activeGenres: activeGenres,
        recentArtists: recent,
      );
      // Recently surfaced cards are a soft negative, not a hard exclusion:
      // fresh candidates win whenever the provider can supply them, while a
      // thin result set can still fall back instead of going blank.
      if (LocalLibrary.instance.recentlyShownIds.contains(id)) {
        c.score *= 0.42;
      }
      c.reason = _reasonFor(c.track, c.bucket, artistScores);
      scored.add(c);
    }
    // Drop bad candidates.
    scored.removeWhere((c) => c.score < 0.15);
    scored.sort((a, b) => b.score.compareTo(a.score));

    // Artist fatigue: no artist repeat within the last 5 emitted cards
    // unless the candidate is top-tier (score >= 0.75).
    final emitted = <String>[];
    final window = <String>[..._recentArtists];
    void pushArtist(String artist) {
      emitted.add(artist);
      window.add(artist);
      if (window.length > 5) window.removeAt(0);
    }

    final out = <Map<String, dynamic>>[];
    final perBucket = <DiscoverBucket, int>{
      for (final b in DiscoverBucket.values) b: 0,
    };
    // Respect quotas, then fill any remainder with best remaining.
    for (final c in scored) {
      if (out.length >= count) break;
      final bucket = c.bucket;
      if (perBucket[bucket]! >= (quotas[bucket] ?? 0)) continue;
      final artist = (c.track['artist'] as String?) ?? '';
      final artistKey = artist.trim().toLowerCase();
      final inWindow = window.any((a) => a.trim().toLowerCase() == artistKey);
      if (inWindow && c.score < 0.75) continue;
      out.add(_attachMeta(c));
      perBucket[bucket] = perBucket[bucket]! + 1;
      pushArtist(artistKey);
      _sessionSongIds.add((c.track['id'] as String?) ?? '');
    }
    // Remainder fill (quotas unmet because pools were thin).
    if (out.length < count) {
      for (final c in scored) {
        if (out.length >= count) break;
        if (out.any((t) => t['id'] == c.track['id'])) continue;
        final artist = (c.track['artist'] as String?) ?? '';
        final artistKey = artist.trim().toLowerCase();
        final inWindow = window.any((a) => a.trim().toLowerCase() == artistKey);
        if (inWindow && c.score < 0.75) continue;
        out.add(_attachMeta(c));
        pushArtist(artistKey);
        _sessionSongIds.add((c.track['id'] as String?) ?? '');
      }
    }
    // Genre fatigue: reuse the ranker's diversity pass for a final
    // interleave (artist caps), preserving score order mostly.
    return const MusicRanker().applyDiversity(out, maxPerArtist: 2);
  }

  Map<String, dynamic> _attachMeta(_ScoredCandidate c) {
    return {
      ...c.track,
      'discoverScore': c.score.toStringAsFixed(4),
      'discoverBucket': c.bucket.name,
      'discoverReason': c.reason,
    };
  }

  /// Records a swipe outcome: immediately reshapes session memory (and thus
  /// the very next batch). Skips/fast-swipes push the artist DOWN, long
  /// listens/completions push it UP in the session window.
  void recordSwipe(
    Map<String, dynamic> track, {
    required DiscoverSwipeOutcome outcome,
  }) {
    final artist = ((track['artist'] as String?) ?? '').trim().toLowerCase();
    final id = (track['id'] as String?) ?? '';
    if (id.isNotEmpty && !_sessionSongIds.contains(id)) {
      _sessionSongIds.add(id);
    }
    final genres = GenreClassifier.instance.classify(
      title: (track['title'] as String?) ?? '',
      artist: artist,
      sourceQuery: (track['discoverSourceQuery'] as String?) ?? '',
    );
    switch (outcome) {
      case DiscoverSwipeOutcome.skippedImmediately:
        _sessionSignalCount++;
        break; // negative: do NOT add to the positive session window
      case DiscoverSwipeOutcome.listenedShort:
      case DiscoverSwipeOutcome.listenedLong:
      case DiscoverSwipeOutcome.completed:
      case DiscoverSwipeOutcome.replayed:
      case DiscoverSwipeOutcome.liked:
        _sessionSignalCount++;
        if (artist.isNotEmpty) {
          _recentArtists.add(artist);
          if (_recentArtists.length > 10) _recentArtists.removeAt(0);
        }
        _recentGenres.addAll(genres);
        while (_recentGenres.length > 10) {
          _recentGenres.removeAt(0);
        }
        break;
    }
  }
}

class _ScoredCandidate {
  _ScoredCandidate(this.track, this.bucket, this.sourceQuery);

  final Map<String, dynamic> track;
  final DiscoverBucket bucket;
  final String sourceQuery;
  double score = 0;
  String reason = '';
}

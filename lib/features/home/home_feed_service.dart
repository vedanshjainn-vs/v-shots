// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Home Feed Service (data-driven, personalized Home)
// ═════════════════════════════════════════════════════════════════════════════
//
// This is the single place that decides WHAT appears on Home and in WHAT
// order. It is deliberately data-driven:
//
//   • Personalized shelves (Made For You, Because You Listened To,
//     Trending For You, Discover Something New) are produced by the real
//     RecommendationEngine (signals -> taste profile -> candidate queries ->
//     scoring -> diversity), NOT hardcoded song lists.
//   • Catalog shelves (Trending, New Releases, Bollywood, Punjabi, …) are
//     fetched through the same MusicRepository -> YouTube Data API v3 /
//     fallback-catalog pipeline used everywhere else.
//   • Continue Listening is instant and offline — it reads the persisted
//     recently-played list.
//
// So Home visibly changes as the user listens: every play / completion /
// like / skip recorded by PlaybackSignalTracker reshapes the personalized
// shelves on the next Home load (see RecommendationEngine.recordSignal).
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

import '../../core/providers/music_repository.dart';
import '../../core/recommendation/feed_intent.dart';
import '../../core/recommendation/recommendation_cache.dart';
import '../../core/recommendation/recommendation_engine.dart';
import '../../core/recommendation/recommendation_scorer.dart';
import '../../core/recommendation/recommendation_service.dart';
import '../../core/recommendation/taste_profile.dart';
import '../../core/storage/local_library.dart';

/// What kind of content a shelf is built from.
enum HomeShelfKind {
  /// Instant, offline — the persisted recently-played list.
  continueListening,

  /// Personalized via the recommendation engine.
  madeForYou,
  becauseYouListenedTo,
  trendingForYou,
  discoverSomethingNew,

  /// Top artists derived from the user's taste profile (recs-driven).
  artistsForYou,

  /// Only official/verified uploads — hidden when too few qualify.
  officialMusic,

  /// A fixed catalog query (YouTube Data API / fallback catalog).
  catalog,
}

enum HomeShelfStatus { loading, loaded, error, hidden }

/// One Home shelf: identity + the rules for loading it + its current state.
class HomeShelf {
  HomeShelf({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    this.query,
    this.order = 'relevance',
    this.limit = 12,
    this.onlyWhenPersonalized = false,
    this.fallbackQueries = const [],
  });

  final String id;
  final String title;

  /// Human "why am I seeing this" line. For personalized shelves this is
  /// updated at load time with the actual seed artist (e.g. "Because you
  /// listened to Arijit Singh").
  String subtitle;
  final HomeShelfKind kind;

  /// YouTube query for [HomeShelfKind.catalog] shelves.
  final String? query;
  final String order;
  final int limit;

  /// Additional relevant queries used to REPLENISH the shelf when the primary
  /// query returns too few valid tracks (never random filler — only related,
  /// official-music queries).
  final List<String> fallbackQueries;

  /// When true the shelf is skipped entirely unless the user has enough
  /// listening history for it to be meaningful (avoids "Because you
  /// listened to nothing" rows on a cold start).
  final bool onlyWhenPersonalized;

  HomeShelfStatus status = HomeShelfStatus.loading;
  List<Map<String, dynamic>> tracks = [];

  /// Artist entries (name-based) for [HomeShelfKind.artistsForYou] shelves.
  List<Map<String, dynamic>> artists = [];
  String? error;
}

class HomeFeedService {
  HomeFeedService({MusicRepository? repository, RecommendationEngine? engine})
      : _repository = repository,
        _engine = engine;

  final MusicRepository? _repository;
  final RecommendationEngine? _engine;

  /// The ordered, data-driven shelf plan. Ordering here is the product
  /// decision of what Home emphasizes; the CONTENT of each shelf is decided
  /// by the data (taste profile + live catalog), not hardcoded here.
  List<HomeShelf> buildShelfDescriptors() => <HomeShelf>[
        HomeShelf(
          id: 'continue',
          title: 'Continue Listening',
          subtitle: 'Pick up where you left off',
          kind: HomeShelfKind.continueListening,
          limit: 15,
        ),
        HomeShelf(
          id: 'mfy',
          title: 'Made For You',
          subtitle: 'Personalized from your listening',
          kind: HomeShelfKind.madeForYou,
          limit: 14,
        ),
        HomeShelf(
          id: 'byld',
          title: 'Because You Listened To',
          subtitle: 'Based on your recent plays',
          kind: HomeShelfKind.becauseYouListenedTo,
          limit: 12,
          onlyWhenPersonalized: true,
        ),
        HomeShelf(
          id: 'trending',
          title: 'Trending Now',
          subtitle: 'What the world is playing',
          kind: HomeShelfKind.catalog,
          query: 'trending songs official music video 2026',
          order: 'viewCount',
          limit: 12,
          fallbackQueries: [
            'viral trending songs official audio 2026',
            'top songs official audio 2026',
          ],
        ),
        HomeShelf(
          id: 'new',
          title: 'New Releases',
          subtitle: 'Fresh drops this week',
          kind: HomeShelfKind.catalog,
          query: 'new music releases official audio 2026',
          order: 'date',
          limit: 12,
          fallbackQueries: ['latest songs official audio 2026'],
        ),
        HomeShelf(
          id: 'tfy',
          title: 'Trending For You',
          subtitle: 'Trending, ranked by your taste',
          kind: HomeShelfKind.trendingForYou,
          limit: 12,
        ),
        HomeShelf(
          id: 'artists',
          title: 'Artists For You',
          subtitle: 'From your listening taste',
          kind: HomeShelfKind.artistsForYou,
          onlyWhenPersonalized: true,
        ),
        HomeShelf(
          id: 'official',
          title: 'Official Music',
          subtitle: 'Verified artist & label uploads',
          kind: HomeShelfKind.officialMusic,
          limit: 12,
        ),
        HomeShelf(
          id: 'discover',
          title: 'Discover Something New',
          subtitle: 'Step outside your usual mix',
          kind: HomeShelfKind.discoverSomethingNew,
          limit: 12,
        ),
        HomeShelf(
          id: 'bollywood',
          title: 'Bollywood Hits',
          subtitle: 'Hindi cinema favourites',
          kind: HomeShelfKind.catalog,
          query: 'top bollywood hindi songs official music video',
          limit: 12,
          fallbackQueries: [
            'latest bollywood songs official audio',
            'new hindi movie songs official',
          ],
        ),
        HomeShelf(
          id: 'punjabi',
          title: 'Punjabi Bangers',
          subtitle: 'Desi energy',
          kind: HomeShelfKind.catalog,
          query: 'latest punjabi pop hits official audio',
          limit: 12,
          fallbackQueries: ['punjabi hit songs official audio'],
        ),
        HomeShelf(
          id: 'global',
          title: 'Global Pop',
          subtitle: 'International chart hits',
          kind: HomeShelfKind.catalog,
          query: 'billboard top global pop hits official audio',
          limit: 12,
          fallbackQueries: ['english pop hits official audio'],
        ),
        HomeShelf(
          id: 'lofi',
          title: 'Chill & Lo-Fi',
          subtitle: 'Late night focus',
          kind: HomeShelfKind.catalog,
          query: 'chill lofi late night beats official audio',
          limit: 12,
          fallbackQueries: ['lofi study beats official audio'],
        ),
        HomeShelf(
          id: 'hiphop',
          title: 'Hip-Hop',
          subtitle: 'Rap & beats',
          kind: HomeShelfKind.catalog,
          query: 'hip hop rap songs official audio',
          limit: 12,
          fallbackQueries: ['rap hits official audio'],
        ),
        HomeShelf(
          id: 'romantic',
          title: 'Romantic',
          subtitle: 'Love songs',
          kind: HomeShelfKind.catalog,
          query: 'romantic love songs official audio hindi',
          limit: 12,
          fallbackQueries: ['romantic hindi songs official video'],
        ),
        HomeShelf(
          id: 'classics',
          title: '90s Classics',
          subtitle: 'Evergreen hits',
          kind: HomeShelfKind.catalog,
          query: '90s 2000s evergreen bollywood classic songs',
          limit: 12,
          fallbackQueries: ['90s hindi songs official'],
        ),
      ];

  /// Whether the user has enough signal history for genuinely personalized
  /// shelves. Exposed for the UI (e.g. to show a "personalize your feed"
  /// nudge on a cold start).
  bool get hasPersonalization => RecommendationService.instance
      .getRecencyWeightedArtistScores()
      .isNotEmpty;

  /// Loads every shelf. [forceRefresh] bypasses the recommendation engine's
  /// short-lived feed cache so Home actually reflects new listening activity
  /// (the write path already records signals; this is the read path honoring
  /// them). [onUpdate] is invoked after each shelf's state changes so the UI
  /// can repaint progressively instead of waiting for everything.
  /// Pagination state per shelf (continuation/page token for catalog
  /// shelves). Keyed by shelf id — one source of truth, no second pipeline.
  final Map<String, String?> _shelfTokens = {};
  final Map<String, bool> _shelfExhausted = {};

  Future<void> loadShelves(
    List<HomeShelf> shelves, {
    bool forceRefresh = false,
    void Function()? onUpdate,
  }) async {
    if (forceRefresh) {
      // New listening/like/skip signals must be visible on the next Home
      // load, not up to 5 stale minutes later.
      RecommendationCache.instance.invalidateAll();
      _shelfTokens.clear();
      _shelfExhausted.clear();
    }

    // Per-shelf exclusion: each shelf starts from the SESSION recently-shown
    // set (freshness) and dedupes within itself only. Cross-shelf duplication
    // is SOFT (allowed) — a genuinely top track may legitimately appear on
    // Trending AND Global Pop; forcing artificial uniqueness hurt quality.
    final baseExclude = LocalLibrary.instance.recentlyShownIds;

    const phaseOneIds = {
      'continue',
      'mfy',
      'byld',
      'trending',
      'new',
      'tfy',
      'artists',
    };
    final phaseOne = shelves.where((s) => phaseOneIds.contains(s.id)).toList();
    final phaseTwo = shelves.where((s) => !phaseOneIds.contains(s.id)).toList();

    // Load in small chunks (not a full parallel burst): InnerTube/YouTube
    // throttle a burst of ~11 simultaneous discovery requests. 3-at-a-time
    // keeps Home fast without tripping rate limits.
    await _loadInChunks(
      phaseOne,
      baseExclude,
      force: forceRefresh,
      onUpdate: onUpdate,
    );
    await _loadInChunks(
      phaseTwo,
      baseExclude,
      force: forceRefresh,
      onUpdate: onUpdate,
    );
    onUpdate?.call();
  }

  Future<void> _loadInChunks(
    List<HomeShelf> shelves,
    Set<String> baseExclude, {
    required bool force,
    void Function()? onUpdate,
  }) async {
    const chunkSize = 3;
    for (var i = 0; i < shelves.length; i += chunkSize) {
      final chunk = shelves.skip(i).take(chunkSize).toList();
      await Future.wait(
        chunk.map(
          (s) => _loadShelf(
            s,
            {...baseExclude},
            force: force,
            onUpdate: onUpdate,
          ),
        ),
      );
    }
  }

  Future<void> _loadShelf(
    HomeShelf shelf,
    Set<String> excludeIds, {
    required bool force,
    void Function()? onUpdate,
  }) async {
    // Skip shelves that need history the user doesn't have yet.
    if (shelf.onlyWhenPersonalized && !hasPersonalization) {
      shelf.status = HomeShelfStatus.hidden;
      onUpdate?.call();
      return;
    }

    // "Artists For You" is derived directly from the taste profile — no
    // network call, and no fabricated artist list (empty → hidden).
    if (shelf.kind == HomeShelfKind.artistsForYou) {
      shelf.artists = _topArtists();
      shelf.status = shelf.artists.isEmpty
          ? HomeShelfStatus.hidden
          : HomeShelfStatus.loaded;
      onUpdate?.call();
      return;
    }

    if (!force &&
        shelf.status == HomeShelfStatus.loaded &&
        shelf.tracks.isNotEmpty) {
      return;
    }

    shelf.status = HomeShelfStatus.loading;
    shelf.error = null;
    onUpdate?.call();

    try {
      var tracks = await _fetch(shelf, excludeIds);
      tracks = _enforceArtistDiversity(tracks);
      if (tracks.isEmpty) {
        // "Official Music" (and any high-confidence-only shelf) hides
        // gracefully instead of showing an error when too few candidates
        // qualify — never padded with random uploads.
        if (shelf.kind == HomeShelfKind.officialMusic) {
          shelf.status = HomeShelfStatus.hidden;
        } else {
          shelf.status = HomeShelfStatus.error;
          shelf.error = 'Nothing to show yet';
        }
      } else {
        shelf.tracks = tracks;
        shelf.status = HomeShelfStatus.loaded;
        for (final t in tracks) {
          final id = t['id'] as String?;
          if (id != null && id.isNotEmpty) {
            excludeIds.add(id);
            LocalLibrary.instance.recordShownSong(id);
          }
        }
      }
    } catch (e) {
      debugPrint('[HomeFeedService] Shelf "${shelf.id}" failed: $e');
      shelf.status = HomeShelfStatus.error;
      shelf.error = '$e';
    }
    onUpdate?.call();
  }

  /// Appends the NEXT PAGE of results to [shelf] (lazy pagination). Returns
  /// true when more was appended, false when the provider is genuinely
  /// exhausted. Uses the existing searchPaginated/continuation pipeline.
  Future<bool> loadMoreShelf(
    HomeShelf shelf, {
    void Function()? onUpdate,
  }) async {
    if (_shelfExhausted[shelf.id] == true) return false;
    final repo = _repository;
    final engine = _engine;
    if (repo == null) return false;

    final currentIds = shelf.tracks
        .map((t) => t['id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    List<Map<String, dynamic>> more;
    if (shelf.kind == HomeShelfKind.catalog) {
      final query = shelf.query ?? '';
      if (query.isEmpty) {
        _shelfExhausted[shelf.id] = true;
        return false;
      }
      final page = await repo.searchPaginated(
        query,
        order: shelf.order,
        limit: shelf.limit,
        excludeIds: currentIds,
        pageToken: _shelfTokens[shelf.id],
      );
      _shelfTokens[shelf.id] = page.nextPageToken;
      more = page.tracks;
    } else {
      // Personalized shelves: generate fresh candidates excluding what's
      // already shown (the engine de-dups against excludeIds).
      if (engine == null) {
        _shelfExhausted[shelf.id] = true;
        return false;
      }
      final intent = switch (shelf.kind) {
        HomeShelfKind.madeForYou => FeedIntent.madeForYou,
        HomeShelfKind.becauseYouListenedTo => FeedIntent.becauseYouListenedTo,
        HomeShelfKind.trendingForYou => FeedIntent.trendingForYou,
        HomeShelfKind.discoverSomethingNew => FeedIntent.discoverSomethingNew,
        _ => FeedIntent.madeForYou,
      };
      final scored = await engine.generateFeed(
        intent: intent,
        excludeIds: currentIds,
        count: shelf.limit,
        forceRefresh: true,
      );
      more = scored.map((s) => s.track.toTrackMap()).toList();
    }

    if (more.isEmpty) {
      _shelfExhausted[shelf.id] = true;
      return false;
    }

    final seen = <String>{
      ...shelf.tracks.map((t) => t['id'] as String? ?? ''),
    };
    final appended = <Map<String, dynamic>>[];
    for (final track in more) {
      final id = track['id'] as String? ?? '';
      if (id.isEmpty || !seen.add(id)) continue;
      appended.add(track);
    }
    if (appended.isEmpty) {
      _shelfExhausted[shelf.id] = true;
      return false;
    }
    shelf.tracks = [...shelf.tracks, ...appended];
    onUpdate?.call();
    return true;
  }

  Future<List<Map<String, dynamic>>> _fetch(
    HomeShelf shelf,
    Set<String> excludeIds,
  ) async {
    final repo = _repository;
    final engine = _engine;

    switch (shelf.kind) {
      case HomeShelfKind.continueListening:
        return List<Map<String, dynamic>>.from(
          LocalLibrary.instance.recentlyPlayed.value,
        ).take(shelf.limit).toList();

      case HomeShelfKind.madeForYou:
      case HomeShelfKind.becauseYouListenedTo:
      case HomeShelfKind.trendingForYou:
      case HomeShelfKind.discoverSomethingNew:
        final intent = switch (shelf.kind) {
          HomeShelfKind.madeForYou => FeedIntent.madeForYou,
          HomeShelfKind.becauseYouListenedTo => FeedIntent.becauseYouListenedTo,
          HomeShelfKind.trendingForYou => FeedIntent.trendingForYou,
          _ => FeedIntent.discoverSomethingNew,
        };
        if (engine == null) return const [];
        try {
          final scored = await engine.generateFeed(
            intent: intent,
            excludeIds: excludeIds,
            count: shelf.limit,
          );
          if (scored.isNotEmpty) {
            // Enrich the "why" line with the real seed artist.
            if (shelf.kind == HomeShelfKind.becauseYouListenedTo) {
              final scores = RecommendationService.instance
                  .getRecencyWeightedArtistScores();
              if (scores.isNotEmpty) {
                final sorted = scores.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                shelf.subtitle = 'Because you listened to ${sorted.first.key}';
              }
            }
            return _ranked(scored);
          }
        } catch (e) {
          debugPrint('[HomeFeedService] engine intent ${intent.name}: $e');
        }
        // Engine produced nothing (e.g. cold network/empty candidates) —
        // fall back to a relevant catalog query so the shelf is never blank.
        if (repo == null) return const [];
        return repo.search(
          _fallbackQueryFor(shelf.kind),
          limit: shelf.limit,
          excludeIds: excludeIds,
        );

      case HomeShelfKind.artistsForYou:
        // Handled directly in _loadShelf (no fetch needed).
        return const [];

      case HomeShelfKind.officialMusic:
        if (repo == null) return const [];
        // Fetch extra, then keep ONLY official/verified uploads. Hidden
        // gracefully when fewer than a few qualify (see _loadShelf).
        final official = await repo.search(
          'top songs official audio 2026',
          limit: shelf.limit * 2,
          excludeIds: excludeIds,
        );
        return official
            .where((t) => t['isOfficial'] == true)
            .take(shelf.limit)
            .toList();

      case HomeShelfKind.catalog:
        if (repo == null) return const [];
        final query = shelf.query ?? '';
        if (query.isEmpty) return const [];
        return _fetchWithReplenishment(shelf, excludeIds);
    }
  }

  /// Fetches a catalog shelf and REPLENISHES it from related fallback queries
  /// when the primary query returns too few valid tracks — so a shelf is never
  /// 3 cards + empty space. Only related official-music queries are used
  /// (never random filler); dedup by id; stops once the target minimum is
  /// reached or queries are exhausted.
  Future<List<Map<String, dynamic>>> _fetchWithReplenishment(
    HomeShelf shelf,
    Set<String> excludeIds,
  ) async {
    final repo = _repository;
    if (repo == null) return const [];
    final queries = <String>[
      if (shelf.query != null && shelf.query!.isNotEmpty) shelf.query!,
      ...shelf.fallbackQueries,
    ];

    final result = <Map<String, dynamic>>[];
    final seen = <String>{...excludeIds};
    for (final q in queries) {
      final batch = await repo.search(
        q,
        order: shelf.order,
        limit: shelf.limit,
        excludeIds: seen,
      );
      for (final t in batch) {
        final id = t['id'] as String? ?? '';
        if (id.isEmpty || !seen.add(id)) continue;
        result.add(t);
        if (result.length >= shelf.limit) break;
      }
      if (result.length >= shelf.limit) break;
    }
    return result;
  }

  /// Top artists derived from the real taste profile (plays/completions/
  /// likes) — the same signal that drives the rest of Home. Never fabricated.
  List<Map<String, dynamic>> _topArtists() {
    final profile = TasteProfileBuilder().build();
    return profile.topArtists.take(10).map((name) => {'name': name}).toList();
  }

  static String _fallbackQueryFor(HomeShelfKind kind) {
    switch (kind) {
      case HomeShelfKind.madeForYou:
        return 'trending hits top songs official audio';
      case HomeShelfKind.becauseYouListenedTo:
        return 'similar artists popular songs official audio';
      case HomeShelfKind.trendingForYou:
        return 'trending songs official music video 2026';
      default:
        return 'new official music releases 2026';
    }
  }

  List<Map<String, dynamic>> _ranked(List<ScoredTrack> scored) =>
      scored.map((s) => s.track.toTrackMap()).toList();

  /// Caps how often one artist can appear within a shelf and prevents long
  /// same-artist runs — a light, deterministic diversity pass so a single
  /// dominant artist can't fill an entire row (the engine does the full
  /// scored diversity pass for personalized shelves; this is the cheap
  /// guarantee for catalog shelves).
  List<Map<String, dynamic>> _enforceArtistDiversity(
    List<Map<String, dynamic>> tracks,
  ) {
    const maxPerArtist = 3;
    const maxConsecutive = 2;
    final counts = <String, int>{};
    final result = <Map<String, dynamic>>[];
    String? lastArtist;
    var run = 0;

    for (final t in tracks) {
      final artist = t['artist'] as String? ?? '';
      final seen = (counts[artist] ?? 0);
      final wouldRun = artist == lastArtist ? run + 1 : 1;
      if (seen >= maxPerArtist || wouldRun > maxConsecutive) continue;
      counts[artist] = seen + 1;
      run = artist == lastArtist ? run + 1 : 1;
      lastArtist = artist;
      result.add(t);
    }
    return result;
  }
}

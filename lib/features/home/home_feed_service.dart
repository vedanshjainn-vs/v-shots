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

  /// When true the shelf is skipped entirely unless the user has enough
  /// listening history for it to be meaningful (avoids "Because you
  /// listened to nothing" rows on a cold start).
  final bool onlyWhenPersonalized;

  HomeShelfStatus status = HomeShelfStatus.loading;
  List<Map<String, dynamic>> tracks = [];
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
    ),
    HomeShelf(
      id: 'new',
      title: 'New Releases',
      subtitle: 'Fresh drops this week',
      kind: HomeShelfKind.catalog,
      query: 'new music releases official audio 2026',
      order: 'date',
      limit: 12,
    ),
    HomeShelf(
      id: 'tfy',
      title: 'Trending For You',
      subtitle: 'Trending, ranked by your taste',
      kind: HomeShelfKind.trendingForYou,
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
    ),
    HomeShelf(
      id: 'punjabi',
      title: 'Punjabi Bangers',
      subtitle: 'Desi energy',
      kind: HomeShelfKind.catalog,
      query: 'latest punjabi pop hits official audio',
      limit: 12,
    ),
    HomeShelf(
      id: 'global',
      title: 'Global Pop',
      subtitle: 'International chart hits',
      kind: HomeShelfKind.catalog,
      query: 'billboard top global pop hits official audio',
      limit: 12,
    ),
    HomeShelf(
      id: 'lofi',
      title: 'Chill & Lo-Fi',
      subtitle: 'Late night focus',
      kind: HomeShelfKind.catalog,
      query: 'chill lofi late night beats official audio',
      limit: 12,
    ),
    HomeShelf(
      id: 'hiphop',
      title: 'Hip-Hop',
      subtitle: 'Rap & beats',
      kind: HomeShelfKind.catalog,
      query: 'hip hop rap songs official audio',
      limit: 12,
    ),
    HomeShelf(
      id: 'romantic',
      title: 'Romantic',
      subtitle: 'Love songs',
      kind: HomeShelfKind.catalog,
      query: 'romantic love songs official audio hindi',
      limit: 12,
    ),
    HomeShelf(
      id: 'classics',
      title: '90s Classics',
      subtitle: 'Evergreen hits',
      kind: HomeShelfKind.catalog,
      query: '90s 2000s evergreen bollywood classic songs',
      limit: 12,
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
  Future<void> loadShelves(
    List<HomeShelf> shelves, {
    bool forceRefresh = false,
    void Function()? onUpdate,
  }) async {
    if (forceRefresh) {
      // New listening/like/skip signals must be visible on the next Home
      // load, not up to 5 stale minutes later.
      RecommendationCache.instance.invalidateAll();
    }

    // Shared exclusion set so the same track doesn't appear on two shelves
    // (real duplicate prevention, not just within a single shelf).
    final excludeIds = <String>{...LocalLibrary.instance.recentlyShownIds};

    // Phase 1: the shelves a user sees first — load them concurrently so
    // Home fills in quickly. Phase 2: the deeper catalog rows, loaded after
    // (and therefore excluded from) phase 1's results for cross-shelf
    // de-duplication.
    const phaseOneIds = {'continue', 'mfy', 'byld', 'trending', 'new', 'tfy'};
    final phaseOne = shelves.where((s) => phaseOneIds.contains(s.id)).toList();
    final phaseTwo = shelves.where((s) => !phaseOneIds.contains(s.id)).toList();

    // Load in small chunks (not a full parallel burst): InnerTube/YouTube
    // throttle a burst of ~11 simultaneous discovery requests, which was
    // causing individual Home shelves to fail. 3-at-a-time keeps Home fast
    // without tripping rate limits.
    await _loadInChunks(phaseOne, excludeIds, onUpdate: onUpdate);
    await _loadInChunks(phaseTwo, excludeIds, onUpdate: onUpdate);

    // Cross-shelf de-duplication is applied AFTER loading because phase-one
    // shelves load concurrently (and therefore can't see each other's
    // results). Shelves earlier in the plan win; later duplicates are
    // dropped. This is the hard guarantee that the same video never appears
    // on two different Home shelves.
    _dedupAcrossShelves(shelves);
    onUpdate?.call();
  }

  Future<void> _loadInChunks(
    List<HomeShelf> shelves,
    Set<String> excludeIds, {
    void Function()? onUpdate,
  }) async {
    const chunkSize = 3;
    for (var i = 0; i < shelves.length; i += chunkSize) {
      final chunk = shelves.skip(i).take(chunkSize).toList();
      await Future.wait(
        chunk.map((s) => _loadShelf(s, excludeIds, onUpdate: onUpdate)),
      );
    }
  }

  void _dedupAcrossShelves(List<HomeShelf> shelves) {
    final seen = <String>{};
    for (final shelf in shelves) {
      final kept = <Map<String, dynamic>>[];
      for (final t in shelf.tracks) {
        final id = t['id'] as String? ?? '';
        if (id.isEmpty || seen.add(id)) kept.add(t);
      }
      shelf.tracks = kept;
    }
  }

  Future<void> _loadShelf(
    HomeShelf shelf,
    Set<String> excludeIds, {
    void Function()? onUpdate,
  }) async {
    // Skip shelves that need history the user doesn't have yet.
    if (shelf.onlyWhenPersonalized && !hasPersonalization) {
      shelf.status = HomeShelfStatus.hidden;
      onUpdate?.call();
      return;
    }
    if (shelf.status == HomeShelfStatus.loaded && shelf.tracks.isNotEmpty) {
      return;
    }

    shelf.status = HomeShelfStatus.loading;
    shelf.error = null;
    onUpdate?.call();

    try {
      var tracks = await _fetch(shelf, excludeIds);
      tracks = _enforceArtistDiversity(tracks);
      if (tracks.isEmpty) {
        shelf.status = HomeShelfStatus.error;
        shelf.error = 'Nothing to show yet';
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

      case HomeShelfKind.catalog:
        if (repo == null) return const [];
        final query = shelf.query ?? '';
        if (query.isEmpty) return const [];
        return repo.search(
          query,
          order: shelf.order,
          limit: shelf.limit,
          excludeIds: excludeIds,
        );
    }
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

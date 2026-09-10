// ═════════════════════════════════════════════════════════════════════════════
// V Shots — "For You" Discover Feed (Reels-Style Swipe Playback & Vibe Picker)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ads/ad_config.dart';
import '../../core/ads/ad_policy.dart';
import '../../core/ads/discovery_swipe_native_ad_page.dart';
import '../../core/ads/player_sponsored_card.dart';
import '../../core/config/discovery_filters.dart';
import '../../core/config/discovery_remote.dart';
import '../../core/playback/playback_router.dart';
import '../../core/remote_config/remote_config_service.dart';
import '../../core/remote_config/remote_feature_flags.dart';
import '../../core/music/music_catalog_service.dart';
import '../../core/music/music_ranker.dart';
import '../../core/motion/motion.dart';
import '../../core/recommendation/feed_intent.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import 'package:v_shots/shared/widgets/loading_skeleton.dart';
import '../../shared/widgets/app_image.dart';
import '../../shared/widgets/comment_sheet.dart';
import '../../main.dart'
    show
        currentTabIndexNotifier,
        forYouFeedService,
        musicRecommendationEngine,
        musicRepository,
        playbackSignalTracker,
        recommendationEngine,
        showMoreOptionsSheet,
        showAddToPlaylistSheet;
import '../../core/discover/discover_feed_engine.dart';
import 'discovery_browser_controller.dart';
import '../../core/playback/vshots_playback_manager.dart';

class ForYouFeedScreen extends StatefulWidget {
  const ForYouFeedScreen({super.key});

  @override
  State<ForYouFeedScreen> createState() => _ForYouFeedScreenState();
}

class _ForYouFeedScreenState extends State<ForYouFeedScreen> {
  final PageController _pageController = PageController();

  /// The ONE app-global in-app browser session (VShotsPlaybackManager).
  /// Discovery reuses it — a second browser is never created anywhere.
  DiscoveryBrowserController get _browser =>
      VShotsPlaybackManager.instance.browser;

  final List<Map<String, dynamic>> _items = [];
  final Set<String> _seenIds = {};

  int _currentIndex = 0;
  bool _isLoadingMore = false;
  bool _initialLoading = true;

  // Discovery is a true vertical PageView: organic video pages are
  // interleaved with embeddable LevelPlay Native ad pages. The ad page is a
  // real SDK view, never a modal interstitial or a fake placeholder.
  bool get _adsEnabled =>
      AdPolicy.instance.canShowNative(AdPlacement.forYouFeed);

  int _adCountFor(int songCount) {
    if (!_adsEnabled || songCount <= 0) return 0;
    return (songCount - 1) ~/ AdConfig.discoveryAdEvery;
  }

  int get _pageCount => _items.length + _adCountFor(_items.length);

  bool _isAdPage(int page) {
    if (!_adsEnabled || page == 0) return false;
    return (page - AdConfig.discoveryAdEvery) %
            (AdConfig.discoveryAdEvery + 1) ==
        0;
  }

  int _songIndexForPage(int page) {
    if (!_adsEnabled) return page;
    final adsBefore = page ~/ (AdConfig.discoveryAdEvery + 1);
    return page - adsBefore;
  }

  int _pageForSongIndex(int songIndex) {
    if (!_adsEnabled) return songIndex;
    return songIndex + (songIndex ~/ AdConfig.discoveryAdEvery);
  }

  /// The APPLIED Discovery filter configuration — the only state the feed
  /// actually fetches from. The Explore sheet works on a DRAFT copy and only
  /// commits here on APPLY (see _showExplore).
  DiscoveryFilterCatalog _catalog = DiscoveryFilterCatalog.compiled;
  DiscoveryFilterConfig _applied = DiscoveryFilterConfig.initial;

  /// True while the PageView is being moved PROGRAMMATICALLY (auto-advance),
  /// so [_onPageChanged] does not re-trigger playback (no feedback loop).
  bool _syncingFromManager = false;

  /// The V Shots Discover algorithm engine: adaptive bucket weights,
  /// Discover Score ranking, artist/genre fatigue and dynamic re-ranking.
  /// Session-scoped — swipe behaviour immediately reshapes the next batch.
  late final DiscoverFeedEngine _discoverEngine;

  /// Swipe-time tracking: how long the previous card was on screen.
  DateTime? _cardShownAt;
  Map<String, dynamic>? _prevCard;

  @override
  void initState() {
    super.initState();
    _catalog = DiscoveryFilterCatalog.resolve(
      useRemote: RemoteFeatureFlags.instance.enableDiscoveryRemoteCategories,
      rows: RemoteConfigService.instance.categoryRows,
    );
    _applied = DiscoveryFilterConfig(source: _catalog.sources.first);
    _discoverEngine = DiscoverFeedEngine(
      repository: musicRepository,
      recommendationEngine: recommendationEngine,
      musicEngine: musicRecommendationEngine,
    );
    _browser.addListener(_onBrowserChanged);
    VShotsPlaybackManager.instance.addListener(_onManagerChanged);
    currentTabIndexNotifier.addListener(_onTabChanged);
    _loadInitialBatch();
  }

  /// Coalesce browser/manager/tab listener callbacks into ONE setState per
  /// frame — without this, a single track transition can fire all three
  /// listeners, causing 3 redundant rebuilds of the entire feed subtree.
  bool _discoverUpdateScheduled = false;

  void _scheduleDiscoverRebuild() {
    if (!mounted || _discoverUpdateScheduled) return;
    _discoverUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _discoverUpdateScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _onBrowserChanged() {
    _scheduleDiscoverRebuild();
  }

  /// Auto-advance synchronization: when the manager moves to a NEW track
  /// (song completed), Discovery swipes to the matching item — the SAME
  /// currentItem source both directions converge on. Guarded so a manual
  /// swipe (which also changes the manager) never causes a loop.
  void _onManagerChanged() {
    if (!mounted || _syncingFromManager) return;
    final mgr = VShotsPlaybackManager.instance;
    if (!mgr.isOpen) return;
    final currentId = mgr.currentTrack?['id'];
    if (currentId == null) return;
    final idx = _items.indexWhere((t) => t['id'] == currentId);
    if (idx == -1 || idx == _currentIndex) return;

    // Auto-advance means the PREVIOUS card finished playing — record the
    // strongest positive signal (completed) for the engine.
    if (_currentIndex >= 0 && _currentIndex < _items.length) {
      _discoverEngine.recordSwipe(
        _items[_currentIndex],
        outcome: DiscoverSwipeOutcome.completed,
      );
      unawaited(
        LocalLibrary.instance.recordRecentlyPlayed(_items[_currentIndex]),
      );
      _cardShownAt = DateTime.now();
      _prevCard = _items[idx];
    }

    _syncingFromManager = true;
    setState(() => _currentIndex = idx);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(
        _pageForSongIndex(idx).clamp(0, _pageCount - 1),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncingFromManager = false;
    });
  }

  void _onTabChanged() {
    if (!mounted) return;
    _scheduleDiscoverRebuild();
    // Entering Discovery auto-plays the active item in the in-app browser
    // (collapsed), so the experience starts immediately without a Play tap.
    // The browser is the ONLY playback owner in Discovery. App launch stays
    // silent — this fires only on an actual tab switch to Discovery.
    if (_onDiscoverTab && _items.isNotEmpty && !_browser.isOpen) {
      unawaited(_playCurrent(expanded: false));
    }
  }

  bool get _onDiscoverTab => currentTabIndexNotifier.value == 1;

  @override
  void dispose() {
    VShotsPlaybackManager.instance.removeListener(_onManagerChanged);
    currentTabIndexNotifier.removeListener(_onTabChanged);
    // The global browser is owned by VShotsPlaybackManager — do NOT dispose
    // it here (it must survive tab switches).
    _browser.removeListener(_onBrowserChanged);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialBatch() async {
    final batch = await _fetchDiscoverBatch();
    if (!mounted) return;
    setState(() {
      _items.addAll(batch);
      _seenIds.addAll(batch.map((t) => t['id'] as String));
      _initialLoading = false;
    });
    if (batch.isNotEmpty) {
      final first = batch.first;
      final id = first['id'] as String? ?? '';
      if (id.isNotEmpty) LocalLibrary.instance.recordShownSong(id);
      _cardShownAt = DateTime.now();
      _prevCard = first;
    }
  }

  /// Play tap on a Discovery card → open the selected video in the in-app
  /// YouTube browser (reusing the single session). Discovery NEVER routes to
  /// the old global player — this is the ONLY playback path in Discovery.
  Future<void> _playCurrent({required bool expanded}) async {
    if (_items.isEmpty) return;
    final resolved = await PlaybackRouter.instance.resolveQueue(
      List.of(_items),
    );
    if (!mounted) return;
    _items
      ..clear()
      ..addAll(resolved);
    final current = _items[_currentIndex.clamp(0, _items.length - 1)];
    if (current['playbackUnavailable'] == true) {
      debugPrint(
        '[DiscoveryPlay] unavailable: ${current['unavailableReason']}',
      );
      return;
    }
    VShotsPlaybackManager.instance.playQueue(
      List.of(_items),
      _currentIndex,
      expanded: expanded,
    );
    if (mounted) setState(() {});
  }

  void _onPlayTap() {
    final track = _items.isNotEmpty ? _items[_currentIndex] : null;
    if (track == null) return;
    debugPrint('[DiscoveryPlay] id=${track['id']} url=${track['url']}');
    unawaited(_playCurrent(expanded: true));
  }

  Future<List<Map<String, dynamic>>> _fetchDiscoverBatch() async {
    final source = _applied.source;
    final query = buildDiscoveryQuery(
      source: source,
      moods: _applied.moods,
      languages: _applied.languages,
      genres: _applied.genres,
    );
    debugPrint(
      '[Discover] source="${source.label}" order="${source.order}" '
      'moods=${_applied.moods.length} query="$query"',
    );

    // "For You" (null source query) → V SHOTS DISCOVER ALGORITHM:
    // adaptive buckets (personal/trending/fresh/exploration) → Discover
    // Score ranking → fatigue/diversity guards → dynamic re-rank per swipe.
    if (source.query == null) {
      final primaryMood =
          _applied.moods.isNotEmpty ? _applied.moods.first : null;
      forYouFeedService.setMood(primaryMood?.label, primaryMood?.query ?? '');
      final biases = <String>[
        ..._applied.moods.map((m) => m.query),
        ..._applied.decades.map((d) => d.token),
        ..._applied.activities.map((a) => a.token),
      ];
      var engineConfig = RemoteConfigService.instance.discoverSettings;
      if (source.id == 'surprise_me') {
        // 🎲 Surprise Me = exploration-heavy mix (owner spec).
        engineConfig = {
          ...engineConfig,
          'weights': {
            'personal': 10,
            'trending': 25,
            'fresh': 25,
            'exploration': 40,
          },
          'enabled': {
            'personalization': false,
            'trending': true,
            'fresh': true,
            'exploration': true,
          },
        };
      }
      try {
        final music = await musicRecommendationEngine.generateForYou(
          excludeIds: _seenIds,
          count: 12,
          languages: _applied.languages.map((l) => l.token).toList(),
          moods: biases,
          regions: _applied.genres.map((g) => g.token).toList(),
        );
        if (music.isNotEmpty) return _refineForMode(source, music);
      } catch (e) {
        debugPrint('[ForYouFeed] Shared recommendation pool failed: $e');
      }
      try {
        final batch = await _discoverEngine.nextBatch(
          excludeIds: _seenIds,
          count: 12,
          languages: _applied.languages.map((l) => l.token).toList(),
          moods: biases,
          regions: _applied.genres.map((g) => g.token).toList(),
          config: engineConfig,
        );
        if (batch.isNotEmpty) return _refineForMode(source, batch);
      } catch (e) {
        debugPrint('[ForYouFeed] Discover engine failed, falling back: $e');
      }
      // Fallback: existing personalized engine, then mood-biased pool.
      try {
        final scored = await recommendationEngine.generateFeed(
          intent: FeedIntent.forYou,
          excludeIds: _seenIds,
          count: 12,
          forceRefresh: true,
        );
        if (scored.isNotEmpty) {
          return _refineForMode(
            source,
            scored.map((s) => s.track.toTrackMap()).toList(),
          );
        }
      } catch (e) {
        debugPrint('[ForYouFeed] Engine discover batch failed: $e');
      }
      return _refineForMode(
        source,
        await forYouFeedService.fetchNextBatch(excludeIds: _seenIds, count: 12),
      );
    }

    // Source/mood/language/region → exact query with the source's OWN ranking
    // order (viewCount for trending/viral/popular, date for new/latest).
    if (query.isNotEmpty) {
      final batch = await forYouFeedService.fetchQuery(
        query,
        order: source.order,
        excludeIds: _seenIds,
        count: 12,
      );
      if (batch.isNotEmpty) return _refineForMode(source, batch);
    }
    // Graceful fallback so a filter never leaves Discovery empty.
    final fallback = await forYouFeedService.fetchNextBatch(
      excludeIds: _seenIds,
      count: 12,
    );
    return _refineForMode(source, fallback);
  }

  /// Catalog gate + mode-specific ranking + diversity + already-seen penalty.
  /// Each Discover mode therefore produces a genuinely different order.
  List<Map<String, dynamic>> _refineForMode(
    DiscoverySource source,
    List<Map<String, dynamic>> tracks,
  ) {
    var refined =
        const MusicCatalogService().ingest(tracks, label: '.discover').items;
    const ranker = MusicRanker();
    refined = switch (source.id) {
      'trending' => ranker.rankTrending(refined),
      'new' || 'latest' => ranker.rankNewest(refined),
      'rising_now' || 'viral' => ranker.rankViral(refined),
      'popular' => ranker.rankPopular(refined),
      _ => refined, // For You / Surprise Me: engine order already ranked
    };
    refined = ranker.applyAlreadySeenPenalty(refined, _seenIds);
    refined = ranker.applyDiversity(refined);
    return refined;
  }

  Future<void> _maybeLoadMore() async {
    if (_isLoadingMore) return;
    if (_items.length - _currentIndex > 3) return;
    _isLoadingMore = true;

    // ENDLESS: retry a few times; if the provider returns nothing (rate-limit
    // or every candidate already seen), rotate the session seen-ids and try
    // again so the feed NEVER ends abruptly.
    try {
      List<Map<String, dynamic>> more = const [];
      for (var attempt = 0; attempt < 3 && more.isEmpty; attempt++) {
        more = await _fetchDiscoverBatch();
        if (more.isEmpty && attempt < 2) {
          _seenIds.removeWhere((_) => true);
        }
      }
      if (!mounted || more.isEmpty) return;
      final fresh = more.where((t) {
        final id = t['id'] as String? ?? '';
        return id.isNotEmpty && !_seenIds.contains(id);
      }).toList();
      if (fresh.isNotEmpty) {
        setState(() {
          _items.addAll(fresh);
          _seenIds.addAll(fresh.map((t) => t['id'] as String));
        });
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  void _onPageChanged(int page) {
    if (_syncingFromManager || _items.isEmpty) return;
    if (_isAdPage(page)) return;
    final songIndex = _songIndexForPage(page);
    if (songIndex < 0 || songIndex >= _items.length) return;
    if (songIndex == _currentIndex) return;

    final previousIndex = _currentIndex;
    if (previousIndex >= 0 && previousIndex < _items.length) {
      final previous = _items[previousIndex];
      final elapsed = _cardShownAt == null
          ? null
          : DateTime.now().difference(_cardShownAt!).inMilliseconds;
      final durationMs = (previous['duration'] as num?)?.toDouble();
      final positionMs = VShotsPlaybackManager.instance.position.inMilliseconds;
      final completed = durationMs != null &&
          durationMs > 0 &&
          positionMs >= durationMs * 0.85;
      final outcome = completed
          ? DiscoverSwipeOutcome.completed
          : elapsed != null && elapsed < 3000
              ? DiscoverSwipeOutcome.skipped
              : DiscoverSwipeOutcome.swiped;
      _discoverEngine.recordSwipe(previous, outcome: outcome);
      unawaited(LocalLibrary.instance.recordRecentlyPlayed(previous));
    }

    setState(() => _currentIndex = songIndex);
    final current = _items[songIndex];
    final id = current['id'] as String? ?? '';
    if (id.isNotEmpty) LocalLibrary.instance.recordShownSong(id);
    _cardShownAt = DateTime.now();
    _prevCard = current;
    unawaited(_playCurrent(expanded: false));
    unawaited(_maybeLoadMore());
  }

  Future<void> _showExplore() async {
    final draft = await showModalBottomSheet<DiscoveryFilterConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DiscoveryExploreSheet(
        catalog: _catalog,
        initial: _applied,
      ),
    );
    if (!mounted || draft == null) return;
    setState(() {
      _applied = draft;
      _items.clear();
      _seenIds.clear();
      _currentIndex = 0;
      _initialLoading = true;
    });
    await _loadInitialBatch();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      // Swipe-deck SKELETON (matches the real card's geometry: square cover,
      // title/artist lines, action row) — perceived load is far faster than a
      // bare spinner, and there is no layout jump when content arrives.
      return const Scaffold(
        backgroundColor: Colors.black,
        body: _ForYouSkeletonCard(),
      );
    }

    if (_items.isEmpty) {
      // Friendlier, consistent empty state: soft gradient glyph (no dead
      // icon), real cause, and a prominent retry. Same dark backdrop as the
      // feed so the transition never flashes a different background.
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.28),
                        AppColors.accent.withValues(alpha: 0.18),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    size: 40,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Nothing playing yet',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Recommendations will appear in a moment.\nCheck your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _initialLoading = true);
                    _loadInitialBatch();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try again'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _pageCount,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, page) {
              if (_isAdPage(page)) {
                return DiscoverySwipeNativeAdPage(
                  key: ValueKey('discover-ad-$page'),
                );
              }
              final index = _songIndexForPage(page);
              return _ForYouCard(
                key: ValueKey(_items[index]['id']),
                track: _items[index],
                onPlay: _onPlayTap,
                onNext: () {
                  if (_pageController.hasClients) {
                    final next = (_pageController.page?.round() ?? page) + 1;
                    if (next < _pageCount) {
                      _pageController.animateToPage(
                        next,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  }
                },
                onMore: () => showMoreOptionsSheet(context, _items[index]),
                onAddToPlaylist: () =>
                    showAddToPlaylistSheet(context, _items[index]),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 14,
            child: _ExploreButton(onTap: _showExplore),
          ),
        ],
      ),
    );
  }
}

/// Loading skeleton mirroring the real swipe-card geometry: square cover,
/// title/artist lines and the action row. Prevents the layout jump a bare
/// spinner causes when the first batch of recommendations lands.
class _ForYouSkeletonCard extends StatelessWidget {
  const _ForYouSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final coverSide = (MediaQuery.of(context).size.width * 0.70).clamp(
      200.0,
      330.0,
    );
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingSkeleton(
            width: coverSide,
            height: coverSide,
            borderRadius: 20,
          ),
          const SizedBox(height: 22),
          const LoadingSkeleton(width: 210, height: 20, borderRadius: 8),
          const SizedBox(height: 10),
          const LoadingSkeleton(width: 130, height: 14, borderRadius: 7),
          const SizedBox(height: 26),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingSkeleton(width: 46, height: 46, shape: BoxShape.circle),
              SizedBox(width: 26),
              LoadingSkeleton(width: 64, height: 64, shape: BoxShape.circle),
              SizedBox(width: 26),
              LoadingSkeleton(width: 46, height: 46, shape: BoxShape.circle),
            ],
          ),
        ],
      ),
    );
  }
}

class _ForYouCard extends StatefulWidget {
  const _ForYouCard({
    super.key,
    required this.track,
    required this.onPlay,
    required this.onNext,
    required this.onMore,
    required this.onAddToPlaylist,
  });

  final Map<String, dynamic> track;
  final VoidCallback onPlay;
  final VoidCallback onNext;
  final VoidCallback onMore;
  final VoidCallback onAddToPlaylist;

  @override
  State<_ForYouCard> createState() => _ForYouCardState();
}

class _ForYouCardState extends State<_ForYouCard> {
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _liked = LocalLibrary.instance.isLiked(widget.track);
  }

  @override
  void didUpdateWidget(covariant _ForYouCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track['id'] != widget.track['id']) {
      _liked = LocalLibrary.instance.isLiked(widget.track);
    }
  }

  Future<void> _toggleLike() async {
    final next = !_liked;
    setState(() => _liked = next);
    await LocalLibrary.instance.toggleLike(widget.track);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.track['thumbnail'] as String? ??
        widget.track['image'] as String? ??
        '';
    final title = widget.track['title'] as String? ?? 'Unknown';
    final artist = widget.track['artist'] as String? ?? '';
    final duration = widget.track['duration'] as num?;
    final position = VShotsPlaybackManager.instance.position;
    final total = duration == null
        ? Duration.zero
        : Duration(milliseconds: duration.toInt());
    final progress = total.inMilliseconds <= 0
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onPlay,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AppImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (artist.isNotEmpty) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Like',
                    onPressed: _toggleLike,
                    icon: Icon(
                      _liked ? Icons.favorite : Icons.favorite_border,
                      color: _liked ? Colors.redAccent : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  FloatingActionButton(
                    heroTag: 'discover-play-${widget.track['id']}',
                    onPressed: widget.onPlay,
                    child: Icon(
                      VShotsPlaybackManager.instance.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                  ),
                  const SizedBox(width: 14),
                  IconButton(
                    tooltip: 'Next',
                    onPressed: widget.onNext,
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'More',
                    onPressed: widget.onMore,
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: widget.onAddToPlaylist,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Add to playlist'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreButton extends StatelessWidget {
  const _ExploreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text(
                'Explore',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiscoveryExploreSheet extends StatefulWidget {
  const DiscoveryExploreSheet({
    super.key,
    required this.catalog,
    required this.initial,
  });

  final DiscoveryFilterCatalog catalog;
  final DiscoveryFilterConfig initial;

  @override
  State<DiscoveryExploreSheet> createState() => _DiscoveryExploreSheetState();
}

class _DiscoveryExploreSheetState extends State<DiscoveryExploreSheet> {
  late DiscoveryFilterConfig _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  void _apply() => Navigator.of(context).pop(_draft);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.48,
      maxChildSize: 0.94,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF151515),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Explore',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _draft = DiscoveryFilterConfig(
                        source: widget.catalog.sources.first,
                      ),
                    ),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Choose a vibe, then Apply to refresh the feed.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              _SectionTitle(title: 'Feed'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.catalog.sources.map((source) {
                  final selected = source.id == _draft.source.id;
                  return ChoiceChip(
                    label: Text(source.label),
                    selected: selected,
                    onSelected: (_) => setState(
                      () => _draft = _draft.copyWith(source: source),
                    ),
                  );
                }).toList(),
              ),
              if (widget.catalog.moods.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionTitle(title: 'Mood'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.catalog.moods.map((mood) {
                    final selected = _draft.moods.any((m) => m.id == mood.id);
                    return FilterChip(
                      label: Text(mood.label),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          final moods = [..._draft.moods];
                          if (value) {
                            moods.add(mood);
                          } else {
                            moods.removeWhere((m) => m.id == mood.id);
                          }
                          _draft = _draft.copyWith(moods: moods);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              if (widget.catalog.languages.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionTitle(title: 'Language'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.catalog.languages.map((language) {
                    final selected =
                        _draft.languages.any((l) => l.id == language.id);
                    return FilterChip(
                      label: Text(language.label),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          final languages = [..._draft.languages];
                          if (value) {
                            languages.add(language);
                          } else {
                            languages.removeWhere(
                              (l) => l.id == language.id,
                            );
                          }
                          _draft = _draft.copyWith(languages: languages);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              if (widget.catalog.genres.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionTitle(title: 'Genre'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.catalog.genres.map((genre) {
                    final selected = _draft.genres.any((g) => g.id == genre.id);
                    return FilterChip(
                      label: Text(genre.label),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          final genres = [..._draft.genres];
                          if (value) {
                            genres.add(genre);
                          } else {
                            genres.removeWhere((g) => g.id == genre.id);
                          }
                          _draft = _draft.copyWith(genres: genres);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              if (widget.catalog.decades.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionTitle(title: 'Era'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.catalog.decades.map((decade) {
                    final selected = _draft.decades.any((d) => d.id == decade.id);
                    return FilterChip(
                      label: Text(decade.label),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          final decades = [..._draft.decades];
                          if (value) {
                            decades.add(decade);
                          } else {
                            decades.removeWhere((d) => d.id == decade.id);
                          }
                          _draft = _draft.copyWith(decades: decades);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              if (widget.catalog.activities.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionTitle(title: 'Activity'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.catalog.activities.map((activity) {
                    final selected =
                        _draft.activities.any((a) => a.id == activity.id);
                    return FilterChip(
                      label: Text(activity.label),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          final activities = [..._draft.activities];
                          if (value) {
                            activities.add(activity);
                          } else {
                            activities.removeWhere(
                              (a) => a.id == activity.id,
                            );
                          }
                          _draft = _draft.copyWith(activities: activities);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 28),
              AppButton(
                label: 'Apply',
                onPressed: _apply,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// V Shots — "For You" Discover Feed (Reels-Style Swipe Playback & Vibe Picker)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ads/ad_config.dart';
import '../../core/ads/native_ad_widget.dart';
import '../../core/config/discovery_filters.dart';
import '../../core/music/music_catalog_service.dart';
import '../../core/music/music_ranker.dart';
import '../../core/motion/motion.dart';
import '../../core/recommendation/feed_intent.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/utils/youtube_url.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_image.dart';
import '../../shared/widgets/comment_sheet.dart';
import '../../main.dart'
    show
        currentTabIndexNotifier,
        forYouFeedService,
        playbackSignalTracker,
        recommendationEngine,
        showMoreOptionsSheet,
        showAddToPlaylistSheet;
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

  // ── Discovery ad page mapping (Section 7) ──────────────────────────────
  // The feed is a vertical PageView. Every [AdConfig.discoveryAdEvery] organic
  // videos we insert one clearly-separated ad page, mapping a PageView page
  // index to a song index via [_songIndexForPage]; ad pages never touch the
  // browser. Ads are only inserted when ads are enabled (production config).
  bool get _adsEnabled => AdConfig.adsEnabled;

  /// Number of ad pages inserted for [songCount] songs (one after every
  /// [AdConfig.discoveryAdEvery] songs).
  int _adCountFor(int songCount) => songCount ~/ AdConfig.discoveryAdEvery;

  /// Total PageView pages = songs + inserted ad pages.
  int get _pageCount => _items.length + _adCountFor(_items.length);

  /// Is the given PageView page an ad page? Ad pages appear right after every
  /// [AdConfig.discoveryAdEvery]-th song: at page = adEvery, 2*adEvery+1, ...,
  /// i.e. page where (page - adEvery) % (adEvery+1) == 0 (never the first page).
  bool _isAdPage(int page) {
    if (!_adsEnabled) return false;
    if (page == 0) return false;
    return (page - AdConfig.discoveryAdEvery) %
            (AdConfig.discoveryAdEvery + 1) ==
        0;
  }

  /// Maps a PageView page index to the underlying song index, skipping ad pages.
  int _songIndexForPage(int page) {
    if (!_adsEnabled) return page;
    final adsBefore = page ~/ (AdConfig.discoveryAdEvery + 1);
    return page - adsBefore;
  }

  /// The APPLIED Discovery filter configuration — the only state the feed
  /// actually fetches from. The Explore sheet works on a DRAFT copy and only
  /// commits here on APPLY (see _showExplore).
  DiscoveryFilterConfig _applied = DiscoveryFilterConfig.initial;

  @override
  void initState() {
    super.initState();
    _browser.addListener(_onBrowserChanged);
    currentTabIndexNotifier.addListener(_onTabChanged);
    _loadInitialBatch();
  }

  void _onBrowserChanged() {
    if (mounted) setState(() {});
  }

  void _onTabChanged() {
    if (!mounted) return;
    setState(() {});
    // Entering Discovery auto-plays the active item in the in-app browser
    // (collapsed), so the experience starts immediately without a Play tap.
    // The browser is the ONLY playback owner in Discovery. App launch stays
    // silent — this fires only on an actual tab switch to Discovery.
    if (_onDiscoverTab && _items.isNotEmpty && !_browser.isOpen) {
      VShotsPlaybackManager.instance.playQueue(_items, _currentIndex);
    }
  }

  bool get _onDiscoverTab => currentTabIndexNotifier.value == 1;

  @override
  void dispose() {
    currentTabIndexNotifier.removeListener(_onTabChanged);
    // The global browser is owned by VShotsPlaybackManager — do NOT dispose
    // it here (it must survive tab switches).
    _browser.removeListener(_onBrowserChanged);
    _pageController.dispose();
    super.dispose();
  }

  /// Animate to a PageView [page], clamping and load-more-triggering so the
  /// feed never runs out. Callers pass a PAGE index (use [_pageForSongIndex]).
  void _goToPage(int page) {
    if (!mounted) return;
    if (page >= _pageCount) {
      // At the end: fetch more, then advance if new items arrived.
      unawaited(_fetchMoreThenJump(page));
      return;
    }
    if (page < 0) page = 0;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
    unawaited(_maybeLoadMore());
  }

  Future<void> _fetchMoreThenJump(int page) async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    final batch = await _fetchDiscoverBatch();
    _isLoadingMore = false;
    if (!mounted) return;
    if (batch.isNotEmpty) {
      setState(() {
        _items.addAll(batch);
        _seenIds.addAll(batch.map((t) => t['id'] as String));
      });
      if (page < _pageCount) {
        unawaited(
          _pageController.animateToPage(
            page,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          ),
        );
      }
    }
  }

  Future<void> _loadInitialBatch() async {
    final batch = await _fetchDiscoverBatch();
    if (!mounted) return;
    setState(() {
      _items.addAll(batch);
      _seenIds.addAll(batch.map((t) => t['id'] as String));
      _initialLoading = false;
    });
  }

  /// Play tap on a Discovery card → open the selected video in the in-app
  /// YouTube browser (reusing the single session). Discovery NEVER routes to
  /// the old global player — this is the ONLY playback path in Discovery.
  void _onPlayTap() {
    final track = _items.isNotEmpty ? _items[_currentIndex] : null;
    if (track == null) return;
    final videoId = (track['id'] as String?) ?? '';
    debugPrint(
      '[DiscoveryPlay] videoId=$videoId url=${youtubeWatchUrl(videoId)}',
    );
    // The old global player is intentionally bypassed for Discovery — the
    // in-app browser owns playback. The single playback coordinator pauses the
    // global IFrame (in case another tab was playing) so audio never doubles.
    debugPrint('[DiscoveryPlay] OLD_PLAYER_CALL_BLOCKED (routing to browser)');
    VShotsPlaybackManager.instance.playQueue(List.of(_items), _currentIndex);
    setState(() {});
  }

  Future<List<Map<String, dynamic>>> _fetchDiscoverBatch() async {
    final source = _applied.source;
    final query = buildDiscoveryQuery(
      source: source,
      moods: _applied.moods,
      languages: _applied.languages,
      regions: _applied.regions,
    );
    debugPrint(
      '[Discover] source="${source.label}" order="${source.order}" '
      'moods=${_applied.moods.length} query="$query"',
    );

    // "For You" (null source query) → personalized recommendation engine.
    // forceRefresh so APPLY genuinely reshapes the feed (never the stale
    // cached forYou feed).
    if (source.query == null) {
      final primaryMood =
          _applied.moods.isNotEmpty ? _applied.moods.first : null;
      forYouFeedService.setMood(primaryMood?.label, primaryMood?.query ?? '');
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
      // Mood/language/region-biased fallback pool.
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
      'viral' => ranker.rankViral(refined),
      'popular' => ranker.rankPopular(refined),
      _ => refined, // For You: engine order already personalized
    };
    refined = ranker.applyAlreadySeenPenalty(refined, _seenIds);
    refined = ranker.applyDiversity(refined);
    return refined;
  }

  Future<void> _maybeLoadMore() async {
    if (_isLoadingMore) return;
    if (_items.length - _currentIndex > 3) return;
    _isLoadingMore = true;
    final batch = await _fetchDiscoverBatch();
    if (mounted) {
      setState(() {
        _items.addAll(batch);
        _seenIds.addAll(batch.map((t) => t['id'] as String));
      });
    }
    _isLoadingMore = false;
  }

  void _onPageChanged(int page) {
    // On an ad page nothing changes — the current card stays as-is.
    if (_isAdPage(page)) {
      setState(() {});
      return;
    }
    final index = _songIndexForPage(page);
    if (index < 0 || index >= _items.length) return;
    unawaited(HapticFeedback.selectionClick());
    final track = _items[index];
    setState(() => _currentIndex = index);

    // Swiping Discovery moves playback to the new active item: reuse the ONE
    // global in-app browser (switch URL + autoplay) — one playback engine.
    VShotsPlaybackManager.instance.playQueue(List.of(_items), index);

    unawaited(LocalLibrary.instance.recordRecentlyPlayed(track));
    playbackSignalTracker.onTrackStarted(track);
    unawaited(_maybeLoadMore());
  }

  /// Opens the Explore panel: the full filter hierarchy (DISCOVER / MOODS /
  /// LANGUAGE / REGION) in a premium bottom sheet — never permanently visible
  /// across the top of Discovery.
  void _showExplore() async {
    final committed = await showModalBottomSheet<DiscoveryFilterConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExploreSheet(initial: _applied),
    );
    // null → dismissed WITHOUT APPLY (X / Done / tap-outside): discard draft,
    // keep the previously applied configuration.
    if (committed == null) return;
    _commitFilters(committed);
  }

  /// Commits a config (from APPLY): updates the applied state and rebuilds
  /// the feed exactly once. Chip taps never call this.
  void _commitFilters(DiscoveryFilterConfig config) {
    if (!mounted) return;
    if (_applied.matches(config)) return;
    _applied = config;
    setState(() {
      _initialLoading = true;
      _items.clear();
      _seenIds.clear();
      _currentIndex = 0;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _loadInitialBatch();
  }

  /// Compact summary for the top pill (e.g. "For You", "Romantic · Hindi").
  String _filterSummary() => discoveryFilterSummary(
        source: _applied.source,
        moods: _applied.moods,
        languages: _applied.languages,
        regions: _applied.regions,
      );

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryLight),
        ),
      );
    }

    if (_items.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: AppColors.textSubtle),
              const SizedBox(height: 12),
              const Text(
                'Could not load recommendations',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _initialLoading = true);
                  _loadInitialBatch();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Vertical Reel-Style Swipe PageView. Each card renders its own
          // artwork backdrop (the old full-screen IFrame player is gone from
          // Discovery — playback happens in the in-app browser only). Bottom
          // padding is added while the browser mini player is visible so feed
          // content is never hidden underneath it.
          AnimatedPadding(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: _browser.isOpen ? 88 : 0),
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              itemCount: _pageCount,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, page) {
                final isCurrent = page == _currentIndex;
                // Ad page: a clearly-separated, labeled native ad card. It never
                // touches the YouTube player (which keeps playing the song that
                // was active before/after), so it can't violate YouTube policy.
                if (_isAdPage(page)) {
                  return RepaintBoundary(
                    child: _ForYouAdCard(onSkip: () => _goToPage(page + 1)),
                  );
                }
                final songIndex = _songIndexForPage(page);
                final track = _items[songIndex];
                return RepaintBoundary(
                  child: _ForYouCard(
                    track: track,
                    isActive: isCurrent,
                    isPlaying: false,
                    onPlayPauseToggle: _onPlayTap,
                    onNotInterested: () => _handleNotInterested(songIndex),
                    onDoubleTapLike: () => _handleDoubleTapLike(track),
                    onSkipPrevious: page > 0
                        ? () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            )
                        : null,
                    onSkipNext: page < _pageCount - 1
                        ? () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            )
                        : null,
                  ),
                );
              },
            ),
          ),

          // Top filter hierarchy — two organized sections:
          //   DISCOVER (source) + a compact Filters entry, then MOOD.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    // Compact summary pill — the ONLY persistent filter
                    // control. Tapping opens the Explore panel.
                    GestureDetector(
                      onTap: _showExplore,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.6,
                            ),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _applied.source.icon,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _filterSummary(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.accent,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showExplore,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 15,
                              color: Colors.white70,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Explore',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDoubleTapLike(Map<String, dynamic> track) {
    final id = track['id'] as String? ?? '';
    if (id.isEmpty) return;
    final wasLiked = LocalLibrary.instance.isLiked(id);
    if (!wasLiked) {
      LocalLibrary.instance.toggleLiked(track);
      playbackSignalTracker.onLiked(track);
    }
  }

  void _handleNotInterested(int index) {
    final artist = _items[index]['artist'] as String? ?? '';
    forYouFeedService.markNotInterested(artist);
    playbackSignalTracker.onTrackEnded(completed: false);
    if (index < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }
}

/// Explore panel: the full Discovery filter hierarchy in a premium bottom
/// sheet. The top of Discovery stays clean — only the compact summary pill +
/// Explore control are persistent; everything else lives here.
class _ExploreSheet extends StatefulWidget {
  const _ExploreSheet({required this.initial});

  final DiscoveryFilterConfig initial;

  @override
  State<_ExploreSheet> createState() => _ExploreSheetState();
}

class _ExploreSheetState extends State<_ExploreSheet> {
  // DRAFT state — chip taps mutate ONLY this; the live feed is untouched
  // until APPLY is pressed (then this draft is returned to _showExplore,
  // which commits it and refreshes the feed).
  late DiscoverySource _draftSource;
  late List<DiscoveryMood> _draftMoods;
  late List<DiscoveryFilterOption> _draftLanguages;
  late List<DiscoveryFilterOption> _draftRegions;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _draftSource = i.source;
    _draftMoods = List.of(i.moods);
    _draftLanguages = List.of(i.languages);
    _draftRegions = List.of(i.regions);
  }

  DiscoveryFilterConfig get _draft => DiscoveryFilterConfig(
        source: _draftSource,
        moods: _draftMoods,
        languages: _draftLanguages,
        regions: _draftRegions,
      );

  bool get _hasChanges => !_draft.matches(widget.initial);

  void _toggleMood(DiscoveryMood mood) {
    setState(() {
      _draftMoods.any((m) => m.id == mood.id)
          ? _draftMoods.removeWhere((m) => m.id == mood.id)
          : _draftMoods.add(mood);
    });
  }

  void _toggleLanguage(DiscoveryFilterOption lang) {
    setState(() {
      _draftLanguages.any((l) => l.id == lang.id)
          ? _draftLanguages.removeWhere((l) => l.id == lang.id)
          : _draftLanguages.add(lang);
    });
  }

  void _toggleRegion(DiscoveryFilterOption region) {
    setState(() {
      _draftRegions.any((r) => r.id == region.id)
          ? _draftRegions.removeWhere((r) => r.id == region.id)
          : _draftRegions.add(region);
    });
  }

  void _clear() {
    setState(() {
      _draftMoods.clear();
      _draftLanguages.clear();
      _draftRegions.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appliedLabel = discoveryFilterSummary(
      source: widget.initial.source,
      moods: widget.initial.moods,
      languages: widget.initial.languages,
      regions: widget.initial.regions,
    );
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Explore',
                    style: TextStyle(
                      color: AppColors.textMain,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _clear,
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        // X → discard draft (no APPLY): return null.
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _sectionLabel('Discover'),
              _chipWrap(
                kDiscoverySources
                    .map(
                      (s) => (
                        label: s.label,
                        icon: s.icon,
                        selected: s.id == _draftSource.id,
                        onTap: () => setState(() => _draftSource = s),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              _sectionLabel('Moods'),
              _chipWrap(
                kDiscoveryMoods
                    .map(
                      (m) => (
                        label: m.label,
                        icon: m.icon,
                        selected: _draftMoods.any((x) => x.id == m.id),
                        onTap: () => _toggleMood(m),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              _sectionLabel('Language'),
              _chipWrap(
                kDiscoveryLanguages
                    .map(
                      (l) => (
                        label: l.label,
                        icon: '',
                        selected: _draftLanguages.any((x) => x.id == l.id),
                        onTap: () => _toggleLanguage(l),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              _sectionLabel('Region / Culture'),
              _chipWrap(
                kDiscoveryRegions
                    .map(
                      (r) => (
                        label: r.label,
                        icon: '',
                        selected: _draftRegions.any((x) => x.id == r.id),
                        onTap: () => _toggleRegion(r),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              // ── APPLY / DONE ─────────────────────────────────────────
              if (_hasChanges)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Applied: $appliedLabel',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'Apply',
                  icon: Icons.check_rounded,
                  isFullWidth: true,
                  size: AppButtonSize.large,
                  // APPLY commits the draft and returns it; the sheet STAYS
                  // open so the user can then press DONE.
                  onPressed: () => Navigator.pop(context, _draft),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'Done',
                  variant: AppButtonVariant.secondary,
                  isFullWidth: true,
                  size: AppButtonSize.medium,
                  // DONE closes the sheet without committing anything new.
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textMain,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _chipWrap(
    List<({String label, String icon, bool selected, VoidCallback onTap})>
        items,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return GestureDetector(
          onTap: item.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: item.selected ? AppColors.primaryGradient : null,
              color: item.selected ? null : AppColors.surface2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: item.selected ? Colors.transparent : AppColors.border,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.icon.isNotEmpty) ...[
                  Text(item.icon, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                ],
                Text(
                  item.label,
                  style: TextStyle(
                    color: item.selected ? Colors.white : AppColors.textMain,
                    fontSize: 13,
                    fontWeight:
                        item.selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ForYouAdCard extends StatelessWidget {
  const _ForYouAdCard({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Ad · Sponsored',
                style: TextStyle(
                  color: AppColors.hotPink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Advertisement',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'This is an advertisement, not a V Shots track.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),
              const NativeAdWidget(height: 180),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onSkip,
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Continue'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(
                    color: AppColors.accent.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForYouCard extends StatefulWidget {
  const _ForYouCard({
    required this.track,
    required this.isActive,
    required this.isPlaying,
    required this.onPlayPauseToggle,
    required this.onNotInterested,
    required this.onDoubleTapLike,
    this.onSkipPrevious,
    this.onSkipNext,
  });

  final Map<String, dynamic> track;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onPlayPauseToggle;
  final VoidCallback onNotInterested;
  final VoidCallback onDoubleTapLike;
  final VoidCallback? onSkipPrevious;
  final VoidCallback? onSkipNext;

  @override
  State<_ForYouCard> createState() => _ForYouCardState();
}

class _ForYouCardState extends State<_ForYouCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _heartCtl;
  Animation<double>? _heartScale;
  Animation<double>? _heartOpacity;

  /// Slow Ken Burns controller for the animated blurred backdrop (only runs
  /// while this card is the active one).
  late final AnimationController _bgCtl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 11),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _bgCtl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ForYouCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_bgCtl.isAnimating) {
      _bgCtl.repeat(reverse: true);
    } else if (!widget.isActive && _bgCtl.isAnimating) {
      _bgCtl.stop();
    }
  }

  @override
  void dispose() {
    _bgCtl.dispose();
    _heartCtl?.dispose();
    super.dispose();
  }

  void _pulseHeart() {
    final ctl = _heartCtl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _heartScale = CurvedAnimation(parent: ctl, curve: Curves.easeOutBack);
    _heartOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: ctl, curve: const Interval(0.4, 1.0)));
    unawaited(HapticFeedback.mediumImpact());
    ctl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final isActive = widget.isActive;
    final isPlaying = widget.isPlaying;
    final onPlayPauseToggle = widget.onPlayPauseToggle;
    final onNotInterested = widget.onNotInterested;
    final onSkipPrevious = widget.onSkipPrevious;
    final onSkipNext = widget.onSkipNext;
    final title = (track['title'] as String?) ?? '';
    final artist = (track['artist'] as String?) ?? '';
    final trackId = track['id'] as String? ?? '';
    final artwork = (track['artwork'] as String?) ?? '';
    // Square cover side: scales with screen, capped for large phones.
    final coverSide = (MediaQuery.of(context).size.width * 0.70).clamp(
      200.0,
      330.0,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Cinematic ANIMATED blurred-artwork backdrop — a slow Ken Burns
        // (pan + zoom) with two drifting ambient glows. Runs only while the
        // card is active; never resized/detached (pure visual layer).
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _bgCtl,
              builder: (context, _) {
                final t = _bgCtl.value;
                final scale = 1.12 + 0.16 * t;
                final dx = (t - 0.5) * 34;
                final dy = (t - 0.5) * -20;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (artwork.isNotEmpty)
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                        child: Transform.translate(
                          offset: Offset(dx, dy),
                          child: Transform.scale(
                            scale: scale,
                            child: AppImage(artwork, fit: BoxFit.cover),
                          ),
                        ),
                      )
                    else
                      Container(color: const Color(0xFF0A0D16)),
                    // Drifting ambient glow (primary → hot pink).
                    Align(
                      alignment: Alignment(0.6 - t, 0.15),
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.26),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment(-0.5 + t, -0.28),
                      child: Container(
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.hotPink.withValues(alpha: 0.20),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        // Dark scrim keeps text readable over the animated backdrop.
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.30),
                  Colors.black.withValues(alpha: 0.75),
                ],
                stops: const [0.0, 0.35, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // Tap-to-play layer (active card, cued): transparent, so the square
        // cover stays the visual hero while the whole screen is tappable.
        if (isActive && !isPlaying)
          Positioned.fill(
            child: GestureDetector(
              onTap: onPlayPauseToggle,
              behavior: HitTestBehavior.opaque,
            ),
          ),

        // ── CENTER SQUARE COVER ART ─────────────────────────────────────
        // The sharp, square cover of the playing song — the Discovery hero.
        // Crossfades + scales in when the swipe changes the track.
        Positioned.fill(
          child: IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: const Alignment(0, -0.12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 340),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.94,
                        end: 1.0,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Container(
                    key: ValueKey('cover-$trackId'),
                    width: coverSide,
                    height: coverSide,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 40,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          blurRadius: 30,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (artwork.isNotEmpty)
                            AppImage(artwork, fit: BoxFit.cover)
                          else
                            Container(color: AppColors.surface),
                          // Small play affordance on the cover.
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.primaryGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.45,
                                    ),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Double-tap like heart burst (premium). Triggered from the safe
        // metadata region BELOW the video, never from the YouTube surface.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _heartCtl ?? const AlwaysStoppedAnimation(1.0),
              builder: (context, _) {
                final ctl = _heartCtl;
                if (ctl == null || !ctl.isAnimating) {
                  return const SizedBox.shrink();
                }
                return Center(
                  child: Transform.scale(
                    scale: _heartScale?.value ?? 1.0,
                    child: Opacity(
                      opacity: _heartOpacity?.value ?? 0.0,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.35),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.hotPink.withValues(alpha: 0.5),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.hotPink,
                          size: 44,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Bottom metadata + play controls (safe double-tap region, BELOW the
        // YouTube player — double-tap here to like without hijacking the
        // YouTube player's own controls).
        GestureDetector(
          onDoubleTap: () {
            unawaited(HapticFeedback.mediumImpact());
            widget.onDoubleTapLike();
            _pulseHeart();
          },
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artist,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_circle_filled_rounded,
                            size: 14,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Powered by YouTube',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Playback Controls Row: Prev, Play/Pause Toggle, Next
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                          onPressed: onSkipPrevious,
                        ),
                        const SizedBox(width: 20),

                        // In-Card Play/Pause Toggle
                        GestureDetector(
                          onTap: onPlayPauseToggle,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),

                        IconButton(
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                          onPressed: onSkipNext,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Right Side Action Buttons (Like, Comments, Playlist, More).
        // Sits ABOVE the player (last Stack child = highest z-index) inside a
        // translucent pill so the icons stay visible regardless of video
        // brightness/color (Section 5). Never overlaid on the YouTube player
        // itself — it sits beside/below the video frame.
        Positioned(
          right: 16,
          bottom: 150,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatefulBuilder(
                  builder: (context, setLikeState) {
                    final isLiked = LocalLibrary.instance.isLiked(trackId);
                    return IconButton(
                      icon: LikePop(
                        liked: isLiked,
                        child: Icon(
                          isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isLiked ? AppColors.hotPink : Colors.white,
                          size: 32,
                        ),
                      ),
                      onPressed: () {
                        unawaited(HapticFeedback.lightImpact());
                        final wasLiked = isLiked;
                        LocalLibrary.instance.toggleLiked(track).then((_) {
                          if (wasLiked) {
                            playbackSignalTracker.onUnliked(track);
                          } else {
                            playbackSignalTracker.onLiked(track);
                          }
                          setLikeState(() {});
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                IconButton(
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    unawaited(HapticFeedback.lightImpact());
                    CommentSheet.show(
                      context,
                      shotId: trackId,
                      commentCount: 18,
                    );
                  },
                ),
                const SizedBox(height: 12),
                IconButton(
                  icon: const Icon(
                    Icons.playlist_add_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () {
                    unawaited(HapticFeedback.lightImpact());
                    showAddToPlaylistSheet(context, track);
                  },
                ),
                const SizedBox(height: 12),
                IconButton(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () {
                    unawaited(HapticFeedback.lightImpact());
                    showMoreOptionsSheet(
                      context,
                      track,
                      onNotInterested: onNotInterested,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

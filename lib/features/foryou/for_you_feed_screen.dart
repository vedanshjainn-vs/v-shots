// ═════════════════════════════════════════════════════════════════════════════
// V Shots — "For You" Discover Feed (Reels-Style Swipe Playback & Vibe Picker)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/ads/ad_config.dart';
import '../../core/ads/native_ad_widget.dart';
import '../../core/config/discovery_categories.dart';
import '../../core/motion/motion.dart';
import '../../core/remote_config/remote_config_service.dart';
import '../../core/recommendation/feed_intent.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';
import '../../shared/widgets/comment_sheet.dart';
import '../../main.dart'
    show
        currentTrack,
        currentTrackNotifier,
        currentQueue,
        currentQueueIndex,
        currentTabIndexNotifier,
        ensureGlobalPlayer,
        forYouFeedService,
        globalVideoEndedNotifier,
        globalYtController,
        playbackSignalTracker,
        recommendationEngine,
        showMoreOptionsSheet,
        showAddToPlaylistSheet;

class ForYouFeedScreen extends StatefulWidget {
  const ForYouFeedScreen({super.key});

  @override
  State<ForYouFeedScreen> createState() => _ForYouFeedScreenState();
}

class _ForYouFeedScreenState extends State<ForYouFeedScreen> {
  final PageController _pageController = PageController();

  final List<Map<String, dynamic>> _items = [];
  final Set<String> _seenIds = {};

  /// Phase 9 duplicate/artist-repetition prevention: track seen artists and
  /// enforce a max of 2 consecutive tracks from the same artist.
  final Set<String> _seenArtists = {};
  static const int _maxConsecutiveArtist = 2;
  String? _lastArtist;
  int _lastArtistRun = 0;

  /// Filters a batch, rejecting duplicate video IDs and enforcing the
  /// consecutive-artist limit so the feed doesn't repeat the same artist.
  List<Map<String, dynamic>> _dedupeBatch(List<Map<String, dynamic>> batch) {
    final out = <Map<String, dynamic>>[];
    for (final t in batch) {
      final id = t['id'] as String? ?? '';
      final artist = t['artist'] as String? ?? '';
      if (id.isEmpty || _seenIds.contains(id)) continue;
      if (artist == _lastArtist && _lastArtistRun >= _maxConsecutiveArtist) {
        continue; // reject repeated artist back-to-back
      }
      _seenIds.add(id);
      if (artist.isNotEmpty) _seenArtists.add(artist);
      if (artist == _lastArtist) {
        _lastArtistRun++;
      } else {
        _lastArtist = artist;
        _lastArtistRun = 1;
      }
      out.add(t);
    }
    return out;
  }

  int _currentIndex = 0;
  bool _isLoadingMore = false;
  bool _initialLoading = true;

  /// True when the Discover tab was the active tab on the last tab change.
  /// Used to detect re-entry so every fresh Discovery session starts from a
  /// video the user has NOT recently seen (new-video-every-open requirement).
  bool _wasOnDiscoverTab = false;

  // ── Discovery ad page mapping (Section 7) ──────────────────────────────
  // The feed is a vertical PageView. Every [AdConfig.discoveryAdEvery] organic
  // videos we insert one clearly-separated ad page. To keep the video index
  // math (currentQueue, auto-advance, skip) intact, we map a PageView page
  // index to a song index via [_songIndexForPage]; ad pages never touch the
  // player. Ads are only inserted when ads are enabled (production config).
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

  /// Maps a song index to its PageView page index (accounting for ads).
  int _pageForSongIndex(int songIndex) {
    if (!_adsEnabled) return songIndex;
    return songIndex + (songIndex ~/ AdConfig.discoveryAdEvery);
  }

  /// The single source of truth for the currently selected Discovery category.
  /// Both the displayed label AND the active fetch query come from this one
  /// object (Section 1, point 1) — there is no separate "label" vs "fetch"
  /// variable that can drift apart.
  DiscoveryCategory? _activeCategory;

  String? _activeVideoId;
  bool _isPlaying = false;

  DiscoveryCategory get _defaultCategory =>
      RemoteConfigService.instance.categories.isNotEmpty
          ? RemoteConfigService.instance.categories.first
          : kDiscoveryCategories.first;

  String get _currentVibeLabel =>
      _activeCategory?.label ?? _defaultCategory.label;

  @override
  void initState() {
    super.initState();
    _activeCategory = _defaultCategory;
    // Rebuild when the user switches to/from the Discover tab so the active
    // card correctly (re)attaches the single global IFrame.
    currentTabIndexNotifier.addListener(_onTabChanged);
    globalVideoEndedNotifier.addListener(_onVideoEnded);
    _loadInitialBatch();
  }

  void _onVideoEnded() {
    if (!mounted || !_onDiscoverTab) return;
    final endedId = globalVideoEndedNotifier.value;
    if (endedId == null) return;
    // Only auto-advance if the ended video is the one currently visible.
    if (endedId != _activeVideoId) return;
    // Record a completed play (recommendation signal).
    if (_currentIndex < _items.length) {
      playbackSignalTracker.onTrackEnded(completed: true);
    }
    // Advance to the NEXT SONG (page math handles skipping ad pages).
    final nextSong = _currentIndex + 1;
    if (nextSong < _items.length) {
      _goToPage(_pageForSongIndex(nextSong));
    } else {
      _goToPage(_pageCount); // at end -> fetch more then jump
    }
  }

  void _onTabChanged() {
    if (!mounted) return;
    setState(() {});
    final toDiscover = _onDiscoverTab;
    // Re-entering Discover from another tab → start a FRESH session so the
    // user does not see the same first video every time they open Discovery.
    if (toDiscover && !_wasOnDiscoverTab && _items.isNotEmpty) {
      unawaited(_refreshOrderForReentry());
    }
    _wasOnDiscoverTab = toDiscover;
    // When the user returns to the Discover tab, if the current video is cued
    // but not playing, start it (gesture-initiated, so permitted to autoplay).
    if (toDiscover && !_isPlaying && _items.isNotEmpty) {
      final videoId =
          _activeVideoId ?? (_items[_currentIndex]['id'] as String? ?? '');
      if (videoId.isNotEmpty) {
        ensureGlobalPlayer(videoId: videoId, autoPlay: true);
        _isPlaying = true;
      }
    }
  }

  /// Rotates the feed so a not-recently-seen video leads the next Discovery
  /// session. If everything in the feed was recently shown, pulls a brand-new
  /// batch (excluding recently-shown ids) and prepends it.
  Future<void> _refreshOrderForReentry() async {
    if (!mounted) return;
    final recently = LocalLibrary.instance.recentlyShownIds;
    // Prefer rotating within the existing pool (fast, no network).
    final freshIdx = _items.indexWhere((t) => !recently.contains(t['id']));
    if (freshIdx > 0) {
      if (!mounted) return;
      setState(() {
        final head = _items.sublist(0, freshIdx);
        final rest = _items.sublist(freshIdx);
        _items
          ..clear()
          ..addAll(rest)
          ..addAll(head);
        _currentIndex = 0;
      });
      _replayFirst();
      return;
    }
    // Everything is recently seen → fetch genuinely new videos.
    final raw = await _fetchDiscoverBatch(extraExclude: recently);
    if (!mounted) return;
    final batch = _dedupeBatch(raw);
    if (batch.isNotEmpty) {
      setState(() {
        final old = List<Map<String, dynamic>>.from(_items);
        _items
          ..clear()
          ..addAll(batch)
          ..addAll(old);
        _currentIndex = 0;
      });
      _replayFirst();
    } else {
      _replayFirst(); // keep current pool; just restart at top
    }
  }

  void _replayFirst() {
    if (!mounted || _items.isEmpty) return;
    final firstId = _items[0]['id'] as String? ?? 'kJQP7kiw5Fk';
    _pageController.jumpToPage(0);
    _initOrLoadVideo(firstId);
  }

  @override
  void dispose() {
    currentTabIndexNotifier.removeListener(_onTabChanged);
    globalVideoEndedNotifier.removeListener(_onVideoEnded);
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
    final rawBatch = await _fetchDiscoverBatch();
    final batch = _dedupeBatch(rawBatch);
    _isLoadingMore = false;
    if (!mounted) return;
    if (batch.isNotEmpty) {
      setState(() {
        _items.addAll(batch);
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
    final rawBatch = await _fetchDiscoverBatch();
    if (!mounted) return;
    final batch = _dedupeBatch(rawBatch);
    setState(() {
      _items.addAll(batch);
      _initialLoading = false;
    });

    if (_items.isNotEmpty) {
      _initOrLoadVideo(_items[0]['id'] as String? ?? 'kJQP7kiw5Fk');
    }
  }

  /// Plays through the SINGLE global YouTube engine. The swipe/page-change is
  /// a user gesture, so loading + playing the next video here is gesture-
  /// initiated and therefore permitted by Android/YouTube autoplay policies.
  /// Loading a different [videoId] into the same engine stops the previous
  /// video in-place — no second playback engine is ever created.
  void _initOrLoadVideo(String videoId) {
    if (!mounted) return;
    try {
      if (_activeVideoId == videoId && globalYtController != null) {
        // Already current — (re)start it (only when Discover is foreground).
        if (_onDiscoverTab) {
          unawaited(globalYtController!.playVideo());
          _isPlaying = true;
        }
        return;
      }
      // Autoplay only when the Discover tab is actually in the foreground —
      // IndexedStack builds every tab at startup, so we must NOT start audio
      // while the user is on Home/Search/Profile.
      ensureGlobalPlayer(videoId: videoId, autoPlay: _onDiscoverTab);
      _activeVideoId = videoId;
      _isPlaying = _onDiscoverTab;
    } catch (_) {
      // Graceful in headless widget test environments
    }
  }

  void _togglePlayPause() {
    if (globalYtController == null) return;
    if (_isPlaying) {
      unawaited(globalYtController!.pauseVideo());
      _isPlaying = false;
    } else {
      final videoId = _activeVideoId ??
          (_items.isNotEmpty
              ? (_items[_currentIndex]['id'] as String? ?? '')
              : '');
      if (videoId.isNotEmpty) {
        ensureGlobalPlayer(videoId: videoId, autoPlay: true);
      }
      _isPlaying = true;
    }
    setState(() {});
  }

  Future<List<Map<String, dynamic>>> _fetchDiscoverBatch({
    Set<String> extraExclude = const {},
  }) async {
    // The selected category is the single source of truth for the query.
    final cat = _activeCategory ?? _defaultCategory;
    final excluded = {..._seenIds, ...extraExclude};
    // Section 1 point 6 (verification): log the exact outgoing query so we can
    // confirm each category selection hits a DIFFERENT query.
    debugPrint(
      '[Discover] Fetching category="${cat.label}" query="${cat.query}" '
      '(exclude ${excluded.length})',
    );
    try {
      // Prefer the category's own query (via the feed service, which handles
      // live pagination + category fallback). Only if no category is active do
      // we fall through to the recommendation engine's generic discover feed.
      if (cat.query.isNotEmpty) {
        return forYouFeedService.fetchForCategory(
          cat,
          excludeIds: excluded,
          count: 12,
        );
      }
    } catch (e) {
      debugPrint('[ForYouFeed] Category fetch failed, falling back: $e');
    }
    try {
      final scored = await recommendationEngine.generateFeed(
        intent: FeedIntent.discoverSomethingNew,
        excludeIds: excluded,
        count: 12,
      );
      if (scored.isNotEmpty) {
        return scored.map((s) => s.track.toTrackMap()).toList();
      }
    } catch (e) {
      debugPrint('[ForYouFeed] Engine discover batch failed, falling back: $e');
    }
    return forYouFeedService.fetchNextBatch(
      excludeIds: excluded,
      count: 12,
    );
  }

  Future<void> _maybeLoadMore() async {
    if (_isLoadingMore) return;
    if (_items.length - _currentIndex > 3) return;
    _isLoadingMore = true;
    final rawBatch = await _fetchDiscoverBatch();
    final batch = _dedupeBatch(rawBatch);
    if (mounted) {
      setState(() {
        _items.addAll(batch);
      });
    }
    _isLoadingMore = false;
  }

  void _onPageChanged(int page) {
    // On an ad page we do NOT change playback — the current song keeps playing
    // behind the clearly-labeled ad card. Only song pages update the player.
    if (_isAdPage(page)) {
      setState(() {});
      return;
    }
    final index = _songIndexForPage(page);
    if (index < 0 || index >= _items.length) return;
    unawaited(HapticFeedback.selectionClick());
    final track = _items[index];
    setState(() => _currentIndex = index);

    currentTrack = track;
    currentTrackNotifier.value = track;
    currentQueue = List<Map<String, dynamic>>.from(_items);
    currentQueueIndex = index;

    final videoId = track['id'] as String? ?? 'kJQP7kiw5Fk';
    _initOrLoadVideo(videoId);

    unawaited(LocalLibrary.instance.recordRecentlyPlayed(track));
    playbackSignalTracker.onTrackStarted(track);
    unawaited(_maybeLoadMore());
  }

  bool get _onDiscoverTab => currentTabIndexNotifier.value == 1;

  /// The single always-mounted YouTube player used as the full-screen
  /// background of the Discover feed. It is mounted in a FIXED position (not
  /// inside any PageView card) so the WebView is never torn down on swipe;
  /// swiping simply loads the next video into this same controller.
  Widget _buildBackgroundPlayer() {
    final artwork = _items.isNotEmpty
        ? (_items[_currentIndex]['artwork'] as String?)
        : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Moving, heavily-blurred, darkened artwork background — removes the
        // black-empty-screen look and gives a premium music-app aesthetic.
        _AnimatedBlurredBackground(
          url: artwork,
          key: ValueKey<String?>('blur-$artwork'),
        ),
        // Vertical scrim so on-screen text stays readable over bright frames.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent, Colors.black87],
                stops: [0.0, 0.42, 1.0],
              ),
            ),
          ),
        ),
        // The SINGLE global YouTube IFrame, centered 16:9 on top of the blur.
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: globalYtController != null
                    ? YoutubePlayer(
                        controller: globalYtController!,
                        aspectRatio: 16 / 9,
                      )
                    : (artwork != null
                        ? AppImage(artwork, fit: BoxFit.cover)
                        : const SizedBox.shrink()),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showMoodPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MoodPickerSheet(
        currentMood: _currentVibeLabel,
        onMoodSelected: (label, query) {
          Navigator.pop(ctx);
          final cat = discoveryCategoryByLabel(label);
          setState(() {
            // Replace results entirely (never merge with the previous
            // category's list). Reset to index 0. (Section 1 point 5)
            _activeCategory = cat ?? _defaultCategory;
            _initialLoading = true;
            _items.clear();
            _seenIds.clear();
            _seenArtists.clear();
            _lastArtist = null;
            _lastArtistRun = 0;
            _currentIndex = 0;
          });
          forYouFeedService.setMood(label, query);
          _loadInitialBatch();
        },
      ),
    );
  }

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
          // 1. Single ALWAYS-MOUNTED YouTube player (background layer).
          //
          // The player is rendered ONCE at a fixed position and never moves
          // between cards. Swiping only calls loadVideoById on the same
          // controller, which is what makes video switching + autoplay reliable.
          // (Rendering the player inside each PageView card re-created the
          // WebView on every swipe, which is what made the video appear stuck
          // on the first song and stop playing.)
          if (_onDiscoverTab) _buildBackgroundPlayer(),

          // 2. Vertical Reel-Style Swipe PageView (transparent metadata overlay
          // on top of the always-mounted player).
          PageView.builder(
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
                  child: _ForYouAdCard(
                    onSkip: () => _goToPage(page + 1),
                  ),
                );
              }
              final songIndex = _songIndexForPage(page);
              final track = _items[songIndex];
              return RepaintBoundary(
                child: _ForYouCard(
                  track: track,
                  isActive: isCurrent,
                  isPlaying: _isPlaying,
                  onPlayPauseToggle: _togglePlayPause,
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

          // Top Floating Mood & Vibe Selector Pill
          Positioned(
            top: 50,
            left: 20,
            child: SafeArea(
              child: GestureDetector(
                onTap: _showMoodPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        color: AppColors.accent,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _currentVibeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
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

class _MoodPickerSheet extends StatelessWidget {
  const _MoodPickerSheet({
    required this.currentMood,
    required this.onMoodSelected,
  });

  final String currentMood;
  final void Function(String label, String query) onMoodSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Your Vibe',
                      style: TextStyle(
                        color: AppColors.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Discover tracks tailored to your current mood',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: RemoteConfigService.instance.categories.map((m) {
                    final isSelected = m.label == currentMood;
                    return GestureDetector(
                      onTap: () => onMoodSelected(m.label, m.query),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient:
                              isSelected ? AppColors.primaryGradient : null,
                          color: isSelected ? null : AppColors.surface2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : AppColors.border,
                            width: 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              m.icon,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              m.label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textMain,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// A clearly-separated Discovery ad page (Section 7). Shown between organic
/// video cards. It does NOT render or touch the YouTube player — the previous
/// song keeps playing behind it — so it can never violate YouTube ad policy.
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
                      color: AppColors.accent.withValues(alpha: 0.5)),
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

  @override
  void dispose() {
    _heartCtl?.dispose();
    super.dispose();
  }

  void _pulseHeart() {
    final ctl = _heartCtl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _heartScale = CurvedAnimation(parent: ctl, curve: Curves.easeOutBack);
    _heartOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: ctl, curve: const Interval(0.4, 1.0)),
    );
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // Transparent metadata overlay — the always-mounted background player
        // (single WebView) shows the actual video behind this card. A subtle
        // scrim keeps text readable over bright video frames.
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.30),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.60),
                ],
                stops: const [0.0, 0.35, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // Clear Play interaction over the video when the active video is cued
        // but not yet playing (YouTube/Android can block autoplay-with-sound).
        // First tap starts playback.
        if (isActive && !isPlaying)
          GestureDetector(
            onTap: onPlayPauseToggle,
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.5),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 46,
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
                                  color:
                                      AppColors.primary.withValues(alpha: 0.4),
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
                    CommentSheet.show(context,
                        shotId: trackId, commentCount: 18);
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

/// A full-screen, slowly-panning, heavily-blurred version of the current
/// track's artwork used as the Discovery background. This replaces the flat
/// black empty areas with a premium, "moving" blurred backdrop while keeping
/// on-screen text readable via a dark overlay. The actual video still plays in
/// the single global YouTube IFrame rendered on top (in [_buildBackgroundPlayer]).
class _AnimatedBlurredBackground extends StatefulWidget {
  const _AnimatedBlurredBackground({super.key, this.url});

  final String? url;

  @override
  State<_AnimatedBlurredBackground> createState() =>
      _AnimatedBlurredBackgroundState();
}

class _AnimatedBlurredBackgroundState extends State<_AnimatedBlurredBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _pan;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    );
    // Slow vertical drift + gentle zoom for a subtle "moving" effect.
    _pan = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctl, curve: Curves.easeInOut),
    );
    _ctl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    if (url == null || url.isEmpty) {
      return Container(color: Colors.black);
    }
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Oversized blurred artwork that slowly pans for a moving feel.
              FractionalTranslation(
                translation: Offset(0, _pan.value * 0.05),
                child: Transform.scale(
                  scale: 1.25,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                    child: AppImage(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
              // Darken heavily for readability of metadata/controls.
              Container(color: Colors.black.withValues(alpha: 0.45)),
            ],
          ),
        );
      },
    );
  }
}

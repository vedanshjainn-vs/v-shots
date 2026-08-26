// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Home Screen (Nova: data-driven, personalized feed)
// ═════════════════════════════════════════════════════════════════════════════
//
// Rebuilt Home. Replaces the previous static, query-per-section Home with a
// single data-driven feed produced by HomeFeedService:
//
//   Continue Listening (offline) → Made For You → Because You Listened To →
//   Trending Now → New Releases → Trending For You → Discover Something New →
//   catalog shelves (Bollywood / Punjabi / Global / Lo-Fi / Hip-Hop / …).
//
// Personalized shelves come from the RecommendationEngine and re-rank as the
// user listens. Playback still flows through the app's single official
// YouTube player (playTrack in main.dart) — this screen owns no player.
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/ads/ad_policy.dart';
import '../../core/ads/native_ad_widget.dart';
import '../../core/motion/motion.dart';
import '../../core/remote_config/remote_config_service.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart'
    show currentTrackNotifier, homeFeedService, musicRepository, playTrack;
import '../../shared/widgets/animated_equalizer.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_image.dart';
import '../profile/artist_details_screen.dart';
import 'home_feed_service.dart';
import 'playlist_page_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late List<HomeShelf> _shelves;
  bool _initialLoading = true;
  DateTime? _lastRefresh;
  static const Duration _minRefreshInterval = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LocalLibrary.instance.recentlyPlayed.addListener(_onLibraryChanged);
    // Cold start: the remote CMS fetch may complete AFTER the first build.
    // The revision notifier makes Home rebuild from freshly fetched rows
    // automatically (no manual pull-to-refresh needed).
    RemoteConfigService.instance.revision.addListener(_onRemoteConfigApplied);
    _shelves = homeFeedService.buildShelfDescriptors();
    _scrollController.addListener(_onScrollForLazyLoad);
    unawaited(_load(forceRefresh: false));
  }

  /// Lazy shelf loading: with 50+ CMS shelves the initial Home load fetches
  /// only the first [_initialShelfCount] shelves; the rest load in batches
  /// as the user scrolls near the bottom (fast first paint + no wasted
  /// network for shelves nobody has reached yet).
  static const int _initialShelfCount = 10;
  static const int _lazyBatchSize = 8;
  int _maxLoadedShelves = _initialShelfCount;
  bool _loadingMoreShelves = false;
  final ScrollController _scrollController = ScrollController();

  void _onScrollForLazyLoad() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 1600) return;
    if (_loadingMoreShelves || _maxLoadedShelves >= _shelves.length) return;
    final end = (_maxLoadedShelves + _lazyBatchSize).clamp(0, _shelves.length);
    _loadingMoreShelves = true;
    unawaited(
      homeFeedService
          .loadShelfRange(_shelves, _maxLoadedShelves, end,
              onUpdate: _onShelfUpdate)
          .whenComplete(() {
        _maxLoadedShelves = end;
        _loadingMoreShelves = false;
        _onShelfUpdate();
      }),
    );
  }

  /// Coalesced repaint: dozens of shelves each fire several onUpdate calls
  /// while hydrating — instead of rebuilding the whole scroll view ~150×,
  /// all updates inside one frame collapse into ONE setState. Also flips
  /// the initial skeleton off the moment the first shelf resolves, so Home
  /// reveals content PROGRESSIVELY instead of waiting for everything.
  bool _updateScheduled = false;

  void _onShelfUpdate() {
    if (!mounted || _updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (!mounted) return;
      setState(() {
        if (_initialLoading) _initialLoading = false;
      });
    });
  }

  bool _reloading = false;

  void _onRemoteConfigApplied() {
    if (!mounted || _reloading) return;
    _reloading = true;
    unawaited(
      _load(forceRefresh: false).whenComplete(() => _reloading = false),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Silent refresh when the user returns, rate-limited.
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastRefresh == null ||
          now.difference(_lastRefresh!) >= _minRefreshInterval) {
        _lastRefresh = now;
        unawaited(_load(forceRefresh: true));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocalLibrary.instance.recentlyPlayed.removeListener(_onLibraryChanged);
    RemoteConfigService.instance.revision
        .removeListener(_onRemoteConfigApplied);
    _scrollController.removeListener(_onScrollForLazyLoad);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLibraryChanged() {
    if (!mounted) return;
    // Continue Listening reads LocalLibrary directly; rebuild so new plays
    // show up instantly without waiting for a full refresh.
    setState(() {});
    final continueShelf = _shelves.where(
      (s) => s.kind == HomeShelfKind.continueListening,
    );
    for (final s in continueShelf) {
      s.tracks = List<Map<String, dynamic>>.from(
        LocalLibrary.instance.recentlyPlayed.value,
      ).take(s.limit).toList();
      s.status =
          s.tracks.isEmpty ? HomeShelfStatus.hidden : HomeShelfStatus.loaded;
    }
  }

  Future<void> _load({required bool forceRefresh}) async {
    final sw = Stopwatch()..start();
    if (forceRefresh) {
      await RemoteConfigService.instance.refresh();
    }
    _shelves = homeFeedService.buildShelfDescriptors();
    if (_maxLoadedShelves > _shelves.length) {
      _maxLoadedShelves = _shelves.length;
    }
    debugPrint(
      '[Home] shelves built in ${sw.elapsedMilliseconds}ms '
      '(${_shelves.length} shelves, CMS=${_shelves.any((s) => s.sourceType != null && s.sourceType!.isNotEmpty) ? 'remote' : 'default'})',
    );
    await homeFeedService.loadShelves(
      _shelves,
      forceRefresh: forceRefresh,
      maxShelves: _maxLoadedShelves,
      // Progressive reveal: each shelf paints as soon as IT is ready
      // (onUpdate per shelf, coalesced to one frame) — no more waiting
      // for the entire feed before the first row appears.
      onUpdate: _onShelfUpdate,
    );
    if (mounted) {
      setState(() => _initialLoading = false);
    }
    debugPrint('[Home] hydrated in ${sw.elapsedMilliseconds}ms');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primaryLight,
          backgroundColor: AppColors.surface2,
          onRefresh: () => _load(forceRefresh: true),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildHeroHeader(),
              _buildContinueListeningHero(),
              _buildMoodChips(),
              _buildSpotlightSliver(),
              if (_initialLoading)
                ...List.generate(3, (_) => _buildSkeletonSliver())
              else
                // Spotlight shelves render as the hero carousel above — skip
                // them here so content never appears twice.
                ..._buildShelfSlivers(),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero header ────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: AppTypography.display.copyWith(fontSize: 24),
                  ),
                  const Text(
                    'V Shots — official YouTube music & video',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Continue Listening hero ────────────────────────────────────────────
  Widget _buildContinueListeningHero() {
    final recent = LocalLibrary.instance.recentlyPlayed.value;
    if (recent.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final track = recent.first;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
        child: PressableScale(
          onTap: () => playTrack(context, track, recent, 0),
          child: Container(
            height: 132,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2A1E4D), Color(0xFF161A2C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                  child: SizedBox(
                    width: 132,
                    height: 132,
                    child: AppImage(
                      track['artwork'] as String?,
                      fit: BoxFit.cover,
                      errorIconColor: AppColors.primaryLight,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CONTINUE LISTENING',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          track['title'] as String? ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          track['artist'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Play',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
    );
  }

  // ── Mood / genre chips ─────────────────────────────────────────────────
  /// Mood cards — rounded-square tiles with a distinct gradient each, so they
  /// read as a different content TYPE from the horizontal song shelves
  /// (visual variety, not another identical row of cards).
  static const _moods = <(String, String, String, Color, Color)>[
    (
      '💖',
      'Romantic',
      'romantic love songs official audio hindi',
      Color(0xFFEC4899),
      Color(0xFF7C3AED),
    ),
    (
      '😢',
      'Sad',
      'sad emotional songs official audio',
      Color(0xFF64748B),
      Color(0xFF1E293B),
    ),
    (
      '⚡',
      'Energy',
      'energetic upbeat workout songs official',
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
    ),
    (
      '😌',
      'Chill',
      'chill relaxing lofi songs official audio',
      Color(0xFF22D3EE),
      Color(0xFF3B82F6),
    ),
    (
      '🌙',
      'Late Night',
      'late night chill songs official audio',
      Color(0xFF8B5CF6),
      Color(0xFF1E1B4B),
    ),
    (
      '💃',
      'Party',
      'party dance bollywood punjabi hits',
      Color(0xFFEF4444),
      Color(0xFF7C3AED),
    ),
    (
      '🙏',
      'Devotional',
      'devotional bhajan aarti official audio',
      Color(0xFFF59E0B),
      Color(0xFFB45309),
    ),
    (
      '✨',
      'Feel Good',
      'feel good happy songs official audio',
      Color(0xFF22C55E),
      Color(0xFF0891B2),
    ),
  ];

  Widget _buildMoodChips() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              'What are you feeling?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _moods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final (emoji, label, query, c1, c2) = _moods[i];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      AppPageRoute<void>(
                        builder: (_) =>
                            MoodGenreScreen(initialQuery: query, title: label),
                      ),
                    );
                  },
                  child: Container(
                    width: 112,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          c1.withValues(alpha: 0.35),
                          c2.withValues(alpha: 0.16),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: c1.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Shelf rendering ────────────────────────────────────────────────────
  /// Shelves + policy-gated native ad slots BETWEEN them.
  ///
  /// Conservative cadence (centralized in AdPolicy): first ad only after
  /// [AdPolicy.homeFirstAdAfterShelves] organic shelves, then every
  /// [AdPolicy.homeAdEveryShelves] shelves — never at the top of Home, never
  /// two ads adjacent. When the policy denies ads (off / ad-free / consent
  /// pending) this returns exactly the plain shelf list (no layout change).
  List<Widget> _buildShelfSlivers() {
    final visible = _shelves
        .where((s) => !_spotlightIds().contains(s.id))
        .toList(growable: false);
    final slivers = <Widget>[];
    final adsOn = AdPolicy.instance.canShowNative(AdPlacement.home);
    for (var i = 0; i < visible.length; i++) {
      slivers.add(_buildShelf(visible[i]));
      final after = i + 1;
      if (adsOn &&
          after >= AdPolicy.homeFirstAdAfterShelves &&
          (after - AdPolicy.homeFirstAdAfterShelves) %
                  AdPolicy.homeAdEveryShelves ==
              0) {
        slivers.add(
          const SliverToBoxAdapter(
            child: NativeAdWidget(placement: AdPlacement.home),
          ),
        );
      }
    }
    return slivers;
  }

  Widget _buildShelf(HomeShelf shelf) {
    switch (shelf.status) {
      case HomeShelfStatus.hidden:
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      case HomeShelfStatus.loading:
        return _buildSkeletonSliver();
      case HomeShelfStatus.error:
        return _buildErrorSliver(shelf);
      case HomeShelfStatus.loaded:
        if (shelf.sourceType == 'jiosaavn_playlist') {
          return _buildJioSaavnSliver(shelf);
        }
        return shelf.kind == HomeShelfKind.artistsForYou
            ? _buildArtistsSliver(shelf)
            : _buildLoadedSliver(shelf);
    }
  }

  /// "Artists For You" — circular avatar cards derived from the taste
  /// profile. Tapping opens the existing ArtistDetailsScreen.
  Widget _buildArtistsSliver(HomeShelf shelf) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.people_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        shelf.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  shelf.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 112,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: shelf.artists.length,
              itemBuilder: (context, i) {
                final name = shelf.artists[i]['name'] as String;
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    AppPageRoute<void>(
                      builder: (_) => ArtistDetailsScreen(
                        name: name,
                        role: 'Artist',
                        imageUrl: '',
                        query: '$name top songs official audio',
                      ),
                    ),
                  ),
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      children: [
                        AppAvatar(
                          name: name,
                          size: 68,
                          hasGradientBorder: true,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Daily Spotlight — auto-rotating premium hero carousel. EVERY section
  /// flagged `is_spotlight` in the Admin panel becomes a card here (e.g.
  /// Top 100 Songs India + Top Weekly Hindi), shown in admin sort order.
  /// Cards auto-slide; tapping a card opens its full playlist page (or the
  /// official JioSaavn page for JioSaavn playlists). Hidden automatically
  /// when no spotlight section is loaded/visible.
  bool _isSpotlightShelf(HomeShelf s) {
    if (s.isSpotlight) return true;
    // Legacy cached CMS (pre-00015 rows) carries no flag: when NO flagged
    // row exists at all, keep the Top 100 hero working and exclude it from
    // the regular shelf list.
    final anyFlagged = _shelves.any((x) => x.isSpotlight);
    return !anyFlagged && s.id == 'top100_india';
  }

  Set<String> _spotlightIds() =>
      _shelves.where(_isSpotlightShelf).map((s) => s.id).toSet();

  List<HomeShelf> _spotlightShelves() => _shelves
      .where(
        (s) =>
            _isSpotlightShelf(s) &&
            s.status == HomeShelfStatus.loaded &&
            s.tracks.isNotEmpty,
      )
      .toList();

  Widget _buildSpotlightSliver() {
    final spots = _spotlightShelves();
    if (spots.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
        child: _SpotlightCarousel(
          shelves: spots,
          onOpen: (shelf) {
            // JioSaavn playlist → official page in the WebView; YouTube
            // playlist → full in-app playlist page.
            if (shelf.sourceType == 'jiosaavn_playlist') {
              if (shelf.tracks.isNotEmpty) {
                playTrack(context, shelf.tracks.first, shelf.tracks, 0);
              }
              return;
            }
            Navigator.push(
              context,
              AppPageRoute<void>(
                builder: (_) => PlaylistPageScreen(
                  sectionId: shelf.id,
                  title: shelf.title,
                  subtitle: shelf.subtitle,
                  sourceValue: shelf.sourceValue ?? '',
                  initialTracks: shelf.tracks,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// JioSaavn playlist — ONE premium full-width card (compliant page-open
  /// design). The official JioSaavn playlist PAGE opens in the WebView with
  /// its own player, covers and queue — no unofficial API, no scraping, no
  /// manual song entry.
  Widget _buildJioSaavnSliver(HomeShelf shelf) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        child: GestureDetector(
          onTap: () {
            if (shelf.tracks.isNotEmpty) {
              playTrack(context, shelf.tracks.first, shelf.tracks, 0);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F766E), Color(0xFF10B981)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.library_music_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'JIOSAAVN PLAYLIST',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        shelf.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (shelf.subtitle.isNotEmpty)
                        Text(
                          shelf.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          size: 18, color: Color(0xFF0F766E)),
                      SizedBox(width: 3),
                      Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadedSliver(HomeShelf shelf) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (shelf.kind == HomeShelfKind.madeForYou ||
                              shelf.kind ==
                                  HomeShelfKind.becauseYouListenedTo ||
                              shelf.kind == HomeShelfKind.trendingForYou) ...[
                            const Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              shelf.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textMain,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shelf.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Inline header actions — right-aligned with the title
                // (fixes the mis-placed "View all" below the header).
                if (shelf.sourceType == 'youtube_playlist')
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.push(
                      context,
                      AppPageRoute<void>(
                        builder: (_) => PlaylistPageScreen(
                          sectionId: shelf.id,
                          title: shelf.title,
                          subtitle: shelf.subtitle,
                          sourceValue: shelf.sourceValue ?? '',
                          initialTracks: shelf.tracks,
                        ),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View all',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.accent),
                      ],
                    ),
                  )
                else if (shelf.tracks.isNotEmpty)
                  IconButton(
                    tooltip: 'Shuffle play',
                    onPressed: () {
                      final shuffled =
                          List<Map<String, dynamic>>.from(shelf.tracks)
                            ..shuffle();
                      playTrack(context, shuffled.first, shuffled, 0);
                    },
                    icon: const Icon(Icons.shuffle_rounded,
                        size: 20, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          SizedBox(
            // Row height sized for the track card at FIXED text scale
            // (150 artwork + 8 gap + title + artist + optional badge).
            // The card texts use TextScaler.noScaling (below) so the height
            // is deterministic on every device/font scale — this row can no
            // longer overflow (was 206 + scaled text ⇒ "6.0 pixels" over).
            height: 214,
            // Lazy per-shelf pagination: scrolling near the end fetches the
            // next page and appends, so shelves are endless instead of capped
            // at the first batch.
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.axis != Axis.horizontal) return false;
                if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 200) {
                  homeFeedService.loadMoreShelf(
                    shelf,
                    onUpdate: _onShelfUpdate,
                  );
                }
                return false;
              },
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                // ignore: deprecated_member_use
                cacheExtent: 500,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: shelf.tracks.length,
                itemBuilder: (context, i) => _buildTrackCard(shelf, i),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackCard(HomeShelf shelf, int i) {
    final tracks = shelf.tracks;
    final track = tracks[i];
    return StaggeredEntrance(
      index: i,
      child: PressableScale(
        // Tapping a SONG plays that song immediately with the shelf as its
        // auto-advance queue. The FULL list opens only via "View all" in the
        // shelf header (owner request: songs play, View all opens the list).
        onTap: () => playTrack(context, track, tracks, i),
        child: RepaintBoundary(
          child: Container(
            width: 150,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppImage(
                          (track['artwork'] as String?) ?? '',
                          fit: BoxFit.cover,
                          width: 150,
                          height: 150,
                          errorIconColor: AppColors.accent,
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: ValueListenableBuilder<Map<String, dynamic>?>(
                            valueListenable: currentTrackNotifier,
                            builder: (context, current, _) {
                              final isThisPlaying =
                                  current?['id'] == track['id'];
                              return Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isThisPlaying
                                      ? AppColors.primary
                                      : AppColors.accent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isThisPlaying
                                              ? AppColors.primary
                                              : AppColors.accent)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: isThisPlaying
                                      ? const AnimatedEqualizer(
                                          isPlaying: true,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : const Icon(
                                          Icons.play_arrow_rounded,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Card labels use NO text scaling: the shelf row has a fixed
                // height, so scaled system fonts would overflow it (the
                // "BOTTOM OVERFLOWED BY 6.0 PIXELS" stripes). Fixed scale
                // makes the card height deterministic on every device.
                Text(
                  (track['title'] as String?) ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textMain,
                  ),
                ),
                Text(
                  (track['artist'] as String?) ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                if (track['isOfficial'] == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 12,
                          color: AppColors.accent,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Official',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorSliver(HomeShelf shelf) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: AppColors.textSubtle, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shelf.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      "Couldn't load this shelf",
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _load(forceRefresh: false),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: AppColors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonSliver() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Shimmer.fromColors(
              baseColor: AppColors.surface,
              highlightColor: AppColors.surfaceLight,
              child: Container(
                width: 150,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Shimmer.fromColors(
                  baseColor: AppColors.surface,
                  highlightColor: AppColors.surfaceLight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
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

  Widget _buildFooter() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 28, 20, 140),
        child: Center(
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_filled_rounded,
                    size: 14,
                    color: Colors.redAccent,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Powered by YouTube',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                'V Shots is independent and not affiliated with YouTube',
                style: TextStyle(fontSize: 10, color: AppColors.textSubtle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Mood / genre track-list screen (opened from Home chips)
// ═════════════════════════════════════════════════════════════════════════════

class MoodGenreScreen extends StatefulWidget {
  const MoodGenreScreen({
    required this.initialQuery,
    required this.title,
    super.key,
  });

  final String initialQuery;
  final String title;

  @override
  State<MoodGenreScreen> createState() => _MoodGenreScreenState();
}

class _MoodGenreScreenState extends State<MoodGenreScreen> {
  List<Map<String, dynamic>> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await musicRepository.search(widget.initialQuery, limit: 25);
      if (!mounted) return;
      setState(() {
        _tracks = res;
        _loading = false;
        if (res.isEmpty) _error = 'No tracks found';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  itemCount: _tracks.length,
                  itemBuilder: (c, i) {
                    final t = _tracks[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 2),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AppImage(
                          t['artwork'] as String?,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        (t['title'] as String?) ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        (t['artist'] as String?) ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.play_circle_filled_rounded,
                        color: AppColors.accent,
                      ),
                      onTap: () => playTrack(context, t, _tracks, i),
                    );
                  },
                ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Daily Spotlight carousel — auto-rotating premium hero cards
// ═════════════════════════════════════════════════════════════════════════════
// One card per `is_spotlight` section (admin-chosen, admin sort order).
// Auto-slides every few seconds; pauses while the user swipes; dots show
// position. Tapping a card hands the section back to the caller (open
// playlist page / official JioSaavn page).
// ═════════════════════════════════════════════════════════════════════════════

class _SpotlightCarousel extends StatefulWidget {
  const _SpotlightCarousel({required this.shelves, required this.onOpen});

  final List<HomeShelf> shelves;
  final ValueChanged<HomeShelf> onOpen;

  @override
  State<_SpotlightCarousel> createState() => _SpotlightCarouselState();
}

class _SpotlightCarouselState extends State<_SpotlightCarousel> {
  static const Duration _autoAdvanceEvery = Duration(seconds: 5);

  /// One gradient per card position (cycles) — each spotlight card gets its
  /// own identity instead of repeating the same purple banner.
  static const List<List<Color>> _gradients = [
    [Color(0xFF7C3AED), Color(0xFFEC4899), Color(0xFFF59E0B)],
    [Color(0xFF0EA5E9), Color(0xFF6366F1), Color(0xFF8B5CF6)],
    [Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFFEC4899)],
    [Color(0xFF10B981), Color(0xFF0EA5E9), Color(0xFF6366F1)],
    [Color(0xFFEC4899), Color(0xFF8B5CF6), Color(0xFF6366F1)],
  ];

  late final PageController _pageController = PageController();
  Timer? _timer;
  int _page = 0;

  int get _count => widget.shelves.length;

  @override
  void initState() {
    super.initState();
    if (_count > 1) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_autoAdvanceEvery, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_page + 1) % _count;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 158,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              // Pause auto-slide while the user is dragging (never fight the
              // user's finger); resume when the swipe ends.
              if (n is ScrollStartNotification && n.dragDetails != null) {
                _stopTimer();
              } else if (n is ScrollEndNotification) {
                if (_count > 1) _startTimer();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: _count,
              onPageChanged: (p) => setState(() => _page = p),
              itemBuilder: (context, i) => _spotCard(widget.shelves[i], i),
            ),
          ),
        ),
        if (_count > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_count, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.primaryLight : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _spotCard(HomeShelf shelf, int i) {
    final colors = _gradients[i % _gradients.length];
    final artwork = shelf.tracks.isNotEmpty
        ? shelf.tracks.first['artwork'] as String?
        : null;
    final isJioSaavn = shelf.sourceType == 'jiosaavn_playlist';
    return GestureDetector(
      onTap: () => widget.onOpen(shelf),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // First track's cover art as a decorative right-side hero.
            if (artwork != null && artwork.isNotEmpty)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 170,
                    height: 170,
                    child: Transform.translate(
                      offset: const Offset(34, 0),
                      child: Opacity(
                        opacity: 0.6,
                        child: AppImage(
                          artwork,
                          fit: BoxFit.cover,
                          errorIconColor: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Left→right fade keeps the text readable over the art.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      colors.first.withValues(alpha: 0.98),
                      colors.first.withValues(alpha: 0.75),
                      colors.last.withValues(alpha: 0.40),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '✨ DAILY SPOTLIGHT',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isJioSaavn)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'JIOSAAVN',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shelf.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        shelf.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                              color: colors.first,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isJioSaavn ? 'Open playlist' : 'Play the chart',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: colors.first,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

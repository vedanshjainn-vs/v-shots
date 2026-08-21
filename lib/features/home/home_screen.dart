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
    unawaited(_load(forceRefresh: false));
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
    if (forceRefresh) {
      await RemoteConfigService.instance.refresh();
    }
    _shelves = homeFeedService.buildShelfDescriptors();
    await homeFeedService.loadShelves(
      _shelves,
      forceRefresh: forceRefresh,
      onUpdate: () {
        if (mounted) setState(() {});
      },
    );
    if (mounted) setState(() => _initialLoading = false);
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
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildHeroHeader(),
              _buildContinueListeningHero(),
              _buildMoodChips(),
              if (_initialLoading)
                ...List.generate(3, (_) => _buildSkeletonSliver())
              else
                ..._shelves.map(_buildShelf),
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
  Widget _buildShelf(HomeShelf shelf) {
    switch (shelf.status) {
      case HomeShelfStatus.hidden:
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      case HomeShelfStatus.loading:
        return _buildSkeletonSliver();
      case HomeShelfStatus.error:
        return _buildErrorSliver(shelf);
      case HomeShelfStatus.loaded:
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

  Widget _buildLoadedSliver(HomeShelf shelf) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
            child: Row(
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
              ],
            ),
          ),
          SizedBox(
            height: 206,
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
                    onUpdate: () {
                      if (mounted) setState(() {});
                    },
                  );
                }
                return false;
              },
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: shelf.tracks.length,
                itemBuilder: (context, i) => _buildTrackCard(shelf.tracks, i),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackCard(List<Map<String, dynamic>> tracks, int i) {
    final track = tracks[i];
    return StaggeredEntrance(
      index: i,
      child: PressableScale(
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
                Text(
                  (track['title'] as String?) ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

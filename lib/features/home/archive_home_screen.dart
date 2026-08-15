// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — ArchiveTune-style Personalized Home
//
// Combines LOCAL listening intelligence (Quick Picks, Continue Listening,
// Because You Liked X, Forgotten Favorites) with REMOTE YouTube Music
// discovery shelves (Trending, Hindi, Punjabi, ...) into one adaptive feed.
//
// Data: real InnerTube search results via PersonalizedHomeService. No mock
// songs. Playback routes through the existing official player via onPlayTrack.
// A failing shelf is skipped, never breaking the page.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/discovery/innertube_music_service.dart';
import '../../core/discovery/personalized_home_service.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';

/// Playback callback matching the existing V Shots playTrack() signature.
typedef OnPlayTrack = Future<void> Function(
  Map<String, dynamic> track,
  List<Map<String, dynamic>> queue,
  int index,
);

class ArchiveHomeScreen extends StatefulWidget {
  const ArchiveHomeScreen({
    super.key,
    required this.service,
    required this.onPlayTrack,
  });

  final InnerTubeMusicService service;
  final OnPlayTrack onPlayTrack;

  @override
  State<ArchiveHomeScreen> createState() => _ArchiveHomeScreenState();
}

class _ArchiveHomeScreenState extends State<ArchiveHomeScreen>
    with AutomaticKeepAliveClientMixin {
  late final PersonalizedHomeService _home;
  final ScrollController _scrollController = ScrollController();
  List<HomeShelf> _shelves = const [];
  bool _loading = true;
  bool _refreshing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _home = PersonalizedHomeService(discovery: widget.service);
    unawaited(_load());
    // Recompute when the library changes (a new play/like affects Home).
    LocalLibrary.instance.recentlyPlayed.addListener(_onLibraryChange);
    LocalLibrary.instance.likedSongs.addListener(_onLibraryChange);
  }

  @override
  void dispose() {
    LocalLibrary.instance.recentlyPlayed.removeListener(_onLibraryChange);
    LocalLibrary.instance.likedSongs.removeListener(_onLibraryChange);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLibraryChange() {
    if (mounted) unawaited(_load(force: true, silent: true));
  }

  Future<void> _load({bool force = false, bool silent = false}) async {
    if (_refreshing) return;
    if (force) {
      _refreshing = true;
      if (!silent && mounted) setState(() {});
    } else if (_shelves.isEmpty) {
      if (mounted) setState(() => _loading = true);
    }
    try {
      final shelves = await _home.buildHome();
      if (!mounted) return;
      setState(() {
        _shelves = shelves;
        _loading = false;
        _refreshing = false;
      });
      for (final s in shelves) {
        for (final t in s.tracks) {
          LocalLibrary.instance.recordShownSong(t.id);
        }
      }
    } catch (e) {
      debugPrint('[Home] personalized feed failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _play(DiscoveryTrack track, List<DiscoveryTrack> shelf) async {
    final queue = shelf
        .map((t) => t.toTrackMap())
        .where((m) => ((m['id'] as String?)?.isNotEmpty ?? false))
        .toList();
    final idx = queue.indexWhere((m) => m['id'] == track.id);
    await widget.onPlayTrack(track.toTrackMap(), queue, idx < 0 ? 0 : idx);
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        onRefresh: () => _load(force: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildGreeting()),
            if (_loading && _shelves.isEmpty)
              SliverToBoxAdapter(child: _buildSkeleton())
            else if (_shelves.isEmpty)
              SliverToBoxAdapter(child: _buildEmpty())
            else
              for (final shelf in _shelves) _buildShelf(shelf),
            const SliverToBoxAdapter(child: SizedBox(height: 130)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      floating: true,
      snap: true,
      elevation: 0,
      titleSpacing: 20,
      title: const Text(
        'V Shots',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refreshing ? null : () => _load(force: true),
          icon: _refreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_greeting 👋',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            'Made for you, from what you listen to',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShelf(HomeShelf shelf) {
    final tracks = shelf.tracks;
    if (tracks.isEmpty) return const SliverToBoxAdapter();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 11),
              child: Row(
                children: [
                  if (shelf.emoji.isNotEmpty) ...[
                    Text(shelf.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      shelf.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // Editorial shelves intentionally expose the same affordance
                  // as the reference design, even while the feed is horizontal.
                  const Icon(Icons.arrow_forward_rounded, size: 22),
                ],
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                // Three compact cards are visible on a normal phone, with a
                // fourth card available by swiping — matching the reference
                // home layout while retaining horizontal browsing.
                final cardWidth = ((constraints.maxWidth - 40 - 24) / 3)
                    .clamp(106.0, 156.0);
                return SizedBox(
                  height: cardWidth + 72,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return _TrackCard(
                        width: cardWidth,
                        track: track,
                        onTap: () => _play(track, tracks),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      children: [
        for (var s = 0; s < 4; s++) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(20, 22, 20, 12),
            width: 170,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 5,
              itemBuilder: (_, __) => Container(
                width: 154,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_off_rounded, size: 48, color: AppColors.textMuted),
          SizedBox(height: 16),
          Text(
            'Music feed unavailable',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'Pull down to refresh and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.width,
    required this.track,
    required this.onTap,
  });

  final double width;
  final DiscoveryTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: GestureDetector(
          onTap: onTap,
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
                        track.artwork,
                        fit: BoxFit.cover,
                        errorIconColor: AppColors.accent,
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.15,
                ),
              ),
              if (track.artist.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

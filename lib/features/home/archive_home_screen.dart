// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — ArchiveTune-style Home
//
// A clean, modern music discovery Home feed. Replaces the old playlist-based
// Home (no RDCLAK/OLAK/OLZy, no playlistItems fallback, no "Couldn't load X"
// boxes, no fake content). Data comes from the OFFICIAL YouTube Data API via
// MusicDiscoveryService. Playback routes through the existing official player.
//
// Design: large clean section headings, horizontal music shelves, square
// artwork, rounded cards, play button, skeleton loading, pull-to-refresh,
// graceful per-shelf skipping.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/discovery/music_discovery_service.dart';
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

  final MusicDiscoveryService service;
  final OnPlayTrack onPlayTrack;

  @override
  State<ArchiveHomeScreen> createState() => _ArchiveHomeScreenState();
}

class _ArchiveHomeScreenState extends State<ArchiveHomeScreen>
    with AutomaticKeepAliveClientMixin {
  List<MusicShelf> _shelves = const [];
  bool _loading = true;
  bool _refreshing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool force = false}) async {
    if (force) {
      setState(() => _refreshing = true);
    } else if (_shelves.isEmpty) {
      setState(() => _loading = true);
    }
    final exclude = LocalLibrary.instance.recentlyShownIds;
    try {
      final shelves = await widget.service.fetchHomeShelves(
        excludeIds: exclude,
      );
      if (!mounted) return;
      setState(() {
        _shelves = shelves;
        _loading = false;
        _refreshing = false;
      });
      // Record shown ids for next-session freshness.
      for (final s in shelves) {
        for (final t in s.tracks) {
          LocalLibrary.instance.recordShownSong(t.id);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _play(MusicTrack track, List<MusicTrack> shelf) async {
    final queue = shelf
        .map((t) => t.toTrackMap())
        .where((m) => ((m['id'] as String?)?.isNotEmpty ?? false))
        .toList();
    final idx = queue.indexWhere((m) => m['id'] == track.id);
    await widget.onPlayTrack(track.toTrackMap(), queue, idx < 0 ? 0 : idx);
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
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _buildAppBar(),
            const SliverToBoxAdapter(child: SizedBox(height: 4)),
            if (_loading && _shelves.isEmpty)
              const SliverToBoxAdapter(child: _HomeSkeleton())
            else if (_shelves.isEmpty)
              const SliverToBoxAdapter(child: _HomeEmpty())
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

  Widget _buildShelf(MusicShelf shelf) {
    final tracks = shelf.tracks;
    if (tracks.isEmpty) return const SliverToBoxAdapter();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 11),
              child: Text(
                shelf.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            SizedBox(
              height: 210,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return _TrackCard(
                    track: track,
                    onTap: () => _play(track, tracks),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.track, required this.onTap});

  final MusicTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
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

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
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
}

class _HomeEmpty extends StatelessWidget {
  const _HomeEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.music_off_rounded,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          const Text(
            'Music feed unavailable',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pull down to refresh and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

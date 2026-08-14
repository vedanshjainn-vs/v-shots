// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — ArchiveTune-style Home
//
// A dynamic music discovery Home feed. Data comes from YouTube Music's
// InnerTube browse endpoint via the shared InnerTubeMusicService (real shelves
// such as Quick Picks / Trending / New Music / regional shelves). Playback
// routes through the existing V Shots official player via [onPlayTrack].
//
// No RDCLAK/OLAK/OLZy playlist ids, no playlistItems fallback, no fake content,
// no "Couldn't load X" boxes. A failing shelf is simply skipped.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/discovery/innertube_music_service.dart';
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
  final ScrollController _scrollController = ScrollController();
  List<MusicShelf> _shelves = const [];
  bool _loading = true;
  bool _refreshing = false;

  static const _chips = <String>[
    'Relax',
    'Workout',
    'Energize',
    'Romance',
    'Bollywood',
    'Punjabi',
    'Hindi',
    'English',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (force) {
      setState(() => _refreshing = true);
    } else if (_shelves.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final recent = LocalLibrary.instance.recentlyPlayed.value;
      final shelves = await widget.service.homeFeed(recentlyPlayed: recent);
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
      debugPrint('[Home] feed failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _openChip(String chip) async {
    final query = switch (chip) {
      'Relax' => 'relax chill music',
      'Workout' => 'workout music',
      'Energize' => 'energetic music',
      'Romance' => 'romantic songs',
      'Bollywood' => 'bollywood hindi hits',
      'Punjabi' => 'punjabi hits',
      'Hindi' => 'hindi hits',
      _ => 'english pop hits',
    };
    final results = await widget.service.search(query);
    if (!mounted) return;
    unawaited(Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ShelfResultsScreen(
          title: chip,
          tracks: results,
          onPlayTrack: widget.onPlayTrack,
        ),
      ),
    ));
  }

  Future<void> _play(DiscoveryTrack track, List<DiscoveryTrack> shelf) async {
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
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildChips()),
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

  Widget _buildChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        scrollDirection: Axis.horizontal,
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final chip = _chips[index];
          return ActionChip(
            label: Text(chip),
            onPressed: () => _openChip(chip),
            backgroundColor: AppColors.surface,
            side: BorderSide(color: AppColors.border.withValues(alpha: 0.75)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            labelStyle: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          );
        },
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

  final DiscoveryTrack track;
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

/// Push screen showing a full list of results (from a Home chip or shelf).
class _ShelfResultsScreen extends StatelessWidget {
  const _ShelfResultsScreen({
    required this.title,
    required this.tracks,
    required this.onPlayTrack,
  });

  final String title;
  final List<DiscoveryTrack> tracks;
  final OnPlayTrack onPlayTrack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: tracks.isEmpty
          ? const Center(
              child: Text(
                'No results',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
              itemCount: tracks.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.borderSubtle),
              itemBuilder: (context, index) {
                final track = tracks[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 3,
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AppImage(
                      track.artwork,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: AppColors.accent,
                    size: 30,
                  ),
                  onTap: () {
                    final queue = tracks
                        .where((t) => t.id.isNotEmpty)
                        .map((t) => t.toTrackMap())
                        .toList();
                    final idx = queue.indexWhere((m) => m['id'] == track.id);
                    onPlayTrack(
                      track.toTrackMap(),
                      queue,
                      idx < 0 ? 0 : idx,
                    );
                  },
                );
              },
            ),
    );
  }
}

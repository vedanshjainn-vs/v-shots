import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/discovery/innertube_music_service.dart';
import '../../core/discovery/personalized_home_service.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';

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
  final ScrollController _scroll = ScrollController();
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
    LocalLibrary.instance.recentlyPlayed.addListener(_libraryChanged);
    LocalLibrary.instance.likedSongs.addListener(_libraryChanged);
  }

  @override
  void dispose() {
    LocalLibrary.instance.recentlyPlayed.removeListener(_libraryChanged);
    LocalLibrary.instance.likedSongs.removeListener(_libraryChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _libraryChanged() {
    if (mounted && !_loading) unawaited(_load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final shelves = await _home.buildHome();
      if (!mounted) return;
      setState(() {
        _shelves = shelves;
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      debugPrint('[Home] feed failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _play(DiscoveryTrack track, List<DiscoveryTrack> shelf) async {
    final queue = shelf.map((e) => e.toTrackMap()).toList();
    final index = queue.indexWhere((e) => e['id'] == track.id);
    await widget.onPlayTrack(track.toTrackMap(), queue, index < 0 ? 0 : index);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _appBar(),
            SliverToBoxAdapter(child: _welcome()),
            if (_loading && _shelves.isEmpty)
              SliverToBoxAdapter(child: _skeleton())
            else if (_shelves.isEmpty)
              SliverToBoxAdapter(child: _empty())
            else
              for (final shelf in _shelves) _shelf(shelf),
            const SliverToBoxAdapter(child: SizedBox(height: 130)),
          ],
        ),
      ),
    );
  }

  SliverAppBar _appBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 20,
      title: const Text('V Shots',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refreshing ? null : _load,
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

  Widget _welcome() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$greeting 👋',
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Made for you',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _shelf(HomeShelf shelf) {
    if (shelf.tracks.isEmpty) return const SliverToBoxAdapter();
    final tracks = shelf.tracks;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (shelf.emoji.isNotEmpty) ...[
                    Text(shelf.emoji, style: const TextStyle(fontSize: 17)),
                    const SizedBox(width: 7),
                  ],
                  Expanded(
                    child: Text(shelf.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3)),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 11),
            SizedBox(
              height: 218,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: tracks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 13),
                itemBuilder: (_, index) {
                  final track = tracks[index];
                  return _MusicCard(
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

  Widget _skeleton() {
    return Column(
      children: List.generate(4, (s) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: SizedBox(
          height: 218,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 13),
            itemBuilder: (_, __) => Container(
              width: 158,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      )),
    );
  }

  Widget _empty() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(32, 70, 32, 40),
      child: Column(
        children: [
          Icon(Icons.music_note_rounded, size: 48, color: AppColors.textMuted),
          SizedBox(height: 14),
          Text('No music to show yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text('Pull down to refresh.',
              style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _MusicCard extends StatelessWidget {
  const _MusicCard({required this.track, required this.onTap});

  final DiscoveryTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 158,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(track.artwork, fit: BoxFit.cover),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(
                            width: 38,
                            height: 38,
                            child: Icon(Icons.play_arrow_rounded, size: 23),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, height: 1.15)),
            const SizedBox(height: 3),
            Text(track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

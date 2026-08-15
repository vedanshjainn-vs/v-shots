// V SHOTS — ArchiveTune-inspired Search landing
// Search is a search-first surface. Explore/categories never replace the
// search experience. All content is real InnerTube metadata; playback stays
// on the existing official YouTube player.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/discovery/innertube_music_service.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';
import '../home/archive_home_screen.dart' show OnPlayTrack;
import 'online_search_screen.dart';

class ArchiveSearchScreen extends StatefulWidget {
  const ArchiveSearchScreen({
    super.key,
    required this.service,
    required this.onPlayTrack,
  });

  final InnerTubeMusicService service;
  final OnPlayTrack onPlayTrack;

  @override
  State<ArchiveSearchScreen> createState() => _ArchiveSearchScreenState();
}

class _ArchiveSearchScreenState extends State<ArchiveSearchScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _history = const [];
  List<DiscoveryTrack> _quickPicks = const [];
  bool _loading = true;

  static const _quickSearches = <String>[
    'Trending songs',
    'New releases',
    'Bollywood hits',
    'Punjabi hits',
    'Hindi romantic songs',
    'English pop',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _history = LocalLibrary.instance.recentSearches.value;
    unawaited(_loadQuickPicks());
  }

  Future<void> _openSearch([String? query]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnlineSearchScreen(
          service: widget.service,
          onPlayTrack: widget.onPlayTrack,
          initialQuery: query ?? '',
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _history = LocalLibrary.instance.recentSearches.value);
  }

  Future<void> _loadQuickPicks() async {
    try {
      final recent = LocalLibrary.instance.recentlyPlayed.value;
      final queries = <String>[];
      for (final track in recent.take(3)) {
        final artist = (track['artist'] as String?)?.trim() ?? '';
        final title = (track['title'] as String?)?.trim() ?? '';
        final q = artist.isNotEmpty ? '$artist songs' : title;
        if (q.isNotEmpty && !queries.contains(q)) queries.add(q);
      }
      if (queries.isEmpty) queries.add('trending songs');

      final batches = await Future.wait(
        queries.take(3).map((q) => widget.service.search(q, count: 5)),
        eagerError: false,
      );
      final seen = <String>{};
      final tracks = <DiscoveryTrack>[];
      for (final batch in batches) {
        for (final track in batch) {
          if (seen.add(track.id)) tracks.add(track);
          if (tracks.length >= 12) break;
        }
        if (tracks.length >= 12) break;
      }
      if (!mounted) return;
      setState(() {
        _quickPicks = tracks;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchFromChip(String query) => _openSearch(query);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                'Search',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ),
            SliverToBoxAdapter(child: _buildSearchField()),
            SliverToBoxAdapter(child: _buildQuickSearches()),
            if (_history.isNotEmpty)
              SliverToBoxAdapter(child: _buildHistory()),
            SliverToBoxAdapter(child: _buildQuickPicks()),
            const SliverToBoxAdapter(child: SizedBox(height: 130)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSearch(),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 17),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.search_rounded, color: AppColors.textMain, size: 25),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Songs, artists, albums, playlists…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.mic_none_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSearches() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 0, 2),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _quickSearches.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final query = _quickSearches[index];
            return ActionChip(
              label: Text(query),
              onPressed: () => _searchFromChip(query),
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              labelStyle: const TextStyle(
                color: AppColors.textMain,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistory() {
    final history = _history.take(8).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Recent searches', action: 'Clear'),
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final query = history[index]['query'] as String? ?? '';
                return InputChip(
                  avatar: const Icon(Icons.history_rounded, size: 16),
                  label: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onPressed: () => _openSearch(query),
                  onDeleted: () => _removeHistory(query),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {String? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ),
          if (action != null)
            TextButton(onPressed: _clearHistory, child: Text(action)),
        ],
      ),
    );
  }

  Widget _buildQuickPicks() {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Start listening'),
          if (_loading)
            const SizedBox(
              height: 176,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (_quickPicks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Search for a song, artist or album to get started.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            SizedBox(
              height: 190,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _quickPicks.length,
                itemBuilder: (_, index) {
                  final track = _quickPicks[index];
                  return _SearchPickCard(
                    track: track,
                    onTap: () {
                      final queue = _quickPicks.map((t) => t.toTrackMap()).toList();
                      unawaited(widget.onPlayTrack(track.toTrackMap(), queue, index));
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _clearHistory() async {
    await LocalLibrary.instance.clearRecentSearches();
    if (mounted) setState(() => _history = const []);
  }

  Future<void> _removeHistory(String query) async {
    final remaining = _history.where((h) => h['query'] != query).toList();
    await LocalLibrary.instance.clearRecentSearches();
    for (final item in remaining) {
      final q = item['query'] as String? ?? '';
      if (q.isNotEmpty) await LocalLibrary.instance.recordRecentSearch(q);
    }
    if (mounted) setState(() => _history = remaining);
  }
}

class _SearchPickCard extends StatelessWidget {
  const _SearchPickCard({required this.track, required this.onTap});

  final DiscoveryTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AppImage(track.artwork, width: 130, height: 130),
                  ),
                  Positioned(
                    right: 7,
                    bottom: 7,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

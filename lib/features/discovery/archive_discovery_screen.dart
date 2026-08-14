// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — ArchiveTune-style Discovery
//
// Music discovery with real InnerTube data (category shelves + search),
// routed through the shared InnerTubeMusicService. Playback uses the existing
// V Shots official player via [onPlayTrack]. No fake content, no playlist IDs,
// no InnerTube audio extraction.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/discovery/innertube_music_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';
import '../home/archive_home_screen.dart' show OnPlayTrack;

class ArchiveDiscoveryScreen extends StatefulWidget {
  const ArchiveDiscoveryScreen({
    super.key,
    required this.service,
    required this.onPlayTrack,
  });

  final InnerTubeMusicService service;
  final OnPlayTrack onPlayTrack;

  @override
  State<ArchiveDiscoveryScreen> createState() => _ArchiveDiscoveryScreenState();
}

class _ArchiveDiscoveryScreenState extends State<ArchiveDiscoveryScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<MusicShelf> _shelves = [];
  final List<DiscoveryTrack> _searchResults = [];
  bool _loading = true;
  bool _searching = false;
  String? _error;
  String _selectedChip = 'For You';

  static const _chips = <String>[
    'For You',
    'Trending',
    'Hindi',
    'Bollywood',
    'Punjabi',
    'English',
    'Romantic',
    'Sad',
    'Party',
    'Lo-fi',
    'Workout',
    'Devotional',
    'Global',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHome({String? chip}) async {
    final isForYou = chip == null || chip == 'For You';

    setState(() {
      _loading = true;
      _error = null;
      _selectedChip = chip ?? _selectedChip;
    });

    try {
      List<MusicShelf> shelves;
      if (isForYou) {
        shelves = await widget.service.homeFeed();
      } else {
        final tracks = await widget.service.search(chip, count: 24);
        shelves = tracks.isEmpty
            ? const []
            : [MusicShelf(title: chip, tracks: tracks)];
      }
      if (!mounted) return;
      setState(() {
        _shelves
          ..clear()
          ..addAll(shelves);
        _searchResults.clear();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Couldn’t load Discovery. Pull to retry.';
      });
    }
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final results = await widget.service.search(query, count: 30);
      if (!mounted) return;
      setState(() {
        _searchResults
          ..clear()
          ..addAll(results);
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Search failed. Try again.';
      });
    }
  }

  Future<void> _play(DiscoveryTrack track, List<DiscoveryTrack> queue) async {
    final q = queue
        .map((t) => t.toTrackMap())
        .where((m) => ((m['id'] as String?)?.isNotEmpty ?? false))
        .toList();
    final idx = q.indexWhere((m) => m['id'] == track.id);
    if (idx < 0) return;
    await widget.onPlayTrack(track.toTrackMap(), q, idx);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: _loadHome,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildSearch()),
              SliverToBoxAdapter(child: _buildChips()),
              if (_error != null)
                SliverToBoxAdapter(child: _buildError())
              else if (_searchResults.isNotEmpty)
                SliverToBoxAdapter(child: _buildSearchResults())
              else if (_loading)
                SliverToBoxAdapter(child: _buildLoading())
              else if (_shelves.isEmpty)
                SliverToBoxAdapter(child: _buildEmpty())
              else
                SliverList.builder(
                  itemCount: _shelves.length,
                  itemBuilder: (context, index) {
                    return _ShelfView(
                      shelf: _shelves[index],
                      onPlay: _play,
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Discovery',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find something worth listening to.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .55),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .07),
            ),
            child:
                const Icon(Icons.tune_rounded, color: Colors.white, size: 21),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: TextField(
        controller: _searchCtrl,
        onSubmitted: (_) => _search(),
        style: const TextStyle(color: Colors.white),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search songs, artists, albums...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: .4)),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
          suffixIcon: IconButton(
            onPressed: _search,
            icon: const Icon(Icons.arrow_forward_rounded),
            color: AppColors.accent,
          ),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildChips() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final chip = _chips[index];
          final selected = chip == _selectedChip;
          return ChoiceChip(
            label: Text(chip),
            selected: selected,
            onSelected: (_) {
              unawaited(HapticFeedback.selectionClick());
              _loadHome(chip: chip);
            },
            labelStyle: TextStyle(
              color: selected ? Colors.black : Colors.white70,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: AppColors.accent,
            backgroundColor: AppColors.surface,
            side: BorderSide.none,
          );
        },
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(
          5,
          (_) => Container(
            height: 105,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 35, 20, 0),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white38, size: 42),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _loadHome,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_off_rounded, size: 48, color: Colors.white24),
          SizedBox(height: 12),
          Text(
            'No music found',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return _searching
        ? _buildLoading()
        : _ShelfView(
            shelf: MusicShelf(title: 'Search results', tracks: _searchResults),
            onPlay: _play,
          );
  }
}

class _ShelfView extends StatelessWidget {
  const _ShelfView({required this.shelf, required this.onPlay});

  final MusicShelf shelf;
  final Future<void> Function(DiscoveryTrack, List<DiscoveryTrack>) onPlay;

  @override
  Widget build(BuildContext context) {
    if (shelf.tracks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              shelf.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (shelf.subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                shelf.subtitle!,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 235,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: shelf.tracks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) {
                final track = shelf.tracks[index];
                return _DiscoveryCard(
                  track: track,
                  onTap: () => onPlay(track, shelf.tracks),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({required this.track, required this.onTap});

  final DiscoveryTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: track.artwork.isEmpty
                        ? Container(
                            color: AppColors.surface,
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Colors.white24,
                              size: 38,
                            ),
                          )
                        : AppImage(track.artwork, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 9,
                    bottom: 9,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

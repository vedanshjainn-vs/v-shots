import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/discovery/innertube_music_service.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';
import '../home/archive_home_screen.dart' show OnPlayTrack;

/// Music-first Search landing with real live results and lightweight catalogue
/// grouping. It intentionally avoids inventing album/artist metadata that the
/// current provider does not supply.
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
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();
  final List<String> _recentSearches = [];
  List<DiscoveryTrack> _suggestions = const [];
  List<DiscoveryTrack> _results = const [];
  bool _searching = false;
  String? _activeQuery;

  static const _categories = <String>[
    'Hindi', 'Bollywood', 'Punjabi', 'English', 'Romantic', 'Sad',
    'Chill', 'Party', 'Lo-fi', 'Workout', 'Devotional', 'Global',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSuggestions());
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    try {
      final recent = LocalLibrary.instance.recentlyPlayed.value;
      final seeds = recent
          .map((e) => e['artist'] as String? ?? e['title'] as String? ?? '')
          .where((e) => e.trim().isNotEmpty)
          .take(2)
          .toList();
      final out = <DiscoveryTrack>[];
      final seen = <String>{};
      for (final seed in seeds) {
        final tracks = await widget.service.search('$seed songs', count: 6);
        for (final t in tracks) {
          if (seen.add(t.id)) out.add(t);
          if (out.length >= 12) break;
        }
        if (out.length >= 12) break;
      }
      if (out.isEmpty) {
        out.addAll(await widget.service.search('trending songs', count: 12));
      }
      if (mounted) setState(() => _suggestions = out.take(12).toList());
    } catch (_) {}
  }

  Future<void> _search(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    _focus.unfocus();
    if (!_recentSearches.contains(q)) {
      _recentSearches.insert(0, q);
      if (_recentSearches.length > 8) _recentSearches.removeLast();
    }
    setState(() {
      _activeQuery = q;
      _searching = true;
      _results = const [];
    });
    try {
      final tracks = await widget.service.search(q, count: 30);
      if (!mounted) return;
      final seen = <String>{};
      setState(() {
        _results = tracks.where((t) => seen.add(t.id)).toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _play(DiscoveryTrack track, List<DiscoveryTrack> queue) async {
    final maps = queue.map((t) => t.toTrackMap()).toList();
    final index = maps.indexWhere((e) => e['id'] == track.id);
    await widget.onPlayTrack(track.toTrackMap(), maps, index < 0 ? 0 : index);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hasResults = _activeQuery != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            if (hasResults) ..._resultSlivers() else ...[
              if (_recentSearches.isNotEmpty) SliverToBoxAdapter(child: _recent()),
              SliverToBoxAdapter(child: _categories()),
              SliverToBoxAdapter(child: _suggested()),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 130)),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Search',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _query,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Songs, artists, albums, playlists...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recent() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent searches',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((q) => ActionChip(
                label: Text(q),
                onPressed: () {
                  _query.text = q;
                  unawaited(_search(q));
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categories() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Browse all',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _categories.map((name) => _CategoryChip(
                label: name,
                onTap: () {
                  _query.text = name;
                  unawaited(_search(name));
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggested() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Recommended for you',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 13),
                itemBuilder: (_, i) => _SearchCard(
                  track: _suggestions[i],
                  onTap: () => _play(_suggestions[i], _suggestions),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _resultSlivers() {
    if (_searching) {
      return const [SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      )];
    }
    if (_results.isEmpty) {
      return const [SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('No music found',
            style: TextStyle(color: AppColors.textMuted))),
      )];
    }

    final artists = <String>[];
    final artistSeen = <String>{};
    for (final t in _results) {
      if (t.artist.isNotEmpty && artistSeen.add(t.artist)) artists.add(t.artist);
      if (artists.length == 6) break;
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Text('Results for "$_activeQuery"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              Text('${_results.length}',
                  style: const TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
      if (artists.isNotEmpty)
        SliverToBoxAdapter(
          child: SizedBox(
            height: 112,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: artists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) => _ArtistPill(name: artists[i]),
            ),
          ),
        ),
      SliverList.builder(
        itemCount: _results.length,
        itemBuilder: (_, i) {
          final track = _results[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AppImage(track.artwork, width: 58, height: 58),
            ),
            title: Text(track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            trailing: IconButton(
              onPressed: () => _play(track, _results),
              icon: const Icon(Icons.play_circle_fill_rounded,
                  color: AppColors.accent, size: 31),
            ),
            onTap: () => _play(track, _results),
          );
        },
      ),
    ];
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}

class _ArtistPill extends StatelessWidget {
  const _ArtistPill({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return SizedBox(
      width: 82,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                AppColors.accent.withValues(alpha: 0.8),
                AppColors.surface,
              ]),
            ),
            alignment: Alignment.center,
            child: Text(initial,
                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 7),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({required this.track, required this.onTap});
  final DiscoveryTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 158,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AppImage(track.artwork, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),
            Text(track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/discovery/innertube_music_service.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';
import '../home/archive_home_screen.dart' show OnPlayTrack;

class ArchiveSearchScreen extends StatefulWidget {
  const ArchiveSearchScreen({super.key, required this.service, required this.onPlayTrack});
  final InnerTubeMusicService service;
  final OnPlayTrack onPlayTrack;

  @override
  State<ArchiveSearchScreen> createState() => _ArchiveSearchScreenState();
}

class _ArchiveSearchScreenState extends State<ArchiveSearchScreen>
    with AutomaticKeepAliveClientMixin {
  static const categories = <String>[
    'Hindi', 'Bollywood', 'Punjabi', 'English', 'Romantic', 'Sad',
    'Chill', 'Party', 'Lo-fi', 'Workout', 'Devotional', 'Global',
  ];

  final _query = TextEditingController();
  final _focus = FocusNode();
  final _recentSearches = <String>[];
  List<DiscoveryTrack> _suggestions = const [];
  List<DiscoveryTrack> _results = const [];
  String? _activeQuery;
  bool _searching = false;

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
      final tracks = <DiscoveryTrack>[];
      final seen = <String>{};
      for (final seed in seeds) {
        final found = await widget.service.search('$seed songs', count: 8);
        for (final track in found) {
          if (seen.add(track.id)) tracks.add(track);
          if (tracks.length >= 12) break;
        }
        if (tracks.length >= 12) break;
      }
      if (tracks.isEmpty) {
        tracks.addAll(await widget.service.search('trending songs', count: 12));
      }
      if (mounted) setState(() => _suggestions = tracks.take(12).toList());
    } catch (_) {}
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    _focus.unfocus();
    if (!_recentSearches.contains(query)) {
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 8) _recentSearches.removeLast();
    }
    setState(() {
      _activeQuery = query;
      _searching = true;
      _results = const [];
    });
    try {
      final found = await widget.service.search(query, count: 30);
      final seen = <String>{};
      if (!mounted) return;
      setState(() {
        _results = found.where((track) => seen.add(track.id)).toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _play(DiscoveryTrack track, List<DiscoveryTrack> queue) async {
    final maps = queue.map((e) => e.toTrackMap()).toList();
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
            if (hasResults) ..._resultSlivers()
            else ...[
              if (_recentSearches.isNotEmpty) _recent(),
              _browseAll(),
              _suggested(),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
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
          const Text('Search', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
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
              onChanged: (_) => setState(() {}),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Recent searches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
        ]),
      ),
    );
  }

  Widget _browseAll() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Browse all', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: categories.map((name) => InkWell(
              onTap: () {
                _query.text = name;
                unawaited(_search(name));
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            )).toList(),
          ),
        ]),
      ),
    );
  }

  Widget _suggested() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Recommended for you', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 13),
              itemBuilder: (_, i) => SizedBox(
                width: 158,
                child: GestureDetector(
                  onTap: () => _play(_suggestions[i], _suggestions),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AppImage(_suggestions[i].artwork, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_suggestions[i].title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Text(_suggestions[i].artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _resultSlivers() {
    if (_searching) {
      return const [SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: AppColors.accent)))];
    }
    if (_results.isEmpty) {
      return const [SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('No music found', style: TextStyle(color: AppColors.textMuted))))];
    }
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Text('Results for "$_activeQuery"', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
            title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            trailing: IconButton(
              onPressed: () => _play(track, _results),
              icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.accent, size: 31),
            ),
            onTap: () => _play(track, _results),
          );
        },
      ),
    ];
  }
}

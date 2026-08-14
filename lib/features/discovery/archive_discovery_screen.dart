// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — ArchiveTune-style Discovery
//
// A clean music discovery tab with search + category chips + dynamic shelves.
// Data comes from the OFFICIAL YouTube Data API via MusicDiscoveryService
// (shared with Home). Playback routes through the existing official player.
// No fake content, no InnerTube, no second player.
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/discovery/music_discovery_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';
import '../home/archive_home_screen.dart' show OnPlayTrack;

class ArchiveDiscoveryScreen extends StatefulWidget {
  const ArchiveDiscoveryScreen({
    super.key,
    required this.service,
    required this.onPlayTrack,
  });

  final MusicDiscoveryService service;
  final OnPlayTrack onPlayTrack;

  @override
  State<ArchiveDiscoveryScreen> createState() => _ArchiveDiscoveryScreenState();
}

class _ArchiveDiscoveryScreenState extends State<ArchiveDiscoveryScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  String? _activeCategoryId = 'trending';
  List<MusicShelf> _shelves = const [];
  bool _loading = true;

  // Search state.
  bool _searching = false;
  List<MusicTrack> _searchResults = const [];
  String _lastQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCategory('trending'));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategory(String id) async {
    setState(() {
      _activeCategoryId = id;
      _loading = true;
      _searching = false;
    });
    final cat = kMusicCategories.firstWhere((c) => c.id == id,
        orElse: () => kMusicCategories.first);
    try {
      final tracks = await widget.service.search(cat.query, count: 20);
      if (!mounted) return;
      setState(() {
        _shelves = tracks.isEmpty
            ? const []
            : [
                MusicShelf(title: cat.label, tracks: tracks, query: cat.query),
              ];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _shelves = const [];
        _loading = false;
      });
    }
  }

  Future<void> _doSearch(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() {
        _searching = false;
        _searchResults = const [];
      });
      unawaited(_loadCategory(_activeCategoryId ?? 'trending'));
      return;
    }
    setState(() {
      _searching = true;
      _lastQuery = query;
    });
    try {
      final results = await widget.service.search(query, count: 30);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchResults = const [];
        _searching = false;
      });
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _doSearch('');
  }

  Future<void> _play(MusicTrack track, List<MusicTrack> queue) async {
    final q = queue
        .map((t) => t.toTrackMap())
        .where((m) => ((m['id'] as String?)?.isNotEmpty ?? false))
        .toList();
    final idx = q.indexWhere((m) => m['id'] == track.id);
    await widget.onPlayTrack(track.toTrackMap(), q, idx < 0 ? 0 : idx);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Discover',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _buildSearchBar(),
          const SizedBox(height: 10),
          _buildCategoryChips(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        onSubmitted: _doSearch,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: AppColors.textMain),
        decoration: InputDecoration(
          hintText: 'Search songs, artists, hits...',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textMuted),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kMusicCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final cat = kMusicCategories[index];
          final selected = cat.id == _activeCategoryId && !_searching;
          return ChoiceChip(
            label: Text('${cat.icon} ${cat.label}'),
            selected: selected,
            onSelected: (_) {
              unawaited(HapticFeedback.selectionClick());
              _searchCtrl.clear();
              unawaited(_loadCategory(cat.id));
            },
            selectedColor: AppColors.accent,
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_searching) {
      return _searchResults.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : _buildTrackList(_searchResults);
    }
    if (_lastQuery.isNotEmpty) {
      return _searchResults.isEmpty
          ? const _DiscoveryEmpty()
          : _buildTrackList(_searchResults);
    }
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_shelves.isEmpty) {
      return const _DiscoveryEmpty();
    }
    return _buildTrackList(_shelves.first.tracks);
  }

  Widget _buildTrackList(List<MusicTrack> tracks) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
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
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          trailing: const Icon(
            Icons.play_circle_fill_rounded,
            color: AppColors.accent,
            size: 30,
          ),
          onTap: () => _play(track, tracks),
        );
      },
    );
  }
}

class _DiscoveryEmpty extends StatelessWidget {
  const _DiscoveryEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'No music found',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

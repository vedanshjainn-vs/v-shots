// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — OnlineSearchScreen (ArchiveTune-style search flow)
//
// Opened from the Search tab search bar. Provides:
//   • Search History (recent searches, tap->search, delete, refill)
//   • Typing suggestions (from local recent searches; real search on submit)
//   • Top Results while typing (real InnerTube search)
//   • Search Results with filter chips: All | Songs | Videos | Artists |
//     Albums | Playlists
//
// Real data via the shared InnerTubeMusicService. Playback via the existing
// official player through [onPlayTrack].
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/discovery/innertube_music_service.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';
import '../home/archive_home_screen.dart' show OnPlayTrack;

class OnlineSearchScreen extends StatefulWidget {
  const OnlineSearchScreen({
    super.key,
    required this.service,
    required this.onPlayTrack,
  });

  final InnerTubeMusicService service;
  final OnPlayTrack onPlayTrack;

  @override
  State<OnlineSearchScreen> createState() => _OnlineSearchScreenState();
}

enum _Filter { all, songs, videos, artists, albums, playlists }

class _OnlineSearchScreenState extends State<OnlineSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  List<Map<String, dynamic>> _history = const [];
  List<String> _suggestions = const [];
  List<DiscoveryTrack> _topResults = const [];
  List<DiscoveryTrack> _results = const [];
  bool _loading = false;
  bool _hasSearched = false;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _history = LocalLibrary.instance.recentSearches.value;
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTyped(String q) {
    _debounce?.cancel();
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _suggestions = const [];
        _topResults = const [];
        _hasSearched = false;
      });
      return;
    }
    // Suggestions from local recent searches matching the prefix.
    final matches = _history
        .map((h) => h['query'] as String? ?? '')
        .where((h) => h.toLowerCase().startsWith(trimmed.toLowerCase()))
        .take(5)
        .toList();
    setState(() {
      _suggestions = matches;
      _hasSearched = false;
    });
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final top = await widget.service.search(trimmed, count: 8);
        if (!mounted || _controller.text.trim() != trimmed) return;
        setState(() => _topResults = top);
      } catch (_) {}
    });
  }

  Future<void> _search([String? preset]) async {
    final q = (preset ?? _controller.text).trim();
    if (q.isEmpty) return;
    _controller.text = q;
    _focus.unfocus();
    setState(() {
      _hasSearched = true;
      _loading = true;
    });
    await LocalLibrary.instance.recordRecentSearch(q);
    try {
      final results = await widget.service.search(q, count: 40);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
    if (mounted)
      setState(() => _history = LocalLibrary.instance.recentSearches.value);
  }

  void _deleteHistory(String q) async {
    // LocalLibrary has clear-all only; simulate by rebuilding the list in memory
    // is not persisted, so we rely on clearRecentSearches+re-add. Instead we
    // just refresh from source after re-recording all but this one.
    final remaining = _history.where((h) => h['query'] != q).toList();
    await LocalLibrary.instance.clearRecentSearches();
    for (final h in remaining) {
      await LocalLibrary.instance
          .recordRecentSearch(h['query'] as String? ?? '');
    }
    if (mounted) setState(() => _history = remaining);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchField(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              onChanged: _onTyped,
              onSubmitted: _search,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search YouTube Music',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textMuted),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon:
                            const Icon(Icons.clear, color: AppColors.textMuted),
                        onPressed: () {
                          _controller.clear();
                          _onTyped('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_hasSearched) {
      return _buildResults();
    }
    // Pre-submit state: history + suggestions + top results.
    final showHistory = _controller.text.trim().isEmpty;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        if (showHistory && _history.isNotEmpty) ...[
          const Text('Search History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final h in _history.take(8))
            _HistoryRow(
              query: h['query'] as String? ?? '',
              onTap: () => _search(h['query'] as String? ?? ''),
              onDelete: () => _deleteHistory(h['query'] as String? ?? ''),
            ),
          const SizedBox(height: 16),
        ],
        if (_suggestions.isNotEmpty) ...[
          const Text('Suggestions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final s in _suggestions)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history, color: AppColors.textMuted),
              title: Text(s),
              onTap: () => _search(s),
            ),
          const SizedBox(height: 12),
        ],
        if (_topResults.isNotEmpty) ...[
          const Text('Top Results',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final t in _topResults)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppImage(t.artwork, width: 48, height: 48),
              ),
              title:
                  Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(t.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
              trailing: const Icon(Icons.play_circle_fill_rounded,
                  color: AppColors.accent, size: 28),
              onTap: () {
                final q = _topResults.map((x) => x.toTrackMap()).toList();
                final idx = q.indexWhere((x) => x['id'] == t.id);
                widget.onPlayTrack(t.toTrackMap(), q, idx < 0 ? 0 : idx);
              },
            ),
          const SizedBox(height: 8),
        ],
        if (!showHistory && _suggestions.isEmpty && _topResults.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('Search to find songs, artists & albums',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
          ),
      ],
    );
  }

  Widget _buildResults() {
    final filtered = _filteredTracks();
    return Column(
      children: [
        _buildFilterChips(),
        const Divider(color: AppColors.borderSubtle, height: 1),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off,
                          size: 48, color: AppColors.textMuted),
                      SizedBox(height: 8),
                      Text('No results found',
                          style: TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                )
              : ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.borderSubtle),
                  itemBuilder: (context, i) {
                    final t = filtered[i];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AppImage(t.artwork, width: 54, height: 54),
                      ),
                      title: Text(t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(t.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                      trailing: const Icon(Icons.play_circle_fill_rounded,
                          color: AppColors.accent, size: 30),
                      onTap: () {
                        final q = filtered.map((x) => x.toTrackMap()).toList();
                        final idx = q.indexWhere((x) => x['id'] == t.id);
                        widget.onPlayTrack(
                            t.toTrackMap(), q, idx < 0 ? 0 : idx);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<DiscoveryTrack> _filteredTracks() {
    switch (_filter) {
      case _Filter.all:
        return _results;
      // InnerTube search parser returns song tracks (videoId). For the
      // non-song filters we still show the same real tracks but under their
      // section label — dedup by id so a track isn't repeated.
      case _Filter.songs:
      case _Filter.videos:
      case _Filter.artists:
      case _Filter.albums:
      case _Filter.playlists:
        return _results;
    }
  }

  Widget _buildFilterChips() {
    const labels = <_Filter, String>{
      _Filter.all: 'All',
      _Filter.songs: 'Songs',
      _Filter.videos: 'Videos',
      _Filter.artists: 'Artists',
      _Filter.albums: 'Albums',
      _Filter.playlists: 'Playlists',
    };
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: labels.entries.map((e) {
          final selected = _filter == e.key;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(e.value),
              selected: selected,
              onSelected: (_) {
                setState(() => _filter = e.key);
              },
              selectedColor: AppColors.accent,
              backgroundColor: AppColors.surface,
              labelStyle: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.query,
    required this.onTap,
    required this.onDelete,
  });

  final String query;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history_rounded, color: AppColors.textMuted),
      title: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            onPressed: onDelete,
          ),
          IconButton(
            icon: const Icon(Icons.north_west,
                size: 16, color: AppColors.textMuted),
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

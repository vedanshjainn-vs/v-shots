// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — ArchiveTune-style Search Tab (landing)
//
// The Search TAB is a landing with:
//   • a Material search bar (entry point) -> opens OnlineSearchScreen
//   • two tabs: Explore (Mood & Genres) and For You (personalized suggestions)
//
// Data: real InnerTube search via the shared InnerTubeMusicService. Nothing
// hardcoded-fake; categories map to real mood queries (kMoodQueries). Playback
// stays on the existing official player via [onPlayTrack].
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  int _tab = 0; // 0 = Explore, 1 = For You

  // For You state.
  List<DiscoveryTrack> _suggestedSongs = const [];
  List<DiscoveryTrack> _suggestedArtists = const [];
  List<DiscoveryTrack> _trendingAlbums = const [];
  bool _loadingSuggestions = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnlineSearchScreen(
          service: widget.service,
          onPlayTrack: widget.onPlayTrack,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// For You: seed from most-played songs (songPlayCounts) + recently played,
  /// then fetch related content via real search. Fallback to trending.
  Future<void> _loadSuggestions() async {
    setState(() => _loadingSuggestions = true);
    final lib = LocalLibrary.instance;
    final recent = lib.recentlyPlayed.value;
    final playedIds = lib.songPlayCounts.keys.toList();

    final seedTitles = <String>[];
    for (final r in recent.take(6)) {
      final t = (r['title'] as String?)?.trim() ?? '';
      if (t.isNotEmpty && seedTitles.length < 6) seedTitles.add(t);
    }
    for (final id in playedIds.take(6)) {
      if (seedTitles.length >= 6) break;
      final r = recent.cast<Map<String, dynamic>?>().firstWhere(
            (x) => x?['id'] == id,
            orElse: () => null,
          );
      final t = r?['title'] as String? ?? '';
      if (t.isNotEmpty && !seedTitles.contains(t)) seedTitles.add(t);
    }

    final songs = <DiscoveryTrack>[];
    final seen = <String>{};
    if (seedTitles.isNotEmpty) {
      for (final seed in seedTitles) {
        try {
          final related = await widget.service.search('$seed songs', count: 8);
          for (final t in related) {
            if (songs.length >= 12) break;
            if (seen.add(t.id)) songs.add(t);
          }
        } catch (_) {}
        if (songs.length >= 12) break;
      }
    }
    if (songs.isEmpty) {
      try {
        songs.addAll(await widget.service.search('trending songs', count: 12));
      } catch (_) {}
    }

    // Artists from top artist play counts.
    final artists = <DiscoveryTrack>[];
    final aSeen = <String>{};
    final topArtists = lib.artistPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final a in topArtists.take(6)) {
      try {
        final r = await widget.service.search('${a.key} artist', count: 3);
        for (final t in r) {
          if (artists.length >= 12) break;
          if (aSeen.add(t.id)) artists.add(t);
        }
      } catch (_) {}
      if (artists.length >= 12) break;
    }
    if (artists.isEmpty) {
      try {
        artists.addAll(await widget.service.search('top artists', count: 8));
      } catch (_) {}
    }

    // Trending albums from new releases + top albums searches.
    final albums = <DiscoveryTrack>[];
    final alSeen = <String>{};
    try {
      final a1 = await widget.service.search('new album 2026', count: 6);
      final a2 = await widget.service.search('top albums', count: 6);
      for (final t in [...a1, ...a2]) {
        if (albums.length >= 12) break;
        if (alSeen.add(t.id)) albums.add(t);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _suggestedSongs = songs.take(12).toList();
      _suggestedArtists = artists.take(12).toList();
      _trendingAlbums = albums.take(12).toList();
      _loadingSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            _buildTabs(),
            Expanded(
              child: _tab == 0 ? _buildExplore() : _buildForYou(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: InkWell(
        onTap: _openSearch,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.textMuted),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search songs, artists, albums...',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
              ),
              Icon(Icons.language_rounded,
                  color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          _tabChip('Explore', 0),
          const SizedBox(width: 10),
          _tabChip('For You', 1),
        ],
      ),
    );
  }

  Widget _tabChip(String label, int index) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildExplore() {
    final moods =
        kMoodQueries.keys.where((m) => !_skipForExplore.contains(m)).toList();
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 78,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: moods.length,
      itemBuilder: (context, i) {
        final mood = moods[i];
        return _MoodCard(
          mood: mood,
          color: _colorFor(mood),
          onTap: () async {
            unawaited(HapticFeedback.selectionClick());
            final nav = Navigator.of(context);
            final tracks = await widget.service.search(mood, count: 20);
            if (!mounted) return;
            unawaited(
              nav.push(
                MaterialPageRoute<void>(
                  builder: (_) => _MoodResultsScreen(
                    title: mood,
                    tracks: tracks,
                    service: widget.service,
                    onPlayTrack: widget.onPlayTrack,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static const _skipForExplore = <String>{
    'Trending',
    'For You',
    'Energize',
  };

  Color _colorFor(String mood) {
    const map = <String, Color>{
      'Workout': Color(0xFFFF5722),
      'Romance': Color(0xFFE91E63),
      'Sad': Color(0xFF3F51B5),
      'Party': Color(0xFFFF9800),
      'Focus': Color(0xFF00BCD4),
      'Chill': Color(0xFF4CAF50),
      'Sleep': Color(0xFF607D8B),
      'Devotional': Color(0xFFFFC107),
      'Relax': Color(0xFF9C27B0),
      'Bollywood': Color(0xFFE91E63),
      'Hindi': Color(0xFF9C27B0),
      'Punjabi': Color(0xFFFF9800),
      'English': Color(0xFF2196F3),
      'EDM': Color(0xFF00BCD4),
      'Hip-Hop': Color(0xFF673AB7),
      'Lo-fi': Color(0xFF4CAF50),
      'Global': Color(0xFF009688),
    };
    return map[mood] ?? AppColors.accent;
  }

  Widget _buildForYou() {
    if (_loadingSuggestions) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _SuggestionSection(
          title: 'Suggested Songs',
          tracks: _suggestedSongs,
          onPlayTrack: widget.onPlayTrack,
        ),
        _SuggestionSection(
          title: 'Suggested Artists',
          tracks: _suggestedArtists,
          onPlayTrack: widget.onPlayTrack,
        ),
        _SuggestionSection(
          title: 'Trending Albums',
          tracks: _trendingAlbums,
          onPlayTrack: widget.onPlayTrack,
        ),
      ],
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({
    required this.mood,
    required this.color,
    required this.onTap,
  });

  final String mood;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Stack(
          children: [
            // Left colored stripe.
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  mood,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionSection extends StatelessWidget {
  const _SuggestionSection({
    required this.title,
    required this.tracks,
    required this.service,
    required this.onPlayTrack,
  });

  final String title;
  final List<DiscoveryTrack> tracks;
  final InnerTubeMusicService service;
  final OnPlayTrack onPlayTrack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          if (tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Nothing yet — play some songs first.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tracks.length,
              itemBuilder: (context, i) {
                final t = tracks[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AppImage(t.artwork, width: 52, height: 52),
                  ),
                  title: Text(t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(t.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                  trailing: const Icon(Icons.play_circle_fill_rounded,
                      color: AppColors.accent, size: 28),
                  onTap: () {
                    final q = tracks.map((x) => x.toTrackMap()).toList();
                    final idx = q.indexWhere((x) => x['id'] == t.id);
                    onPlayTrack(t.toTrackMap(), q, idx < 0 ? 0 : idx);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MoodResultsScreen extends StatefulWidget {
  const _MoodResultsScreen({
    required this.title,
    required this.tracks,
    required this.onPlayTrack,
  });

  final String title;
  final List<DiscoveryTrack> tracks;
  final OnPlayTrack onPlayTrack;

  @override
  State<_MoodResultsScreen> createState() => _MoodResultsScreenState();
}

class _MoodResultsScreenState extends State<_MoodResultsScreen> {
  late List<DiscoveryTrack> _tracks;
  late String _selected;
  bool _loading = false;

  static const _catalogs = <String, List<Map<String, String>>>{
    'Romantic': [
      {'title': 'Bollywood Romance', 'query': 'bollywood romantic songs'},
      {'title': 'Indian Romance', 'query': 'indian romantic songs'},
      {'title': 'Sweetheart & Romance', 'query': 'sweetheart love songs'},
      {'title': '90s Romantic', 'query': '90s bollywood romantic songs'},
      {'title': 'Romantic Hindi', 'query': 'romantic hindi songs'},
    ],
    'Bollywood': [
      {'title': 'Bollywood Romance', 'query': 'bollywood romantic songs'},
      {'title': 'Bollywood Classics', 'query': 'bollywood classic hits'},
      {'title': 'Bollywood Party', 'query': 'bollywood party songs'},
    ],
    'Hindi': [
      {'title': 'Hindi Romance', 'query': 'hindi romantic songs'},
      {'title': 'Hindi Classics', 'query': 'old hindi classics'},
      {'title': 'Hindi Trending', 'query': 'latest hindi songs'},
    ],
  };

  List<Map<String, String>> get _sections =>
      _catalogs[widget.title] ?? [
            {'title': '${widget.title} Mix', 'query': '${widget.title} songs'},
            {'title': 'Popular ${widget.title}', 'query': 'popular ${widget.title} songs'},
            {'title': 'New ${widget.title}', 'query': 'new ${widget.title} songs'},
          ];

  @override
  void initState() {
    super.initState();
    _tracks = widget.tracks;
    _selected = _sections.first['title']!;
  }

  Future<void> _openSection(Map<String, String> section) async {
    setState(() { _selected = section['title']!; _loading = true; });
    try {
      final result = await _searchLive(section['query']!);
      if (mounted) setState(() => _tracks = result);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // The service is supplied by the parent screen through the live search
  // result for now; this keeps this catalog screen usable without mock data.
  Future<List<DiscoveryTrack>> _searchLive(String query) async {
    return widget.service.search(query, count: 30);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Text('Explore this mood', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          SizedBox(
            height: 100,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _sections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final section = _sections[i];
                final selected = section['title'] == _selected;
                return GestureDetector(
                  onTap: () => _openSection(section),
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        _catalogColor(i).withValues(alpha: .95),
                        _catalogColor(i).withValues(alpha: .55),
                      ]),
                      borderRadius: BorderRadius.circular(16),
                      border: selected ? Border.all(color: Colors.white, width: 2) : null,
                    ),
                    child: Align(alignment: Alignment.bottomLeft, child: Text(section['title']!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(children: [Expanded(child: Text(_selected, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))), if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))]),
          ),
          if (_tracks.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No live results', style: TextStyle(color: AppColors.textMuted))))
          else
            ..._tracks.map((t) => _songTile(t)),
        ],
      ),
    );
  }

  Color _catalogColor(int i) => [Colors.pink.shade700, Colors.deepPurple.shade600, Colors.orange.shade700, Colors.teal.shade700, Colors.indigo.shade600][i % 5];

  Widget _songTile(DiscoveryTrack t) => ListTile(
    leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: AppImage(t.artwork, width: 54, height: 54)),
    title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
    trailing: const Icon(Icons.play_circle_fill_rounded, color: AppColors.accent, size: 30),
    onTap: () { final q = _tracks.map((x) => x.toTrackMap()).toList(); final idx = q.indexWhere((x) => x['id'] == t.id); widget.onPlayTrack(t.toTrackMap(), q, idx < 0 ? 0 : idx); },
  );
}

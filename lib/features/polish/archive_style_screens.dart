import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/cache/search_cache.dart';
import '../../core/providers/adapters/youtube/youtube_data_api_client.dart';
import '../../core/providers/provider_bootstrap.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';

typedef TrackPlayCallback = Future<void> Function(
  BuildContext context,
  Map<String, dynamic> track,
  List<Map<String, dynamic>> queue,
  int index,
);

final _polishApi = YouTubeDataApiClient();
final _polishRepository = buildMusicRepository(apiClient: _polishApi);

class ArchiveStyleHomeScreen extends StatefulWidget {
  const ArchiveStyleHomeScreen({required this.onPlay, super.key});
  final TrackPlayCallback onPlay;

  @override
  State<ArchiveStyleHomeScreen> createState() => _ArchiveStyleHomeScreenState();
}

class _ArchiveStyleHomeScreenState extends State<ArchiveStyleHomeScreen> {
  final Map<String, List<Map<String, dynamic>>> _sections = {};
  final Set<String> _loading = {};
  final _layout = const [
    ('Quick picks', 'trending songs official music video 2026'),
    ('Made for you', 'new music friday official audio 2026'),
    ('India hits', 'top bollywood hindi songs official music video'),
    ('Punjabi wave', 'latest punjabi pop hits official audio'),
    ('Chill & lofi', 'chill lofi late night beats official audio'),
    ('International pop', 'billboard top global pop hits official audio'),
  ];

  @override
  void initState() {
    super.initState();
    for (final item in _layout) {
      unawaited(_load(item.$1, item.$2));
    }
  }

  Future<void> _load(String title, String query) async {
    if (!_loading.add(query)) return;
    try {
      final cached = SearchCache.instance.get(query);
      if (cached != null && mounted) {
        setState(() => _sections[query] = _dedupe(cached));
      }
      final fresh = await _polishRepository.search(
        query,
        limit: 18,
        excludeIds: LocalLibrary.instance.recentlyShownIds,
      );
      if (!mounted) return;
      final clean = _dedupe(fresh);
      SearchCache.instance.set(query, clean);
      setState(() => _sections[query] = clean);
    } finally {
      _loading.remove(query);
    }
  }

  List<Map<String, dynamic>> _dedupe(List<Map<String, dynamic>> input) {
    final seen = <String>{};
    return input.where((item) {
      final id = item['id'] as String? ?? '';
      return id.isNotEmpty && seen.add(id);
    }).toList();
  }

  Future<void> _refresh() async {
    for (final item in _layout) {
      await _load(item.$1, item.$2);
    }
  }

  void _openCategory(BuildContext context, String query) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _CategoryResultsScreen(query: query, onPlay: widget.onPlay),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              titleSpacing: 20,
              title: const Text(
                'ArchiveTune',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              actions: [
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Made for you',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    _MoodPills(onTap: (query) => _openCategory(context, query)),
                  ],
                ),
              ),
            ),
            for (final item in _layout) _buildSection(context, item.$1, item.$2),
            SliverToBoxAdapter(child: _recentlyPlayed(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String query) {
    final tracks = _sections[query] ?? const <Map<String, dynamic>>[];
    if (tracks.isEmpty && _loading.contains(query)) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 205,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => Container(
              width: 152,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      );
    }
    if (tracks.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 205,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: tracks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return _TrackCard(
                    track: track,
                    onTap: () => widget.onPlay(context, track, tracks, index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentlyPlayed(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: LocalLibrary.instance.recentlyPlayed,
      builder: (context, recent, _) {
        final seen = <String>{};
        final display = recent.where((item) {
          final id = item['id'] as String? ?? '';
          return id.isNotEmpty && seen.add(id);
        }).take(12).toList();
        if (display.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Recently played',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 205,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: display.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _TrackCard(
                    track: display[index],
                    onTap: () => widget.onPlay(
                      context,
                      display[index],
                      display,
                      index,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MoodPills extends StatelessWidget {
  const _MoodPills({required this.onTap});
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    const moods = [
      ('Romance', 'romantic love songs official audio hindi'),
      ('Feel good', 'feel good pop hits official audio'),
      ('Relax', 'chill lofi relaxing music official audio'),
      ('Energize', 'workout hype songs official audio'),
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: moods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text(moods[i].$1, style: const TextStyle(fontWeight: FontWeight.w700)),
          onPressed: () => onTap(moods[i].$2),
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.track, required this.onTap});
  final Map<String, dynamic> track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 152,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: AppImage(track['artwork'] as String?, fit: BoxFit.cover),
                  ),
                ),
                const Positioned(
                  right: 9,
                  bottom: 9,
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: AppColors.accent,
                    child: Icon(Icons.play_arrow_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              track['title'] as String? ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            Text(
              track['artist'] as String? ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class ArchiveStyleSearchScreen extends StatefulWidget {
  const ArchiveStyleSearchScreen({required this.onPlay, super.key});
  final TrackPlayCallback onPlay;

  @override
  State<ArchiveStyleSearchScreen> createState() => _ArchiveStyleSearchScreenState();
}

class _ArchiveStyleSearchScreenState extends State<ArchiveStyleSearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  String? _nextPageToken;
  bool _loading = false;
  bool _loadingMore = false;
  bool _focused = false;
  String _query = '';

  static const _categories = [
    ('Hindi', 'hindi songs official audio'),
    ('Bollywood', 'bollywood songs official music video'),
    ('Punjabi', 'punjabi hits official audio'),
    ('English', 'english pop hits official audio'),
    ('Romantic', 'romantic love songs official audio'),
    ('Sad', 'sad emotional songs official audio'),
    ('Chill', 'chill lofi relaxing music official audio'),
    ('Party', 'party dance hits official audio'),
    ('Lo-fi', 'lofi beats official audio'),
    ('Workout', 'workout gym motivation songs official'),
    ('Devotional', 'devotional bhajan official audio'),
    ('Global', 'global pop hits official audio'),
    ('Hip-hop', 'hip hop rap hits official audio'),
    ('EDM', 'edm electronic dance hits official audio'),
    ('Indie', 'indie acoustic songs official audio'),
    ('J-pop', 'j-pop hits official audio'),
  ];

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    _scroll.addListener(_onScroll);
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _focused = _focus.hasFocus);
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 500) {
      unawaited(_loadMore());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _query = '';
        _results = [];
        _nextPageToken = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    setState(() {
      _query = query;
      _loading = true;
      _results = [];
      _nextPageToken = null;
    });
    try {
      final page = await _polishApi.searchMusicVideosPaginated(
        query,
        maxResults: 24,
      );
      if (!mounted) return;
      final seen = <String>{};
      final results = page.items
          .map(_toTrack)
          .where((item) => seen.add(item['id'] as String))
          .toList();
      SearchCache.instance.set(query, results);
      unawaited(LocalLibrary.instance.recordRecentSearch(query));
      setState(() {
        _results = results;
        _nextPageToken = page.nextPageToken;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _nextPageToken == null || _query.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _polishApi.searchMusicVideosPaginated(
        _query,
        maxResults: 24,
        pageToken: _nextPageToken,
      );
      if (!mounted) return;
      final seen = _results.map((item) => item['id'] as String).toSet();
      final extra = page.items
          .map(_toTrack)
          .where((item) => seen.add(item['id'] as String))
          .toList();
      setState(() {
        _results = [..._results, ...extra];
        _nextPageToken = page.nextPageToken;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Map<String, dynamic> _toTrack(YouTubeVideoItem item) => {
        'id': item.id,
        'title': item.title,
        'artist': item.channelTitle,
        'artwork': item.thumbnailUrl,
        'duration': item.durationSeconds,
      };

  void _selectCategory(String query) {
    _controller.text = query;
    _search(query);
  }

  @override
  Widget build(BuildContext context) {
    final recent = LocalLibrary.instance.recentSearches.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _focused ? AppColors.accent : AppColors.border,
                          width: _focused ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: AppColors.textMuted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focus,
                              onChanged: _onChanged,
                              onSubmitted: _search,
                              textInputAction: TextInputAction.search,
                              style: const TextStyle(fontSize: 16),
                              decoration: const InputDecoration(
                                hintText: 'Songs, artists, albums, playlists…',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          if (_controller.text.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                _controller.clear();
                                _onChanged('');
                              },
                              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_query.isEmpty) ...[
              if (recent.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: recent.take(8).map((item) {
                        final query = item['query'] as String? ?? '';
                        return ActionChip(
                          label: Text(query),
                          onPressed: () => _selectCategory(query),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text('Browse all', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _categories[index];
                      return _CategoryCard(
                        title: item.$1,
                        index: index,
                        onTap: () => _selectCategory(item.$2),
                      );
                    },
                    childCount: _categories.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.95,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ] else if (_loading) ...[
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
              ),
            ] else if (_results.isEmpty) ...[
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No music found', style: TextStyle(color: AppColors.textMuted))),
              ),
            ] else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Text(
                    'Results for “$_query”',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = _results[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AppImage(track['artwork'] as String?, width: 58, height: 58, fit: BoxFit.cover),
                      ),
                      title: Text(track['title'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text(track['artist'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      trailing: const Icon(Icons.play_circle_fill_rounded, color: AppColors.accent, size: 30),
                      onTap: () => widget.onPlay(context, track, _results, index),
                    );
                  },
                  childCount: _results.length,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: _loadingMore
                        ? const CircularProgressIndicator(color: AppColors.accent)
                        : Text(
                            _nextPageToken == null ? 'End of results' : 'Scroll for more',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.title, required this.index, required this.onTap});
  final String title;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const colors = [
      AppColors.accent,
      Color(0xFFFF8A65),
      Color(0xFF64B5F6),
      Color(0xFFBA68C8),
      Color(0xFFFFB74D),
      Color(0xFF81C784),
      Color(0xFF4DD0E1),
      Color(0xFFE57373),
    ];
    final color = colors[index % colors.length];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: .34), color.withValues(alpha: .12)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        padding: const EdgeInsets.all(14),
        alignment: Alignment.bottomLeft,
        child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _CategoryResultsScreen extends StatefulWidget {
  const _CategoryResultsScreen({required this.query, required this.onPlay});
  final String query;
  final TrackPlayCallback onPlay;

  @override
  State<_CategoryResultsScreen> createState() => _CategoryResultsScreenState();
}

class _CategoryResultsScreenState extends State<_CategoryResultsScreen> {
  List<Map<String, dynamic>> tracks = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final result = await _polishRepository.search(widget.query, limit: 24);
    if (mounted) setState(() => tracks = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Browse', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: tracks.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 120),
              itemCount: tracks.length,
              itemBuilder: (context, index) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppImage(tracks[index]['artwork'] as String?, width: 58, height: 58, fit: BoxFit.cover),
                ),
                title: Text(tracks[index]['title'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(tracks[index]['artist'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted)),
                trailing: const Icon(Icons.play_circle_fill_rounded, color: AppColors.accent),
                onTap: () => widget.onPlay(context, tracks[index], tracks, index),
              ),
            ),
    );
  }
}

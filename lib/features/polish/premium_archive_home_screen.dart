import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/cache/search_cache.dart';
import '../../core/providers/adapters/youtube/youtube_data_api_client.dart';
import '../../core/providers/provider_bootstrap.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';

typedef HomeTrackPlayCallback = Future<void> Function(
  BuildContext context,
  Map<String, dynamic> track,
  List<Map<String, dynamic>> queue,
  int index,
);

class PremiumArchiveHomeScreen extends StatefulWidget {
  const PremiumArchiveHomeScreen({required this.onPlay, super.key});

  final HomeTrackPlayCallback onPlay;

  @override
  State<PremiumArchiveHomeScreen> createState() =>
      _PremiumArchiveHomeScreenState();
}

class _HomeShelf {
  const _HomeShelf(this.title, this.query, {this.subtitle});

  final String title;
  final String query;
  final String? subtitle;
}

class _PremiumArchiveHomeScreenState extends State<PremiumArchiveHomeScreen> {
  final _api = YouTubeDataApiClient();
  late final _repository = buildMusicRepository(apiClient: _api);

  List<_HomeShelf> _layout = const [
    _HomeShelf('Quick Picks', 'trending songs today official audio 2026'),
    _HomeShelf('Made For You', 'popular new music official audio 2026'),
    _HomeShelf(
        'New Releases', 'new hindi punjabi english songs 2026 official audio'),
    _HomeShelf('Trending Now', 'viral trending music hits 2026 official audio'),
    _HomeShelf(
        'India Hits', 'top bollywood hindi songs official music video 2026'),
    _HomeShelf('Punjabi Wave', 'latest punjabi pop hits official audio 2026'),
    _HomeShelf('Chill & Lofi', 'chill lofi late night beats official audio'),
    _HomeShelf(
        'International Pop', 'billboard global pop hits official audio 2026'),
  ];

  final Map<String, List<Map<String, dynamic>>> _shelves = {};
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHome());
  }

  String _id(Map<String, dynamic> track) => track['id'] as String? ?? '';

  List<Map<String, dynamic>> _dedupe(List<Map<String, dynamic>> tracks) {
    final seen = <String>{};
    return tracks.where((track) {
      final id = _id(track);
      return id.isNotEmpty && seen.add(id);
    }).toList();
  }

  List<Map<String, dynamic>> _tracks(_HomeShelf shelf) {
    return (_shelves[shelf.query] ?? const <Map<String, dynamic>>[])
        .take(12)
        .toList();
  }

  Map<String, dynamic>? get _hero {
    for (final shelf in _layout) {
      final tracks = _tracks(shelf);
      if (tracks.isNotEmpty) return tracks.first;
    }
    return null;
  }

  Future<void> _loadHome({bool force = false}) async {
    if (_refreshing) return;
    if (mounted) setState(() => _refreshing = true);

    try {
      final recent =
          _dedupe(LocalLibrary.instance.recentlyPlayed.value).take(12).toList();
      final artist = recent.isNotEmpty
          ? (recent.first['artist'] as String? ?? '').trim()
          : '';

      if (artist.isNotEmpty) {
        _layout = [
          const _HomeShelf(
              'Quick Picks', 'trending songs today official audio 2026'),
          const _HomeShelf(
              'Made For You', 'popular new music official audio 2026'),
          _HomeShelf(
            'Because You Listened To',
            'songs like $artist official audio',
            subtitle: artist,
          ),
          ..._layout.skip(2),
        ];
      }

      final reserved = <String>{
        ...recent.map(_id).where((id) => id.isNotEmpty),
      };
      final fetched = <String, List<Map<String, dynamic>>>{};

      await Future.wait(_layout.map((shelf) async {
        try {
          final cached = SearchCache.instance.get(shelf.query);
          if (!force && cached != null && cached.isNotEmpty) {
            fetched[shelf.query] = _dedupe(cached);
          }

          final fresh = await _repository.search(
            shelf.query,
            limit: 20,
            excludeIds: {
              ...LocalLibrary.instance.recentlyShownIds,
              ...reserved,
            },
          );
          final clean = _dedupe(fresh);
          if (clean.isNotEmpty) {
            SearchCache.instance.set(shelf.query, clean);
            fetched[shelf.query] = clean;
          }
        } catch (_) {
          // A single failed shelf must not blank the rest of Home.
        }
      }));

      // Prevent the same track from appearing in multiple Home shelves.
      final used = <String>{...reserved};
      final cleanedShelves = <String, List<Map<String, dynamic>>>{};
      for (final shelf in _layout) {
        final unique = <Map<String, dynamic>>[];
        for (final track
            in fetched[shelf.query] ?? const <Map<String, dynamic>>[]) {
          final id = _id(track);
          if (id.isNotEmpty && used.add(id)) {
            unique.add(track);
          }
          if (unique.length == 12) break;
        }
        cleanedShelves[shelf.query] = unique;
      }

      if (!mounted) return;
      setState(() {
        _shelves
          ..clear()
          ..addAll(cleanedShelves);
        _loading = false;
        _refreshing = false;
        _error = _shelves.values.every((items) => items.isEmpty)
            ? 'Could not load music right now.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = 'Could not load music right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final hero = _hero;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        onRefresh: () => _loadHome(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(greeting)),
            SliverToBoxAdapter(child: _buildSearch()),
            SliverToBoxAdapter(child: _buildChips()),
            if (_loading && hero == null)
              const SliverToBoxAdapter(child: _HeroSkeleton())
            else if (hero != null)
              SliverToBoxAdapter(child: _buildHero(hero)),
            if (_error != null && hero == null)
              SliverToBoxAdapter(child: _buildError()),
            for (final shelf in _layout)
              if (_tracks(shelf).isNotEmpty)
                SliverToBoxAdapter(child: _buildShelf(shelf)),
            SliverToBoxAdapter(child: _buildRecentlyPlayed()),
            SliverToBoxAdapter(child: _buildArtists()),
            SliverToBoxAdapter(child: _buildMoods()),
            const SliverToBoxAdapter(child: SizedBox(height: 150)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String greeting) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Vedansh 👋',
                  style: TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          const _CircleButton(icon: Icons.notifications_none_rounded),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 21,
            backgroundColor: AppColors.surfaceElevated,
            child: Icon(Icons.person_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Row(
          children: [
            SizedBox(width: 17),
            Icon(Icons.search_rounded,
                color: AppColors.textSecondary, size: 23),
            SizedBox(width: 12),
            Text(
              'Search songs, artists, albums...',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChips() {
    const labels = [
      'Quick Picks',
      'Made For You',
      'Trending',
      'New Releases',
      'Recently Played',
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final active = index == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: active ? AppColors.primaryGradient : null,
              color: active ? null : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? Colors.transparent : AppColors.border,
              ),
            ),
            child: Text(
              labels[index],
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero(Map<String, dynamic> track) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        height: 218,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppImage(track['artwork'] as String?, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x99070A12), Color(0xDD070A12)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 20,
              top: 18,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.hotPink.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'MADE FOR YOU',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 78,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track['title'] as String? ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track['artist'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => unawaited(_play(track)),
                  child: const SizedBox(
                    width: 54,
                    height: 54,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.background,
                      size: 31,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShelf(_HomeShelf shelf) {
    final tracks = _tracks(shelf);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    shelf.title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.35,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _showAll(shelf),
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
          if (shelf.subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 5),
              child: Text(
                shelf.subtitle!,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          SizedBox(
            height: 216,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemCount: tracks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 13),
              itemBuilder: (context, index) {
                final track = tracks[index];
                return _MusicCard(
                  track: track,
                  onTap: () => widget.onPlay(context, track, tracks, index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyPlayed() {
    final tracks =
        _dedupe(LocalLibrary.instance.recentlyPlayed.value).take(10).toList();
    if (tracks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Recently Played',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 82,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: tracks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final track = tracks[index];
                return GestureDetector(
                  onTap: () => widget.onPlay(context, track, tracks, index),
                  child: Container(
                    width: 230,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: SizedBox(
                            width: 58,
                            height: 58,
                            child: AppImage(
                              track['artwork'] as String?,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track['title'] as String? ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                track['artist'] as String? ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.play_circle_fill_rounded,
                          color: AppColors.accent,
                          size: 29,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtists() {
    final pool = _layout.expand(_tracks).toList();
    final seen = <String>{};
    final artists = pool
        .where((track) {
          final artist = track['artist'] as String? ?? '';
          return artist.trim().isNotEmpty && seen.add(artist.toLowerCase());
        })
        .take(10)
        .toList();
    if (artists.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Popular Artists',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: artists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 17),
              itemBuilder: (_, index) {
                final artist = artists[index];
                return SizedBox(
                  width: 82,
                  child: Column(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 74,
                          height: 74,
                          child: AppImage(
                            artist['artwork'] as String?,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        artist['artist'] as String,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoods() {
    const moods = [
      ('Romantic', Icons.favorite_rounded, Color(0xFFB42368)),
      ('Chill', Icons.nightlight_round, Color(0xFF2563EB)),
      ('Party', Icons.celebration_rounded, Color(0xFF7C3AED)),
      ('Workout', Icons.bolt_rounded, Color(0xFFEA580C)),
      ('Sad', Icons.cloud_rounded, Color(0xFF475569)),
      ('Focus', Icons.auto_awesome_rounded, Color(0xFF0F766E)),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Moods & Vibes',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 106,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: moods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final mood = moods[index];
                return Container(
                  width: 142,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: mood.$3,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: mood.$3.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(mood.$2, color: Colors.white, size: 24),
                      Text(
                        mood.$1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _play(Map<String, dynamic> track) async {
    final queue = _tracks(_layout.first);
    final index = queue.indexWhere((item) => _id(item) == _id(track));
    await widget.onPlay(
      context,
      track,
      queue.isEmpty ? [track] : queue,
      index < 0 ? 0 : index,
    );
  }

  Future<void> _showAll(_HomeShelf shelf) async {
    final tracks = _tracks(shelf);
    if (tracks.isEmpty || !mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.78,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              itemCount: tracks.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                if (index == 0) {
                  return Text(
                    shelf.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                }
                final track = tracks[index - 1];
                return ListTile(
                  tileColor: AppColors.surface2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: AppImage(
                        track['artwork'] as String?,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  title: Text(
                    track['title'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(track['artist'] as String? ?? ''),
                  trailing: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: AppColors.accent,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(
                      widget.onPlay(context, track, tracks, index - 1),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => _loadHome(force: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicCard extends StatelessWidget {
  const _MusicCard({required this.track, required this.onTap});

  final Map<String, dynamic> track;
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
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: AppImage(
                      track['artwork'] as String?,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  right: 9,
                  bottom: 9,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              track['title'] as String? ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              track['artist'] as String? ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () {},
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: AppColors.textSecondary, size: 22),
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        height: 218,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(25),
        ),
      ),
    );
  }
}

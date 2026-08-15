import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/providers/adapters/youtube/youtube_data_api_client.dart';
import '../../core/providers/provider_bootstrap.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';
import 'archive_style_screens.dart';

final _discoveryApi = YouTubeDataApiClient();
final _discoveryRepository = buildMusicRepository(apiClient: _discoveryApi);

class PremiumDiscoveryScreen extends StatefulWidget {
  const PremiumDiscoveryScreen({required this.onPlay, super.key});
  final TrackPlayCallback onPlay;

  @override
  State<PremiumDiscoveryScreen> createState() => _PremiumDiscoveryScreenState();
}

class _PremiumDiscoveryScreenState extends State<PremiumDiscoveryScreen> {
  static const _genres = [
    ('For You', 'trending songs official music video 2026'),
    ('Moods', 'feel good mood music official audio'),
    ('Romance', 'romantic love songs official audio'),
    ('Sad', 'sad emotional songs official audio'),
    ('Chill', 'chill lofi relaxing music official audio'),
    ('Party', 'party dance hits official audio'),
    ('Workout', 'workout gym motivation songs official'),
    ('Hindi', 'hindi songs official audio'),
    ('Bollywood', 'bollywood songs official music video'),
    ('Punjabi', 'punjabi hits official audio'),
    ('English Pop', 'english pop hits official audio'),
    ('Hip-Hop', 'hip hop rap hits official audio'),
    ('EDM', 'edm electronic dance hits official audio'),
    ('Indie', 'indie acoustic songs official audio'),
    ('Lo-fi', 'lofi beats official audio'),
    ('Devotional', 'devotional bhajan official audio'),
    ('Bengali', 'bengali songs official audio'),
    ('Bhojpuri', 'bhojpuri hits official audio'),
    ('Gujarati', 'gujarati songs official audio'),
    ('Haryanvi', 'haryanvi songs official audio'),
    ('Marathi', 'marathi songs official audio'),
    ('Tamil', 'tamil hits official audio'),
    ('Telugu', 'telugu hits official audio'),
    ('Malayalam', 'malayalam songs official audio'),
    ('Kannada', 'kannada songs official audio'),
    ('Arabic', 'arabic hits official audio'),
    ('African', 'afrobeats african hits official audio'),
    ('K-pop', 'k-pop hits official audio'),
    ('J-pop', 'j-pop hits official audio'),
    ('Classical', 'classical music official audio'),
    ('Folk', 'folk music official audio'),
    ('Global', 'global pop hits official audio'),
  ];

  final PageController _pageController = PageController();
  List<Map<String, dynamic>> _items = [];
  int _index = 0;
  int _selectedGenre = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load(_genres.first.$2));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load(String query) async {
    setState(() => _loading = true);
    try {
      final data = await _discoveryRepository.search(query, limit: 20);
      final seen = <String>{};
      final clean = data.where((item) {
        final id = item['id'] as String? ?? '';
        return id.isNotEmpty && seen.add(id);
      }).toList();
      if (!mounted) return;
      setState(() {
        _items = clean;
        _index = 0;
        _loading = false;
      });
      if (clean.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onPlay(context, clean.first, clean, 0);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectGenre(int index) {
    if (index == _selectedGenre) return;
    setState(() => _selectedGenre = index);
    unawaited(_load(_genres[index].$2));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    floating: true,
                    backgroundColor: AppColors.background,
                    title: const Text('Discover', style: TextStyle(fontWeight: FontWeight.w800)),
                    actions: [
                      IconButton(onPressed: () => _load(_genres[_selectedGenre].$2), icon: const Icon(Icons.refresh_rounded)),
                      const SizedBox(width: 8),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 48,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        scrollDirection: Axis.horizontal,
                        itemCount: _genres.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, index) => ChoiceChip(
                          label: Text(_genres[index].$1),
                          selected: index == _selectedGenre,
                          onSelected: (_) => _selectGenre(index),
                          selectedColor: AppColors.accent,
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.border),
                          labelStyle: TextStyle(
                            color: index == _selectedGenre ? Colors.white : AppColors.textMain,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Text(
                        '${_genres[_selectedGenre].$1} for you',
                        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.sizeOf(context).height * .62,
                      child: PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.vertical,
                        itemCount: _items.length,
                        onPageChanged: (index) {
                          setState(() => _index = index);
                          widget.onPlay(context, _items[index], _items, index);
                        },
                        itemBuilder: (context, index) {
                          final track = _items[index];
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: AppImage(track['artwork'] as String?, fit: BoxFit.cover),
                                ),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withValues(alpha: .8)],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 18,
                                  right: 18,
                                  bottom: 18,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(track['title'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                            const SizedBox(height: 4),
                                            Text(track['artist'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                                            const SizedBox(height: 8),
                                            Text('${index + 1} / ${_items.length}', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        onPressed: () => widget.onPlay(context, track, _items, index),
                                        icon: const Icon(Icons.play_circle_fill_rounded, size: 54, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _genres.skip(1).take(12).map((genre) => ActionChip(label: Text(genre.$1), onPressed: () => _selectGenre(_genres.indexOf(genre)))).toList(),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

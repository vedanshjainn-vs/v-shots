import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

typedef DiscoveryTrack = Map<String, dynamic>;
typedef DiscoveryPlayCallback = Future<void> Function(
  DiscoveryTrack track,
  List<DiscoveryTrack> queue,
  int index,
);

/// ArchiveTune-inspired Discovery UI for V Shots.
///
/// IMPORTANT:
/// - Discovery data comes from YouTube Music's public InnerTube browse/search
///   endpoints. This is a discovery/metadata client, not an audio downloader.
/// - Playback is delegated to the host app through [onPlayTrack], so V Shots
///   continues using its existing official YouTube player pipeline.
/// - The parser is deliberately defensive because InnerTube response shapes
///   can change.
class ArchiveTuneDiscoveryScreen extends StatefulWidget {
  const ArchiveTuneDiscoveryScreen({
    super.key,
    required this.onPlayTrack,
  });

  final DiscoveryPlayCallback onPlayTrack;

  @override
  State<ArchiveTuneDiscoveryScreen> createState() =>
      _ArchiveTuneDiscoveryScreenState();
}

class _ArchiveTuneDiscoveryScreenState
    extends State<ArchiveTuneDiscoveryScreen> {
  final _api = _InnerTubeDiscoveryApi();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  final List<_DiscoveryShelf> _shelves = [];
  final List<DiscoveryTrack> _searchResults = [];
  bool _loading = true;
  bool _searching = false;
  String? _error;
  String _selectedChip = 'For You';

  static const _chips = <String>[
    'For You',
    'Trending',
    'Hindi',
    'Punjabi',
    'English',
    'Romantic',
    'Sad',
    'Party',
    'Lo-fi',
  ];

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHome({String? chip}) async {
    final query = chip == null || chip == 'For You' ? null : chip;

    setState(() {
      _loading = true;
      _error = null;
      _selectedChip = chip ?? _selectedChip;
    });

    try {
      final shelves = await _api.discoveryHome(query: query);
      if (!mounted) return;
      setState(() {
        _shelves
          ..clear()
          ..addAll(shelves);
        _searchResults.clear();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Couldn’t load Discovery. Pull to retry.';
      });
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final results = await _api.search(query);
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

  Future<void> _play(
    DiscoveryTrack track,
    List<DiscoveryTrack> queue,
  ) async {
    final index = queue.indexWhere((t) => t['id'] == track['id']);
    if (index < 0) return;
    await widget.onPlayTrack(track, queue, index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF2DE2E6),
          backgroundColor: const Color(0xFF151922),
          onRefresh: () => _loadHome(),
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
                Text(
                  'Discovery',
                  style: const TextStyle(
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
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: TextField(
        controller: _searchController,
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
            color: const Color(0xFF2DE2E6),
          ),
          filled: true,
          fillColor: const Color(0xFF151922),
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
            onSelected: (_) => _loadHome(chip: chip),
            labelStyle: TextStyle(
              color: selected ? Colors.black : Colors.white70,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: const Color(0xFF2DE2E6),
            backgroundColor: const Color(0xFF151922),
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
              color: const Color(0xFF151922),
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
          const Icon(
            Icons.cloud_off_rounded,
            color: Colors.white38,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => _loadHome(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return _searching
        ? _buildLoading()
        : _ShelfView(
            shelf: _DiscoveryShelf(
              title: 'Search results',
              tracks: _searchResults,
            ),
            onPlay: _play,
          );
  }
}

class _ShelfView extends StatelessWidget {
  const _ShelfView({
    required this.shelf,
    required this.onPlay,
  });

  final _DiscoveryShelf shelf;
  final Future<void> Function(
    DiscoveryTrack,
    List<DiscoveryTrack>,
  ) onPlay;

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
  const _DiscoveryCard({
    required this.track,
    required this.onTap,
  });

  final DiscoveryTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = track['artwork'] as String?;
    final title = (track['title'] as String?) ?? 'Unknown';
    final artist = (track['artist'] as String?) ?? '';

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
                    child: image == null
                        ? Container(
                            color: const Color(0xFF151922),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Colors.white24,
                              size: 38,
                            ),
                          )
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF151922),
                              child: const Icon(
                                Icons.music_note_rounded,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    right: 9,
                    bottom: 9,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF2DE2E6),
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
              title,
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
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryShelf {
  const _DiscoveryShelf({
    required this.title,
    required this.tracks,
    this.subtitle,
  });

  final String title;
  final List<DiscoveryTrack> tracks;
  final String? subtitle;
}

/// Minimal InnerTube client. No YouTube Data API key is required for discovery.
class _InnerTubeDiscoveryApi {
  static const _host = 'https://music.youtube.com/youtubei/v1';

  final http.Client _client = http.Client();

  Map<String, dynamic> get _context => {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20260101.01.00',
          'hl': 'en',
          'gl': 'IN',
        },
      };

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      Uri.parse('$_host/$endpoint?prettyPrint=false'),
      headers: const {
        'Content-Type': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130 Safari/537.36',
      },
      body: jsonEncode({
        'context': _context,
        ...body,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('InnerTube ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<_DiscoveryShelf>> discoveryHome({String? query}) async {
    if (query != null && query.trim().isNotEmpty) {
      final tracks = await search(query);
      return [
        _DiscoveryShelf(title: query, tracks: tracks),
      ];
    }

    final data = await _post('browse', {'browseId': 'FEmusic_home'});
    final sections = <_DiscoveryShelf>[];

    void walk(dynamic node, {String? title}) {
      if (node is Map<String, dynamic>) {
        final shelfTitle = _text(node['title']) ?? title;
        final tracks = _extractTracks(node);

        if (tracks.isNotEmpty && shelfTitle != null) {
          sections.add(
            _DiscoveryShelf(
              title: shelfTitle,
              tracks: tracks.take(20).toList(),
            ),
          );
        }

        for (final value in node.values) {
          if (value is Map || value is List) {
            walk(value, title: shelfTitle);
          }
        }
      } else if (node is List) {
        for (final item in node) {
          walk(item, title: title);
        }
      }
    }

    walk(data);

    final unique = <String, _DiscoveryShelf>{};
    for (final shelf in sections) {
      final key = shelf.title.trim().toLowerCase();
      if (key.isEmpty) continue;
      if (!unique.containsKey(key)) unique[key] = shelf;
    }

    return unique.values.take(12).toList();
  }

  Future<List<DiscoveryTrack>> search(String query) async {
    final data = await _post('search', {
      'query': query,
      'params': 'EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D',
    });

    final result = <DiscoveryTrack>[];

    void walk(dynamic node) {
      if (node is Map<String, dynamic>) {
        final id = node['videoId'] as String?;
        final title = _text(node['title']);
        if (id != null && title != null) {
          final thumbs = _thumbnails(node['thumbnail']);
          result.add({
            'id': id,
            'title': title,
            'artist': _runsText(node['flexColumns']),
            'artwork': thumbs.isEmpty ? null : thumbs.last,
          });
        }
        for (final value in node.values) {
          if (value is Map || value is List) walk(value);
        }
      } else if (node is List) {
        for (final value in node) walk(value);
      }
    }

    walk(data);

    final seen = <String>{};
    return result.where((e) => seen.add(e['id'] as String)).take(30).toList();
  }

  List<DiscoveryTrack> _extractTracks(Map<String, dynamic> node) {
    final output = <DiscoveryTrack>[];

    void walk(dynamic value) {
      if (value is Map<String, dynamic>) {
        final id = value['videoId'] as String?;
        final title = _text(value['title']);
        if (id != null && title != null) {
          final thumbs = _thumbnails(value['thumbnail']);
          output.add({
            'id': id,
            'title': title,
            'artist': _runsText(value['flexColumns']),
            'artwork': thumbs.isEmpty ? null : thumbs.last,
          });
        }
        for (final child in value.values) {
          if (child is Map || child is List) walk(child);
        }
      } else if (value is List) {
        for (final child in value) walk(child);
      }
    }

    walk(node);

    final seen = <String>{};
    return output.where((e) => seen.add(e['id'] as String)).toList();
  }

  String? _text(dynamic value) {
    if (value is Map<String, dynamic>) {
      final simple = value['simpleText'];
      if (simple is String) return simple;
      final runs = value['runs'];
      if (runs is List) {
        return runs
            .whereType<Map>()
            .map((e) => e['text'])
            .whereType<String>()
            .join();
      }
    }
    return null;
  }

  String _runsText(dynamic value) {
    final texts = <String>[];

    void walk(dynamic node) {
      if (node is Map<String, dynamic>) {
        final t = _text(node['text']);
        if (t != null) texts.add(t);
        for (final child in node.values) {
          if (child is Map || child is List) walk(child);
        }
      } else if (node is List) {
        for (final child in node) walk(child);
      }
    }

    walk(value);
    return texts.take(3).join(' • ');
  }

  List<String> _thumbnails(dynamic value) {
    final result = <String>[];

    void walk(dynamic node) {
      if (node is Map<String, dynamic>) {
        final url = node['url'];
        if (url is String && url.isNotEmpty) result.add(url);
        for (final child in node.values) {
          if (child is Map || child is List) walk(child);
        }
      } else if (node is List) {
        for (final child in node) walk(child);
      }
    }

    walk(value);
    return result;
  }
}

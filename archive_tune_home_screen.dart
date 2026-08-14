import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';

/// ArchiveTune-style Home feed for V Shots.
///
/// DATA:
/// - Uses YouTube Music's public web InnerTube endpoints for discovery.
/// - Does NOT use YouTube Data API playlistItems.list.
/// - Does NOT depend on RDCLAK/OLAK/OLZy generated playlists.
/// - The discovery layer only returns metadata/video IDs.
///
/// PLAYBACK:
/// Pass [onPlayTrack] from the existing official YouTube-player pipeline.
/// This widget never downloads/extracts YouTube audio.
class ArchiveTuneHomeScreen extends StatefulWidget {
  const ArchiveTuneHomeScreen({
    super.key,
    required this.onPlayTrack,
  });

  final Future<void> Function(
    Map<String, dynamic> track,
    List<Map<String, dynamic>> queue,
    int index,
  ) onPlayTrack;

  @override
  State<ArchiveTuneHomeScreen> createState() => _ArchiveTuneHomeScreenState();
}

class _ArchiveTuneHomeScreenState extends State<ArchiveTuneHomeScreen>
    with AutomaticKeepAliveClientMixin {
  final _provider = _YouTubeMusicInnerTubeProvider();
  final _scrollController = ScrollController();

  _HomeFeed? _feed;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  final Set<String> _playingIds = <String>{};

  static const _chips = <String>[
    'Relax',
    'Workout',
    'Energize',
    'Romance',
    'Bollywood',
    'Punjabi',
    'Hindi',
    'English',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (_refreshing) return;

    if (force) {
      _refreshing = true;
      if (mounted) setState(() {});
    } else if (_feed == null) {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
    }

    try {
      final feed = await _provider.getHomeFeed(forceRefresh: force);
      if (!mounted) return;

      setState(() {
        _feed = feed;
        _loading = false;
        _error = feed.sections.isEmpty
            ? 'No music shelves were returned by YouTube Music.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _feed == null ? 'Unable to load music right now.' : null;
      });
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _play(_MusicItem item, List<_MusicItem> queue) async {
    final videoId = item.videoId;
    if (videoId == null || videoId.isEmpty) return;

    final track = <String, dynamic>{
      'id': videoId,
      'videoId': videoId,
      'title': item.title,
      'artist': item.subtitle,
      'artwork': item.artwork,
      'duration': item.durationSeconds ?? 0,
      'source': 'youtube_music_innertube',
    };

    setState(() {
      _playingIds
        ..clear()
        ..add(videoId);
    });

    try {
      await widget.onPlayTrack(
        track,
        queue
            .map(
              (e) => <String, dynamic>{
                'id': e.videoId,
                'videoId': e.videoId,
                'title': e.title,
                'artist': e.subtitle,
                'artwork': e.artwork,
                'duration': e.durationSeconds ?? 0,
                'source': 'youtube_music_innertube',
              },
            )
            .where((e) => (e['id'] as String?)?.isNotEmpty == true)
            .toList(),
        queue.indexOf(item),
      );
    } finally {
      if (mounted) {
        setState(() => _playingIds.remove(videoId));
      }
    }
  }

  Future<void> _openChip(String chip) async {
    final query = switch (chip) {
      'Relax' => 'relax chill music',
      'Workout' => 'workout music',
      'Energize' => 'energetic music',
      'Romance' => 'romantic songs',
      'Bollywood' => 'bollywood hindi hits',
      'Punjabi' => 'punjabi hits',
      'Hindi' => 'hindi hits',
      _ => 'english pop hits',
    };

    final results = await _provider.search(query);
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ArchiveTuneSearchResultsScreen(
          title: chip,
          items: results,
          onPlayTrack: widget.onPlayTrack,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        onRefresh: () => _load(force: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildChips()),
            if (_loading && _feed == null) _buildInitialSkeleton(),
            if (_error != null && _feed == null) _buildError(),
            if (_feed != null)
              for (final section in _feed!.sections)
                _buildSection(section),
            const SliverToBoxAdapter(child: SizedBox(height: 130)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      floating: true,
      snap: true,
      elevation: 0,
      titleSpacing: 20,
      title: const Text(
        'V Shots',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refreshing ? null : () => _load(force: true),
          icon: _refreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        scrollDirection: Axis.horizontal,
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final chip = _chips[index];
          return ActionChip(
            label: Text(chip),
            onPressed: () => _openChip(chip),
            backgroundColor: AppColors.surface,
            side: BorderSide(color: AppColors.border.withValues(alpha: 0.75)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            labelStyle: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          );
        },
      ),
    );
  }

  Widget _buildInitialSkeleton() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, sectionIndex) => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                width: 170,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 190,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: 5,
                  itemBuilder: (_, index) => Container(
                    width: 154,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          margin: const EdgeInsets.fromLTRB(10, 0, 40, 10),
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        childCount: 5,
      ),
    );
  }

  Widget _buildError() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.music_off_rounded,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              const Text(
                'Music feed unavailable',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pull down to refresh and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => _load(force: true),
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(_HomeSection section) {
    final items = section.items;
    if (items.isEmpty) return const SliverToBoxAdapter();

    final cardWidth = section.kind == _HomeSectionKind.artist ? 118.0 : 156.0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      section.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  if (section.browseId != null)
                    TextButton(
                      onPressed: () async {
                        final more = await _provider.browse(section.browseId!);
                        if (!mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _ArchiveTuneSearchResultsScreen(
                              title: section.title,
                              items: more,
                              onPlayTrack: widget.onPlayTrack,
                            ),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: section.kind == _HomeSectionKind.artist ? 145 : 210,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isPlaying = _playingIds.contains(item.videoId);

                  return SizedBox(
                    width: cardWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: item.videoId == null
                            ? null
                            : () => _play(item, items),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: section.kind == _HomeSectionKind.artist
                                  ? 1
                                  : 1,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  section.kind == _HomeSectionKind.artist
                                      ? 999
                                      : 14,
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    AppImage(
                                      item.artwork,
                                      fit: BoxFit.cover,
                                      errorIconColor: AppColors.accent,
                                    ),
                                    if (item.videoId != null)
                                      Positioned(
                                        right: 8,
                                        bottom: 8,
                                        child: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: AppColors.accent,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.35,
                                                ),
                                                blurRadius: 10,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            isPlaying
                                                ? Icons.graphic_eq_rounded
                                                : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 21,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.15,
                              ),
                            ),
                            if (item.subtitle.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveTuneSearchResultsScreen extends StatelessWidget {
  const _ArchiveTuneSearchResultsScreen({
    required this.title,
    required this.items,
    required this.onPlayTrack,
  });

  final String title;
  final List<_MusicItem> items;
  final Future<void> Function(
    Map<String, dynamic> track,
    List<Map<String, dynamic>> queue,
    int index,
  ) onPlayTrack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          color: AppColors.borderSubtle,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 3,
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AppImage(
                item.artwork,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(
              Icons.play_circle_fill_rounded,
              color: AppColors.accent,
              size: 30,
            ),
            onTap: item.videoId == null
                ? null
                : () {
                    final queue = items
                        .where((e) => e.videoId != null && e.videoId!.isNotEmpty)
                        .map(
                          (e) => <String, dynamic>{
                            'id': e.videoId,
                            'videoId': e.videoId,
                            'title': e.title,
                            'artist': e.subtitle,
                            'artwork': e.artwork,
                            'duration': e.durationSeconds ?? 0,
                            'source': 'youtube_music_innertube',
                          },
                        )
                        .toList();
                    final queueIndex = queue.indexWhere(
                      (e) => e['id'] == item.videoId,
                    );
                    onPlayTrack(
                      {
                        'id': item.videoId,
                        'videoId': item.videoId,
                        'title': item.title,
                        'artist': item.subtitle,
                        'artwork': item.artwork,
                        'duration': item.durationSeconds ?? 0,
                        'source': 'youtube_music_innertube',
                      },
                      queue,
                      queueIndex < 0 ? 0 : queueIndex,
                    );
                  },
          );
        },
      ),
    );
  }
}

enum _HomeSectionKind { track, artist, playlist }

class _HomeFeed {
  const _HomeFeed(this.sections);

  final List<_HomeSection> sections;
}

class _HomeSection {
  const _HomeSection({
    required this.title,
    required this.items,
    this.browseId,
    this.kind = _HomeSectionKind.track,
  });

  final String title;
  final List<_MusicItem> items;
  final String? browseId;
  final _HomeSectionKind kind;
}

class _MusicItem {
  const _MusicItem({
    required this.title,
    required this.subtitle,
    required this.artwork,
    this.videoId,
    this.browseId,
    this.durationSeconds,
    this.kind = _HomeSectionKind.track,
  });

  final String title;
  final String subtitle;
  final String artwork;
  final String? videoId;
  final String? browseId;
  final int? durationSeconds;
  final _HomeSectionKind kind;
}

class _YouTubeMusicInnerTubeProvider {
  _YouTubeMusicInnerTubeProvider();

  final http.Client _client = http.Client();

  String? _apiKey;
  String? _clientVersion;
  DateTime? _bootstrapAt;

  final Map<String, _CacheEntry<_HomeFeed>> _homeCache = {};
  final Map<String, _CacheEntry<List<_MusicItem>>> _browseCache = {};

  static const _musicHost = 'https://music.youtube.com';
  static const _homeBrowseId = 'FEmusic_home';

  // Current WEB_REMIX values are intentionally treated as replaceable.
  // _bootstrap() refreshes these from music.youtube.com when possible.
  static const _fallbackApiKey =
      'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  static const _fallbackClientVersion = '1.20260707.12.00';

  Future<_HomeFeed> getHomeFeed({bool forceRefresh = false}) async {
    final cache = _homeCache['home'];
    if (!forceRefresh && cache != null && !cache.isExpired) {
      return cache.value;
    }

    final json = await _browseRaw(_homeBrowseId);
    final sections = _parseHomeSections(json);

    final feed = _HomeFeed(_cleanSections(sections));
    _homeCache['home'] = _CacheEntry(
      feed,
      const Duration(minutes: 10),
    );

    return feed;
  }

  Future<List<_MusicItem>> browse(String browseId) async {
    final cache = _browseCache[browseId];
    if (cache != null && !cache.isExpired) return cache.value;

    final json = await _browseRaw(browseId);
    final items = _parseItemsDeep(json);

    _browseCache[browseId] = _CacheEntry(
      items,
      const Duration(minutes: 10),
    );
    return items;
  }

  Future<List<_MusicItem>> search(String query) async {
    await _bootstrap();

    final uri = Uri.parse(
      '$_musicHost/youtubei/v1/search'
      '?key=${Uri.encodeQueryComponent(_apiKey!)}'
      '&prettyPrint=false',
    );

    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Origin': _musicHost,
        'Referer': '$_musicHost/',
      },
      body: jsonEncode({
        'query': query,
        'context': _context(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('YouTube Music search ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    return _cleanItems(_parseItemsDeep(decoded));
  }

  Future<Map<String, dynamic>> _browseRaw(String browseId) async {
    await _bootstrap();

    final uri = Uri.parse(
      '$_musicHost/youtubei/v1/browse'
      '?key=${Uri.encodeQueryComponent(_apiKey!)}'
      '&prettyPrint=false',
    );

    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Origin': _musicHost,
        'Referer': '$_musicHost/',
      },
      body: jsonEncode({
        'browseId': browseId,
        'context': _context(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('YouTube Music browse ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid YouTube Music response');
    }
    return decoded;
  }

  Future<void> _bootstrap() async {
    final fresh = _bootstrapAt != null &&
        DateTime.now().difference(_bootstrapAt!) < const Duration(hours: 6);

    if (_apiKey != null && _clientVersion != null && fresh) return;

    _apiKey = _fallbackApiKey;
    _clientVersion = _fallbackClientVersion;

    try {
      final response = await _client.get(
        Uri.parse('$_musicHost/'),
        headers: const {
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'en-IN,en;q=0.9',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/136.0 Mobile Safari/537.36',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final html = response.body;

        final key = _firstMatch(
          html,
          RegExp(r'INNERTUBE_API_KEY["\']?\s*:\s*["\']([^"\']+)'),
        );

        final version = _firstMatch(
          html,
          RegExp(r'INNERTUBE_CLIENT_VERSION["\']?\s*:\s*["\']([^"\']+)'),
        );

        if (key != null && key.isNotEmpty) _apiKey = key;
        if (version != null && version.isNotEmpty) _clientVersion = version;
      }
    } catch (_) {
      // Fallback values above remain active.
    }

    _bootstrapAt = DateTime.now();
  }

  Map<String, dynamic> _context() {
    return {
      'client': {
        'clientName': 'WEB_REMIX',
        'clientVersion': _clientVersion ?? _fallbackClientVersion,
        'hl': 'en',
        'gl': 'IN',
        'platform': 'DESKTOP',
      },
    };
  }

  List<_HomeSection> _parseHomeSections(Map<String, dynamic> root) {
    final output = <_HomeSection>[];

    void walk(dynamic node) {
      if (node is Map<String, dynamic>) {
        final carousel = node['musicCarouselShelfRenderer'];
        if (carousel is Map<String, dynamic>) {
          final title = _textFrom(
            carousel['header'],
          );

          final items = <_MusicItem>[];
          final contents = carousel['contents'];
          if (contents is List) {
            for (final child in contents) {
              final item = _parseMusicItem(child);
              if (item != null) items.add(item);
            }
          }

          if (title.trim().isNotEmpty && items.isNotEmpty) {
            final browseId = _browseIdFrom(carousel['header']);
            output.add(
              _HomeSection(
                title: title.trim(),
                items: _cleanItems(items),
                browseId: browseId,
                kind: _inferSectionKind(items),
              ),
            );
          }
        }

        final shelf = node['musicShelfRenderer'];
        if (shelf is Map<String, dynamic>) {
          final title = _textFrom(shelf['title']);
          final items = <_MusicItem>[];
          final contents = shelf['contents'];

          if (contents is List) {
            for (final child in contents) {
              final item = _parseMusicItem(child);
              if (item != null) items.add(item);
            }
          }

          if (title.trim().isNotEmpty && items.isNotEmpty) {
            output.add(
              _HomeSection(
                title: title.trim(),
                items: _cleanItems(items),
                browseId: _browseIdFrom(shelf),
                kind: _inferSectionKind(items),
              ),
            );
          }
        }

        for (final value in node.values) {
          walk(value);
        }
      } else if (node is List) {
        for (final value in node) {
          walk(value);
        }
      }
    }

    walk(root);
    return output;
  }

  List<_MusicItem> _parseItemsDeep(dynamic root) {
    final result = <_MusicItem>[];

    void walk(dynamic node) {
      if (node is Map<String, dynamic>) {
        final item = _parseMusicItem(node);
        if (item != null) result.add(item);

        for (final value in node.values) {
          walk(value);
        }
      } else if (node is List) {
        for (final value in node) {
          walk(value);
        }
      }
    }

    walk(root);
    return _cleanItems(result);
  }

  _MusicItem? _parseMusicItem(dynamic node) {
    if (node is! Map<String, dynamic>) return null;

    final twoRow = node['musicTwoRowItemRenderer'];
    if (twoRow is Map<String, dynamic>) {
      final title = _textFrom(twoRow['title']);
      final subtitle = _textFrom(twoRow['subtitle']);
      final artwork = _thumbnail(twoRow['thumbnail']);
      final videoId = _videoIdFrom(twoRow);
      final browseId = _browseIdFrom(twoRow);

      if (title.isEmpty || artwork.isEmpty) return null;

      return _MusicItem(
        title: title,
        subtitle: subtitle,
        artwork: artwork,
        videoId: videoId,
        browseId: browseId,
        kind: _kindFrom(twoRow),
      );
    }

    final responsive = node['musicResponsiveListItemRenderer'];
    if (responsive is Map<String, dynamic>) {
      final flexColumns = responsive['flexColumns'];
      final title = _textFrom(
        flexColumns is List && flexColumns.isNotEmpty
            ? flexColumns.first
            : null,
      );

      final subtitle = _textFrom(
        flexColumns is List && flexColumns.length > 1
            ? flexColumns[1]
            : null,
      );

      final artwork = _thumbnail(responsive['thumbnail']);
      final videoId = _videoIdFrom(responsive);
      final browseId = _browseIdFrom(responsive);

      if (title.isEmpty || artwork.isEmpty) return null;

      return _MusicItem(
        title: title,
        subtitle: subtitle,
        artwork: artwork,
        videoId: videoId,
        browseId: browseId,
        durationSeconds: _durationFrom(responsive),
        kind: _kindFrom(responsive),
      );
    }

    return null;
  }

  _HomeSectionKind _inferSectionKind(List<_MusicItem> items) {
    if (items.isEmpty) return _HomeSectionKind.track;
    if (items.where((e) => e.kind == _HomeSectionKind.artist).length >
        items.length / 2) {
      return _HomeSectionKind.artist;
    }
    if (items.where((e) => e.kind == _HomeSectionKind.playlist).length >
        items.length / 2) {
      return _HomeSectionKind.playlist;
    }
    return _HomeSectionKind.track;
  }

  _HomeSectionKind _kindFrom(Map<String, dynamic> node) {
    final browse = _findFirstKey(node, 'browseEndpoint');
    final browseId = browse is Map ? browse['browseId'] : null;

    if (browseId is String && browseId.startsWith('VL')) {
      return _HomeSectionKind.playlist;
    }

    final pageType = _findPageType(node);
    if (pageType.contains('ARTIST')) return _HomeSectionKind.artist;

    return _HomeSectionKind.track;
  }

  String _findPageType(dynamic node) {
    if (node is Map<String, dynamic>) {
      final endpoint = node['navigationEndpoint'];
      if (endpoint is Map<String, dynamic>) {
        final browseEndpoint = endpoint['browseEndpoint'];
        if (browseEndpoint is Map<String, dynamic>) {
          final context = browseEndpoint['browseEndpointContextSupportedConfigs'];
          if (context is Map<String, dynamic>) {
            final pageType = context['browseEndpointContextMusicConfig'];
            if (pageType is Map<String, dynamic>) {
              return '${pageType['pageType'] ?? ''}'.toUpperCase();
            }
          }
        }
      }

      for (final value in node.values) {
        final found = _findPageType(value);
        if (found.isNotEmpty) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _findPageType(value);
        if (found.isNotEmpty) return found;
      }
    }

    return '';
  }

  String? _videoIdFrom(dynamic node) {
    final watch = _findFirstKey(node, 'watchEndpoint');
    if (watch is Map && watch['videoId'] is String) {
      return watch['videoId'] as String;
    }

    final videoId = _findFirstKey(node, 'videoId');
    return videoId is String ? videoId : null;
  }

  String? _browseIdFrom(dynamic node) {
    final browse = _findFirstKey(node, 'browseEndpoint');
    if (browse is Map && browse['browseId'] is String) {
      final id = browse['browseId'] as String;
      if (id.isNotEmpty) return id;
    }
    return null;
  }

  String _thumbnail(dynamic node) {
    if (node is! Map<String, dynamic>) return '';

    final thumbs = node['thumbnails'];
    if (thumbs is List && thumbs.isNotEmpty) {
      final last = thumbs.last;
      if (last is Map && last['url'] is String) {
        return last['url'] as String;
      }
    }

    final nested = _findFirstKey(node, 'thumbnails');
    if (nested is List && nested.isNotEmpty) {
      final last = nested.last;
      if (last is Map && last['url'] is String) {
        return last['url'] as String;
      }
    }

    return '';
  }

  int? _durationFrom(dynamic node) {
    final duration = _findFirstKey(node, 'lengthText');
    final text = _textFrom(duration);
    if (text.isEmpty) return null;

    final parts = text.split(':').map(int.tryParse).toList();
    if (parts.any((e) => e == null)) return null;

    if (parts.length == 2) {
      return (parts[0]! * 60) + parts[1]!;
    }
    if (parts.length == 3) {
      return (parts[0]! * 3600) + (parts[1]! * 60) + parts[2]!;
    }
    return null;
  }

  String _textFrom(dynamic node) {
    if (node is String) return node.trim();

    if (node is Map<String, dynamic>) {
      final simple = node['text'];
      if (simple is String) return simple.trim();

      final runs = node['runs'];
      if (runs is List) {
        return runs
            .whereType<Map>()
            .map((run) => '${run['text'] ?? ''}')
            .join()
            .trim();
      }

      final flex = node['musicResponsiveListItemFlexColumnRenderer'];
      if (flex is Map<String, dynamic>) {
        return _textFrom(flex['text']);
      }

      final title = node['title'];
      if (title != null) return _textFrom(title);
    }

    return '';
  }

  dynamic _findFirstKey(dynamic node, String key) {
    if (node is Map<String, dynamic>) {
      if (node.containsKey(key)) return node[key];
      for (final value in node.values) {
        final found = _findFirstKey(value, key);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _findFirstKey(value, key);
        if (found != null) return found;
      }
    }
    return null;
  }

  String? _firstMatch(String input, RegExp pattern) {
    final match = pattern.firstMatch(input);
    return match?.group(1);
  }

  List<_HomeSection> _cleanSections(List<_HomeSection> sections) {
    final seenTitles = <String>{};
    final result = <_HomeSection>[];

    for (final section in sections) {
      final title = section.title.trim();
      if (title.isEmpty) continue;

      final key = title.toLowerCase();
      if (!seenTitles.add(key)) continue;

      final items = _cleanItems(section.items);
      if (items.length < 2) continue;

      result.add(
        _HomeSection(
          title: title,
          items: items.take(15).toList(),
          browseId: section.browseId,
          kind: section.kind,
        ),
      );
    }

    return result;
  }

  List<_MusicItem> _cleanItems(List<_MusicItem> input) {
    final seen = <String>{};
    final result = <_MusicItem>[];

    for (final item in input) {
      final key = item.videoId ??
          item.browseId ??
          '${item.title}|${item.subtitle}|${item.artwork}';

      if (!seen.add(key)) continue;
      if (item.title.trim().isEmpty) continue;
      if (item.artwork.trim().isEmpty) continue;

      result.add(item);
    }

    return result;
  }

  void dispose() {
    _client.close();
  }
}

class _CacheEntry<T> {
  _CacheEntry(this.value, this.ttl)
      : createdAt = DateTime.now();

  final T value;
  final Duration ttl;
  final DateTime createdAt;

  bool get isExpired => DateTime.now().difference(createdAt) > ttl;
}

// V Shots — Discover Feed / Browser Playback Repair
// The Discover surface owns the swipe feed; YouTube is opened as a real
// in-app browser page, not as an iframe/embed player.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/discovery_categories.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';
import '../../shared/widgets/comment_sheet.dart';
import '../../main.dart' show currentTabIndexNotifier, forYouFeedService;

class ForYouFeedScreen extends StatefulWidget {
  const ForYouFeedScreen({super.key});

  @override
  State<ForYouFeedScreen> createState() => _ForYouFeedScreenState();
}

class _ForYouFeedScreenState extends State<ForYouFeedScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final InAppWebViewKeepAlive _browserKeepAlive = InAppWebViewKeepAlive();

  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  final Set<String> _seenIds = <String>{};

  InAppWebViewController? _browserController;
  DiscoveryCategory? _activeCategory;
  int _currentIndex = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _browserExpanded = false;
  bool _browserReady = false;
  bool _liked = false;
  double _browserHeight = 78;

  DiscoveryCategory get _defaultCategory =>
      kDiscoveryCategories.isNotEmpty
          ? kDiscoveryCategories.first
          : const DiscoveryCategory(
              id: 'trending',
              label: 'Trending',
              icon: '🌟',
              query: 'trending songs 2026 official video',
              fallbackCategory: 'global',
            );

  Map<String, dynamic>? get _currentTrack =>
      _items.isEmpty ? null : _items[_currentIndex];

  @override
  void initState() {
    super.initState();
    _activeCategory = _defaultCategory;
    _seenIds.addAll(LocalLibrary.instance.recentlyShownIds);
    currentTabIndexNotifier.addListener(_onTabChanged);
    _loadInitial();
  }

  void _onTabChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    currentTabIndexNotifier.removeListener(_onTabChanged);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final batch = await _fetchBatch();
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(batch);
      _loading = false;
      _currentIndex = 0;
    });
    if (_items.isNotEmpty) {
      await _selectTrack(0, autoPlay: true);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchBatch() async {
    final category = _activeCategory ?? _defaultCategory;
    try {
      final results = await forYouFeedService.fetchForCategory(
        category,
        excludeIds: _seenIds,
        count: 12,
      );
      final fresh = <Map<String, dynamic>>[];
      for (final track in results) {
        final id = track['id'] as String?;
        if (id == null || id.isEmpty || _seenIds.contains(id)) continue;
        _seenIds.add(id);
        fresh.add(track);
      }
      return fresh;
    } catch (e) {
      debugPrint('[DiscoverBrowser] category fetch failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _loadMoreIfNeeded() async {
    if (_loadingMore || _items.length - _currentIndex > 3) return;
    _loadingMore = true;
    final batch = await _fetchBatch();
    if (mounted && batch.isNotEmpty) {
      setState(() => _items.addAll(batch));
    }
    _loadingMore = false;
  }

  Future<void> _selectTrack(int index, {bool autoPlay = true}) async {
    if (!mounted || index < 0 || index >= _items.length) return;
    final track = _items[index];
    final id = track['id'] as String?;
    if (id == null || id.isEmpty) return;

    setState(() {
      _currentIndex = index;
      _liked = LocalLibrary.instance.isLiked(id);
    });

    unawaited(HapticFeedback.selectionClick());
    unawaited(LocalLibrary.instance.recordRecentlyPlayed(track));
    LocalLibrary.instance.recordShownSong(id);
    _seenIds.add(id);

    await _loadYouTubeVideo(id, autoPlay: autoPlay);
    unawaited(_loadMoreIfNeeded());
  }

  String _youtubeUrl(String videoId) =>
      'https://www.youtube.com/watch?v=${Uri.encodeComponent(videoId)}&autoplay=1&playsinline=1';

  Future<void> _loadYouTubeVideo(
    String videoId, {
    bool autoPlay = true,
  }) async {
    final controller = _browserController;
    if (controller == null) return;
    try {
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(_youtubeUrl(videoId))));
      if (autoPlay) {
        // The WebView is configured for media autoplay. This JS call is only
        // an additional best-effort nudge after navigation; YouTube remains
        // the actual website/player and no media stream is extracted.
        Future<void>.delayed(const Duration(milliseconds: 900), () async {
          if (!mounted || _browserController == null) return;
          try {
            await _browserController!.evaluateJavascript(
              source: "document.querySelector('video')?.play?.();",
            );
          } catch (_) {}
        });
      }
    } catch (e) {
      debugPrint('[DiscoverBrowser] YouTube navigation failed: $e');
    }
  }

  Future<void> _changeCategory(DiscoveryCategory category) async {
    Navigator.of(context).maybePop();
    setState(() {
      _activeCategory = category;
      _loading = true;
      _currentIndex = 0;
      // IMPORTANT: do not clear _seenIds. Recently shown IDs are global for
      // the session + persisted 24h window, so returning to Sad/Trending/etc.
      // does not recycle the same first songs.
      _items.clear();
    });
    forYouFeedService.setMood(category.label, category.query);
    final batch = await _fetchBatch();
    if (!mounted) return;
    setState(() {
      _items.addAll(batch);
      _loading = false;
    });
    if (_items.isNotEmpty) {
      _pageController.jumpToPage(0);
      await _selectTrack(0, autoPlay: true);
    }
  }

  void _showCategorySheet({bool genresOnly = false}) {
    final categories = genresOnly
        ? kDiscoveryCategories
            .where((c) => <String>{
                  'bollywood',
                  'punjabi',
                  'global',
                  'indie',
                  'devotional',
                  'sufi',
                  'nostalgia',
                }.contains(c.id))
            .toList()
        : kDiscoveryCategories;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(context).size.height * .72,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                genresOnly ? 'Choose a Genre' : 'Choose a Mood',
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.35,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final selected = category.id == _activeCategory?.id;
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _changeCategory(category),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: selected
                              ? AppColors.primaryGradient
                              : const LinearGradient(
                                  colors: [AppColors.surface2, AppColors.surface3],
                                ),
                          border: Border.all(
                            color: selected
                                ? AppColors.primaryLight
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(category.icon, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                category.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMain,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
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
        ),
      ),
    );
  }

  Future<void> _toggleLike() async {
    final track = _currentTrack;
    if (track == null) return;
    await LocalLibrary.instance.toggleLiked(track);
    if (mounted) setState(() => _liked = !_liked);
  }

  Future<void> _shareTrack() async {
    final track = _currentTrack;
    if (track == null) return;
    final title = track['title'] as String? ?? 'Song';
    final id = track['id'] as String? ?? '';
    await Share.share('$title\nhttps://www.youtube.com/watch?v=$id');
  }

  void _showMore() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_full_rounded),
              title: const Text('Open full browser player'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _browserExpanded = true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Reload YouTube page'),
              onTap: () async {
                Navigator.pop(context);
                await _browserController?.reload();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Copy / share YouTube link'),
              onTap: () {
                Navigator.pop(context);
                _shareTrack();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPlaylistSheet() async {
    final track = _currentTrack;
    if (track == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: LocalLibrary.instance.playlists,
        builder: (context, playlists, _) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add to playlist',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No playlists yet. Create one from Library.'),
                )
              else
                ...playlists.take(8).map(
                      (playlist) => ListTile(
                        leading: const Icon(Icons.queue_music_rounded),
                        title: Text(playlist['name'] as String? ?? 'Playlist'),
                        onTap: () async {
                          await LocalLibrary.instance.addTrackToPlaylist(
                            playlist['id'] as String,
                            track,
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(.38),
              border: Border.all(color: Colors.white.withOpacity(.14)),
            ),
            child: Icon(
              icon,
              color: active ? AppColors.primaryLight : Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(blurRadius: 4, color: Colors.black)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowser() {
    final expandedHeight = MediaQuery.of(context).size.height * .58;
    final height = _browserExpanded ? expandedHeight : _browserHeight;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF10131B),
        borderRadius: BorderRadius.circular(_browserExpanded ? 24 : 18),
        border: Border.all(color: Colors.white.withOpacity(.13)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 22, offset: Offset(0, -8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.delta.dy < -4 && !_browserExpanded) {
                setState(() => _browserExpanded = true);
              } else if (details.delta.dy > 4 && _browserExpanded) {
                setState(() => _browserExpanded = false);
              }
            },
            onTap: () => setState(() => _browserExpanded = !_browserExpanded),
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(color: Color(0xFF151923)),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                    child: _currentTrack?['artwork'] != null
                        ? AppImage(_currentTrack!['artwork'] as String, fit: BoxFit.cover)
                        : const ColoredBox(color: Colors.black),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'YouTube Browser',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currentTrack?['title'] as String? ?? 'Select a song',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _currentTrack?['artist'] as String? ?? 'YouTube',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _browserExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          if (_browserExpanded)
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: const Color(0xFF0B0E14),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => _browserController?.goBack(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
                  ),
                  IconButton(
                    tooltip: 'Forward',
                    onPressed: () => _browserController?.goForward(),
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 17),
                  ),
                  Expanded(
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181D28),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_rounded, size: 13, color: Colors.white54),
                          SizedBox(width: 6),
                          Text(
                            'youtube.com',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reload',
                    onPressed: () => _browserController?.reload(),
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  keepAlive: _browserKeepAlive,
                  initialUrlRequest: URLRequest(url: WebUri('https://www.youtube.com/')),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowBackgroundAudioPlaying: true,
                    allowsInlineMediaPlayback: true,
                    allowsPictureInPictureMediaPlayback: true,
                    supportZoom: false,
                    javaScriptCanOpenWindowsAutomatically: true,
                    useHybridComposition: true,
                  ),
                  onWebViewCreated: (controller) {
                    _browserController = controller;
                    if (mounted) setState(() => _browserReady = true);
                  },
                  onLoadStop: (controller, url) async {
                    if (!mounted) return;
                    if (!_browserReady) setState(() => _browserReady = true);
                    try {
                      await controller.evaluateJavascript(
                        source: "document.querySelector('video')?.play?.();",
                      );
                    } catch (_) {}
                  },
                ),
                if (!_browserReady)
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryLight),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedPage(Map<String, dynamic> track, int index) {
    final artwork = track['artwork'] as String?;
    final title = track['title'] as String? ?? 'Unknown Song';
    final artist = track['artist'] as String? ?? 'Unknown Artist';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Premium moving blurred background. The artwork is only used as
        // visual grounding; the actual playback is the YouTube website below.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: artwork == null
              ? Container(key: ValueKey(index), color: const Color(0xFF090B12))
              : Stack(
                  key: ValueKey('${index}_bg'),
                  fit: StackFit.expand,
                  children: [
                    Transform.scale(
                      scale: 1.16,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                        child: AppImage(artwork, fit: BoxFit.cover),
                      ),
                    ),
                    Container(color: Colors.black.withOpacity(.54)),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(.10),
                            Colors.black.withOpacity(.18),
                            Colors.black.withOpacity(.80),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),

        SafeArea(
          child: Column(
            children: [
              _buildTopTabs(),
              Expanded(
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 70, left: 24, right: 84),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Hero(
                            tag: 'discover-art-${track['id']}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: artwork == null
                                  ? const ColoredBox(color: Colors.black)
                                  : AppImage(artwork, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 126,
                      child: Column(
                        children: [
                          _buildActionButton(
                            icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            label: 'Like',
                            active: _liked,
                            onTap: _toggleLike,
                          ),
                          const SizedBox(height: 18),
                          _buildActionButton(
                            icon: Icons.playlist_add_rounded,
                            label: 'Add',
                            onTap: _showPlaylistSheet,
                          ),
                          const SizedBox(height: 18),
                          _buildActionButton(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Comment',
                            onTap: () => CommentSheet.show(
                              context,
                              shotId: track['id'] as String,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildActionButton(
                            icon: Icons.share_rounded,
                            label: 'Share',
                            onTap: _shareTrack,
                          ),
                          const SizedBox(height: 18),
                          _buildActionButton(
                            icon: Icons.more_horiz_rounded,
                            label: 'More',
                            onTap: _showMore,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 24,
                      right: 92,
                      bottom: 28,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _activeCategory?.label ?? 'For You',
                            style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopTabs() {
    final tabs = <Widget>[
      _tab('For You', selected: true, onTap: () {}),
      _tab('Moods', onTap: () => _showCategorySheet()),
      _tab('Genres', onTap: () => _showCategorySheet(genresOnly: true)),
      _tab(
        'Trending',
        onTap: () {
          final category = discoveryCategoryById('trending');
          if (category != null) _changeCategory(category);
        },
      ),
      _tab(
        'New',
        onTap: () {
          final category = discoveryCategoryById('global');
          if (category != null) _changeCategory(category);
        },
      ),
    ];

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: tabs,
      ),
    );
  }

  Widget _tab(String text, {bool selected = false, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : Colors.black.withOpacity(.58),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? AppColors.primaryLight : Colors.white.withOpacity(.12),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryLight),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'No fresh songs available right now.\nTry another mood.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final bottomOffset = MediaQuery.of(context).padding.bottom + 68;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _items.length,
            onPageChanged: (index) => _selectTrack(index),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) => _buildFeedPage(_items[index], index),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: bottomOffset,
            child: _buildBrowser(),
          ),
        ],
      ),
    );
  }
}

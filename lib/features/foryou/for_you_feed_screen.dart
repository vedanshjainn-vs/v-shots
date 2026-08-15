import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/discovery_categories.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart' show currentTabIndexNotifier, forYouFeedService;
import '../../shared/widgets/app_image.dart';
import '../../shared/widgets/comment_sheet.dart';

class ForYouFeedScreen extends StatefulWidget {
  const ForYouFeedScreen({super.key});

  @override
  State<ForYouFeedScreen> createState() => _ForYouFeedScreenState();
}

class _ForYouFeedScreenState extends State<ForYouFeedScreen> {
  final PageController _pages = PageController();
  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  final Set<String> _seen = <String>{};

  InAppWebViewController? _web;
  DiscoveryCategory? _category;
  int _index = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _expanded = false;
  bool _webReady = false;
  bool _liked = false;

  DiscoveryCategory get _defaultCategory => kDiscoveryCategories.first;

  Map<String, dynamic>? get _track =>
      _items.isEmpty || _index >= _items.length ? null : _items[_index];

  @override
  void initState() {
    super.initState();
    _category = _defaultCategory;
    _seen.addAll(LocalLibrary.instance.recentlyShownIds);
    currentTabIndexNotifier.addListener(_tabChanged);
    unawaited(_loadCategory());
  }

  void _tabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    currentTabIndexNotifier.removeListener(_tabChanged);
    _pages.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    try {
      final result = await forYouFeedService.fetchForCategory(
        _category ?? _defaultCategory,
        excludeIds: _seen,
        count: 12,
      );
      final fresh = <Map<String, dynamic>>[];
      for (final track in result) {
        final id = track['id'] as String?;
        if (id == null || id.isEmpty || _seen.contains(id)) continue;
        _seen.add(id);
        fresh.add(track);
      }
      return fresh;
    } catch (e) {
      debugPrint('[DiscoverBrowser] fetch failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _loadCategory() async {
    final batch = await _fetch();
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(batch);
      _index = 0;
      _loading = false;
    });
    if (_items.isNotEmpty) {
      await _select(0);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _items.length - _index > 3) return;
    _loadingMore = true;
    final batch = await _fetch();
    if (mounted && batch.isNotEmpty) {
      setState(() => _items.addAll(batch));
    }
    _loadingMore = false;
  }

  Future<void> _select(int index) async {
    if (!mounted || index < 0 || index >= _items.length) return;
    final track = _items[index];
    final id = track['id'] as String?;
    if (id == null || id.isEmpty) return;

    setState(() {
      _index = index;
      _liked = LocalLibrary.instance.isLiked(id);
    });

    unawaited(HapticFeedback.selectionClick());
    unawaited(LocalLibrary.instance.recordRecentlyPlayed(track));
    LocalLibrary.instance.recordShownSong(id);
    _seen.add(id);

    await _openYouTube(id);
    unawaited(_loadMore());
  }

  Future<void> _openYouTube(String id) async {
    final web = _web;
    if (web == null) return;
    try {
      await web.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(
            'https://www.youtube.com/watch?v=${Uri.encodeComponent(id)}&autoplay=1&playsinline=1',
          ),
        ),
      );
    } catch (e) {
      debugPrint('[DiscoverBrowser] YouTube navigation failed: $e');
    }
  }

  Future<void> _changeCategory(DiscoveryCategory category) async {
    setState(() {
      _category = category;
      _items.clear();
      _index = 0;
      _loading = true;
    });

    forYouFeedService.setMood(category.label, category.query);
    final batch = await _fetch();
    if (!mounted) return;

    setState(() {
      _items.addAll(batch);
      _loading = false;
    });

    if (_items.isNotEmpty) {
      if (_pages.hasClients) _pages.jumpToPage(0);
      await _select(0);
    }
  }

  void _showCategories({bool genres = false}) {
    final genreIds = <String>{
      'bollywood',
      'punjabi',
      'global',
      'indie',
      'devotional',
      'sufi',
      'nostalgia',
    };
    final categories = genres
        ? kDiscoveryCategories
            .where((category) => genreIds.contains(category.id))
            .toList()
        : kDiscoveryCategories;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => Container(
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
              const SizedBox(height: 16),
              Text(
                genres ? 'Choose a Genre' : 'Choose a Mood',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.25,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final selected = category.id == _category?.id;
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.pop(sheet);
                        unawaited(_changeCategory(category));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: selected
                              ? AppColors.primaryGradient
                              : AppColors.cardGradient,
                          border: Border.all(
                            color: selected
                                ? AppColors.primaryLight
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              category.icon,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                category.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
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

  Future<void> _like() async {
    final track = _track;
    if (track == null) return;
    await LocalLibrary.instance.toggleLiked(track);
    if (mounted) setState(() => _liked = !_liked);
  }

  Future<void> _share() async {
    final track = _track;
    if (track == null) return;
    final id = track['id'] as String? ?? '';
    await Share.share(
      '${track['title'] ?? 'Song'}\nhttps://www.youtube.com/watch?v=$id',
    );
  }

  Future<void> _addPlaylist() async {
    final track = _track;
    if (track == null) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (sheet) => ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: LocalLibrary.instance.playlists,
        builder: (context, playlists, _) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Add to playlist',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No playlists yet. Create one from Library.'),
                )
              else
                ...playlists.take(10).map(
                  (playlist) => ListTile(
                    leading: const Icon(Icons.queue_music_rounded),
                    title: Text(playlist['name'] as String? ?? 'Playlist'),
                    onTap: () async {
                      await LocalLibrary.instance.addTrackToPlaylist(
                        playlist['id'] as String,
                        track,
                      );
                      if (sheet.mounted) Navigator.pop(sheet);
                    },
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    IconData icon,
    String label,
    VoidCallback onTap, {
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
              color: Colors.black.withOpacity(.42),
              border: Border.all(color: Colors.white.withOpacity(.14)),
            ),
            child: Icon(
              icon,
              color: active ? AppColors.hotPink : Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(blurRadius: 4, color: Colors.black)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _browser() {
    final height = _expanded
        ? MediaQuery.of(context).size.height * .60
        : 72.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF10131B),
        borderRadius: BorderRadius.circular(_expanded ? 24 : 18),
        border: Border.all(color: Colors.white.withOpacity(.14)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.delta.dy < -4 && !_expanded) {
                setState(() => _expanded = true);
              } else if (details.delta.dy > 4 && _expanded) {
                setState(() => _expanded = false);
              }
            },
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: const Color(0xFF151923),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _track?['artwork'] != null
                          ? AppImage(
                              _track!['artwork'] as String,
                              fit: BoxFit.cover,
                            )
                          : const ColoredBox(color: Colors.black),
                    ),
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
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          _track?['title'] as String? ?? 'YouTube',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _track?['artist'] as String? ?? 'YouTube',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            SizedBox(
              height: 42,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _web?.goBack(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
                  ),
                  IconButton(
                    onPressed: () => _web?.goForward(),
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
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _web?.reload(),
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri('https://www.youtube.com/'),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowBackgroundAudioPlaying: true,
                    allowsInlineMediaPlayback: true,
                    allowsPictureInPictureMediaPlayback: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    useHybridComposition: true,
                    supportZoom: false,
                  ),
                  onWebViewCreated: (controller) {
                    _web = controller;
                    if (mounted) setState(() => _webReady = true);
                    final id = _track?['id'] as String?;
                    if (id != null && id.isNotEmpty) {
                      unawaited(_openYouTube(id));
                    }
                  },
                  onLoadStop: (controller, url) {
                    if (mounted && !_webReady) {
                      setState(() => _webReady = true);
                    }
                  },
                ),
                if (!_webReady)
                  const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryLight,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _page(Map<String, dynamic> track) {
    final artwork = track['artwork'] as String?;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (artwork != null)
          Stack(
            fit: StackFit.expand,
            children: [
              Transform.scale(
                scale: 1.18,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: AppImage(artwork, fit: BoxFit.cover),
                ),
              ),
              Container(color: Colors.black.withOpacity(.50)),
              const DecoratedBox(decoration: AppColors.overlayGradient),
            ],
          )
        else
          const ColoredBox(color: Colors.black),
        SafeArea(
          child: Column(
            children: [
              _topTabs(),
              Expanded(
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 24,
                          right: 82,
                          bottom: 74,
                        ),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: artwork == null
                                ? const ColoredBox(color: Colors.black)
                                : AppImage(artwork, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 118,
                      child: Column(
                        children: [
                          _action(
                            _liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            'Like',
                            _like,
                            active: _liked,
                          ),
                          const SizedBox(height: 17),
                          _action(
                            Icons.playlist_add_rounded,
                            'Add',
                            _addPlaylist,
                          ),
                          const SizedBox(height: 17),
                          _action(
                            Icons.chat_bubble_outline_rounded,
                            'Comment',
                            () => CommentSheet.show(
                              context,
                              shotId: track['id'] as String,
                            ),
                          ),
                          const SizedBox(height: 17),
                          _action(Icons.share_rounded, 'Share', _share),
                          const SizedBox(height: 17),
                          _action(
                            Icons.open_in_full_rounded,
                            'Browser',
                            () => setState(() => _expanded = true),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 24,
                      right: 90,
                      bottom: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _category?.label ?? 'For You',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track['title'] as String? ?? 'Unknown Song',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track['artist'] as String? ?? 'Unknown Artist',
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

  Widget _topTabs() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _tab('For You', true, () {}),
          _tab('Moods', false, _showCategories),
          _tab('Genres', false, () => _showCategories(genres: true)),
          _tab('Trending', false, () {
            final category = discoveryCategoryById('trending');
            if (category != null) unawaited(_changeCategory(category));
          }),
          _tab('New', false, () {
            final category = discoveryCategoryById('global');
            if (category != null) unawaited(_changeCategory(category));
          }),
        ],
      ),
    );
  }

  Widget _tab(String text, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.black.withOpacity(.58),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : Colors.white.withOpacity(.12),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
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
            'No fresh songs available. Try another mood.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final bottom = MediaQuery.of(context).padding.bottom + 68;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            itemCount: _items.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) => unawaited(_select(index)),
            itemBuilder: (context, index) => _page(_items[index]),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: bottom,
            child: _browser(),
          ),
        ],
      ),
    );
  }
}

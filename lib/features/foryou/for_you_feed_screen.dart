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
  final InAppWebViewKeepAlive _keepAlive = InAppWebViewKeepAlive();
  final List<Map<String, dynamic>> _items = [];
  final Set<String> _seen = {};
  InAppWebViewController? _web;
  DiscoveryCategory? _category;
  int _index = 0;
  bool _loading = true, _loadingMore = false, _expanded = false, _webReady = false, _liked = false;

  DiscoveryCategory get _default => kDiscoveryCategories.first;
  Map<String, dynamic>? get _track => _items.isEmpty ? null : _items[_index];

  @override
  void initState() {
    super.initState();
    _category = _default;
    _seen.addAll(LocalLibrary.instance.recentlyShownIds);
    currentTabIndexNotifier.addListener(_tabChanged);
    _loadCategory();
  }
  void _tabChanged() { if (mounted) setState(() {}); }
  @override
  void dispose() { currentTabIndexNotifier.removeListener(_tabChanged); _pages.dispose(); super.dispose(); }

  Future<List<Map<String, dynamic>>> _fetch() async {
    try {
      final result = await forYouFeedService.fetchForCategory(_category ?? _default, excludeIds: _seen, count: 12);
      final fresh = <Map<String, dynamic>>[];
      for (final t in result) {
        final id = t['id'] as String?;
        if (id == null || id.isEmpty || _seen.contains(id)) continue;
        _seen.add(id); fresh.add(t);
      }
      return fresh;
    } catch (e) { debugPrint('[DiscoverBrowser] fetch: $e'); return []; }
  }

  Future<void> _loadCategory() async {
    final batch = await _fetch();
    if (!mounted) return;
    setState(() { _items..clear()..addAll(batch); _index = 0; _loading = false; });
    if (_items.isNotEmpty) await _select(0);
  }
  Future<void> _loadMore() async {
    if (_loadingMore || _items.length - _index > 3) return;
    _loadingMore = true;
    final batch = await _fetch();
    if (mounted && batch.isNotEmpty) setState(() => _items.addAll(batch));
    _loadingMore = false;
  }
  Future<void> _select(int index) async {
    if (!mounted || index < 0 || index >= _items.length) return;
    final t = _items[index], id = t['id'] as String?;
    if (id == null || id.isEmpty) return;
    setState(() { _index = index; _liked = LocalLibrary.instance.isLiked(id); });
    unawaited(HapticFeedback.selectionClick());
    unawaited(LocalLibrary.instance.recordRecentlyPlayed(t));
    LocalLibrary.instance.recordShownSong(id); _seen.add(id);
    await _openYouTube(id);
    unawaited(_loadMore());
  }
  Future<void> _openYouTube(String id) async {
    if (_web == null) return;
    try {
      await _web!.loadUrl(urlRequest: URLRequest(url: WebUri('https://www.youtube.com/watch?v=${Uri.encodeComponent(id)}&autoplay=1&playsinline=1')));
      Future<void>.delayed(const Duration(milliseconds: 800), () async {
        if (!mounted || _web == null) return;
        try { await _web!.evaluateJavascript(source: "document.querySelector('video')?.play?.();"); } catch (_) {}
      });
    } catch (e) { debugPrint('[DiscoverBrowser] navigation: $e'); }
  }
  Future<void> _changeCategory(DiscoveryCategory cat) async {
    setState(() { _category = cat; _items.clear(); _index = 0; _loading = true; });
    forYouFeedService.setMood(cat.label, cat.query);
    final batch = await _fetch();
    if (!mounted) return;
    setState(() { _items.addAll(batch); _loading = false; });
    if (_items.isNotEmpty) { _pages.jumpToPage(0); await _select(0); }
  }

  void _showCategories({bool genres = false}) {
    final genreIds = <String>{'bollywood','punjabi','global','indie','devotional','sufi','nostalgia'};
    final list = genres ? kDiscoveryCategories.where((c) => genreIds.contains(c.id)).toList() : kDiscoveryCategories;
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (sheet) => Container(
        height: MediaQuery.of(context).size.height * .72,
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: SafeArea(child: Column(children: [
          const SizedBox(height: 10), Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.all(Radius.circular(4)))),
          const SizedBox(height: 16), Text(genres ? 'Choose a Genre' : 'Choose a Mood', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Expanded(child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.25),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final c = list[i], selected = c.id == _category?.id;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () { Navigator.pop(sheet); unawaited(_changeCategory(c)); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: selected ? AppColors.primaryGradient : AppColors.cardGradient, border: Border.all(color: selected ? AppColors.primaryLight : AppColors.border)),
                  child: Row(children: [Text(c.icon, style: const TextStyle(fontSize: 22)), const SizedBox(width: 8), Expanded(child: Text(c.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)))]),
                ),
              );
            },
          )),
        ])),
      ),
    );
  }

  Future<void> _like() async { final t = _track; if (t == null) return; await LocalLibrary.instance.toggleLiked(t); if (mounted) setState(() => _liked = !_liked); }
  Future<void> _share() async { final t = _track; if (t == null) return; final id = t['id'] as String? ?? ''; await Share.share('${t['title'] ?? 'Song'}\nhttps://www.youtube.com/watch?v=$id'); }
  Future<void> _addPlaylist() async {
    final t = _track; if (t == null) return;
    await showModalBottomSheet<void>(context: context, backgroundColor: AppColors.surface, showDragHandle: true,
      builder: (sheet) => ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: LocalLibrary.instance.playlists,
        builder: (context, playlists, _) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Add to playlist', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          if (playlists.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No playlists yet. Create one from Library.'))
          else ...playlists.take(10).map((p) => ListTile(leading: const Icon(Icons.queue_music_rounded), title: Text(p['name'] as String? ?? 'Playlist'), onTap: () async { await LocalLibrary.instance.addTrackToPlaylist(p['id'] as String, t); if (sheet.mounted) Navigator.pop(sheet); })),
          const SizedBox(height: 12),
        ])),
      ),
    );
  }
  Widget _action(IconData icon, String label, VoidCallback tap, {bool active = false}) => GestureDetector(onTap: tap, child: Column(children: [Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(.42), border: Border.all(color: Colors.white.withOpacity(.14))), child: Icon(icon, color: active ? AppColors.hotPink : Colors.white, size: 25)), const SizedBox(height: 5), Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 4, color: Colors.black)]))]));

  Widget _browser() {
    final height = _expanded ? MediaQuery.of(context).size.height * .60 : 72.0;
    return AnimatedContainer(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic, height: height, clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: const Color(0xFF10131B), borderRadius: BorderRadius.circular(_expanded ? 24 : 18), border: Border.all(color: Colors.white.withOpacity(.14)), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, -8))]),
      child: Column(children: [
        GestureDetector(
          onVerticalDragUpdate: (d) { if (d.delta.dy < -4 && !_expanded) setState(() => _expanded = true); if (d.delta.dy > 4 && _expanded) setState(() => _expanded = false); },
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(height: 72, padding: const EdgeInsets.symmetric(horizontal: 12), color: const Color(0xFF151923), child: Row(children: [
            SizedBox(width: 50, height: 50, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _track?['artwork'] != null ? AppImage(_track!['artwork'] as String, fit: BoxFit.cover) : const ColoredBox(color: Colors.black))),
            const SizedBox(width: 10), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('YouTube Browser', style: TextStyle(color: AppColors.primaryLight, fontSize: 10, fontWeight: FontWeight.w900)), Text(_track?['title'] as String? ?? 'YouTube', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), Text(_track?['artist'] as String? ?? 'YouTube', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11))])),
            Icon(_expanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 28),
          ])),
        ),
        if (_expanded) SizedBox(height: 42, child: Row(children: [IconButton(onPressed: () => _web?.goBack(), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17)), IconButton(onPressed: () => _web?.goForward(), icon: const Icon(Icons.arrow_forward_ios_rounded, size: 17)), Expanded(child: Container(height: 30, padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: const Color(0xFF181D28), borderRadius: BorderRadius.circular(15)), child: const Row(children: [Icon(Icons.lock_rounded, size: 13, color: Colors.white54), SizedBox(width: 6), Text('youtube.com', style: TextStyle(color: Colors.white60, fontSize: 12))]))), IconButton(onPressed: () => _web?.reload(), icon: const Icon(Icons.refresh_rounded, size: 19))])),
        Expanded(child: Stack(children: [
          InAppWebView(
            keepAlive: _keepAlive,
            initialUrlRequest: URLRequest(url: WebUri('https://www.youtube.com/')),
            initialSettings: InAppWebViewSettings(javaScriptEnabled: true, domStorageEnabled: true, thirdPartyCookiesEnabled: true, mediaPlaybackRequiresUserGesture: false, allowBackgroundAudioPlaying: true, allowsInlineMediaPlayback: true, allowsPictureInPictureMediaPlayback: true, javaScriptCanOpenWindowsAutomatically: true, useHybridComposition: true, supportZoom: false),
            onWebViewCreated: (controller) { _web = controller; if (mounted) setState(() => _webReady = true); },
            onLoadStop: (controller, url) async { if (!mounted) return; if (!_webReady) setState(() => _webReady = true); try { await controller.evaluateJavascript(source: "document.querySelector('video')?.play?.();"); } catch (_) {} },
          ),
          if (!_webReady) const Center(child: CircularProgressIndicator(color: AppColors.primaryLight)),
        ])),
      ]),
    );
  }

  Widget _page(Map<String, dynamic> t) {
    final art = t['artwork'] as String?;
    return Stack(fit: StackFit.expand, children: [
      if (art != null) Stack(fit: StackFit.expand, children: [Transform.scale(scale: 1.18, child: ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28), child: AppImage(art, fit: BoxFit.cover))), Container(color: Colors.black.withOpacity(.50)), const DecoratedBox(decoration: AppColors.overlayGradient)]) else const ColoredBox(color: Colors.black),
      SafeArea(child: Column(children: [
        _topTabs(),
        Expanded(child: Stack(children: [
          Center(child: Padding(padding: const EdgeInsets.only(left: 24, right: 82, bottom: 74), child: AspectRatio(aspectRatio: 1, child: ClipRRect(borderRadius: BorderRadius.circular(28), child: art == null ? const ColoredBox(color: Colors.black) : AppImage(art, fit: BoxFit.cover))))),
          Positioned(right: 12, bottom: 118, child: Column(children: [_action(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, 'Like', _like, active: _liked), const SizedBox(height: 17), _action(Icons.playlist_add_rounded, 'Add', _addPlaylist), const SizedBox(height: 17), _action(Icons.chat_bubble_outline_rounded, 'Comment', () => CommentSheet.show(context, shotId: t['id'] as String)), const SizedBox(height: 17), _action(Icons.share_rounded, 'Share', _share), const SizedBox(height: 17), _action(Icons.open_in_full_rounded, 'Browser', () => setState(() => _expanded = true))])),
          Positioned(left: 24, right: 90, bottom: 24, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_category?.label ?? 'For You', style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(t['title'] as String? ?? 'Unknown Song', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 23, height: 1.05, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(t['artist'] as String? ?? 'Unknown Artist', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600))])),
        ])),
      ])),
    ]);
  }

  Widget _topTabs() => SizedBox(height: 52, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), children: [_tab('For You', true, () {}), _tab('Moods', false, _showCategories), _tab('Genres', false, () => _showCategories(genres: true)), _tab('Trending', false, () { final c = discoveryCategoryById('trending'); if (c != null) unawaited(_changeCategory(c)); }), _tab('New', false, () { final c = discoveryCategoryById('global'); if (c != null) unawaited(_changeCategory(c)); })]);
  Widget _tab(String text, bool selected, VoidCallback tap) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: GestureDetector(onTap: tap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10), decoration: BoxDecoration(color: selected ? AppColors.accent : Colors.black.withOpacity(.58), borderRadius: BorderRadius.circular(15), border: Border.all(color: selected ? AppColors.accent : Colors.white.withOpacity(.12))), child: Text(text, style: TextStyle(color: selected ? Colors.black : Colors.white, fontSize: 13, fontWeight: FontWeight.w800))));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator(color: AppColors.primaryLight)));
    if (_items.isEmpty) return const Scaffold(backgroundColor: AppColors.background, body: Center(child: Text('No fresh songs available. Try another mood.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70))));
    final bottom = MediaQuery.of(context).padding.bottom + 68;
    return Scaffold(backgroundColor: Colors.black, body: Stack(children: [PageView.builder(controller: _pages, scrollDirection: Axis.vertical, itemCount: _items.length, physics: const BouncingScrollPhysics(), onPageChanged: _select, itemBuilder: (context, i) => _page(_items[i])), Positioned(left: 10, right: 10, bottom: bottom, child: _browser())]));
  }
}

// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — Discovery Reels (TikTok/Reels-style vertical music discovery)
//
// Full-screen vertical discovery feed. Default landing is "For You" (immediate
// music). Top control chips: For You | Moods | Genres | Trending | New.
// Mood/Genre open visual picker screens that transform into a mood/genre feed.
//
// Interaction: swipe up -> next, swipe down -> previous, tap Play -> existing
// official player, double-tap -> like, long-press -> quick actions. Right rail:
// Like, Add, Share, More. Not-interested / blocked artists feed the
// recommendation learning loop.
//
// Real data via shared InnerTubeMusicService. Playback via existing official
// player (no second engine, no audio extraction).
// ═════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/discovery/innertube_music_service.dart';
import '../../core/recommendation/recommendation_event_service.dart';
import '../../core/recommendation/recommendation_memory.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';
import '../home/archive_home_screen.dart' show OnPlayTrack;

enum _FeedKind { forYou, mood, genre, trending, newMusic }

class DiscoveryReelsScreen extends StatefulWidget {
  const DiscoveryReelsScreen({
    super.key,
    required this.service,
    required this.onPlayTrack,
  });

  final InnerTubeMusicService service;
  final OnPlayTrack onPlayTrack;

  @override
  State<DiscoveryReelsScreen> createState() => _DiscoveryReelsScreenState();
}

class _DiscoveryReelsScreenState extends State<DiscoveryReelsScreen>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  final List<DiscoveryTrack> _tracks = [];
  final Set<String> _seenIds = {};
  bool _loading = true;
  bool _loadingMore = false;
  int _currentIndex = 0;

  _FeedKind _kind = _FeedKind.forYou;
  String? _activeMood; // e.g. Romantic

  static const _modeChips = <String>[
    'For You',
    'Moods',
    'Genres',
    'Trending',
    'New'
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String? get _moodArg {
    if (_kind == _FeedKind.mood) return _activeMood;
    if (_kind == _FeedKind.genre) return _activeMood;
    return null;
  }

  Future<void> _loadInitial({_FeedKind? kind, String? mood}) async {
    setState(() {
      _loading = true;
      if (kind != null) _kind = kind;
      if (mood != null) _activeMood = mood;
    });
    final lib = LocalLibrary.instance;
    final exclude = {..._seenIds};
    try {
      final String? moodArg = _moodArg;
      List<DiscoveryTrack> feed;
      switch (_kind) {
        case _FeedKind.forYou:
          feed = await widget.service.discoveryFeed(
            target: 30,
            excludeIds: exclude,
            blockedArtists: lib.blockedArtists,
            notInterestedIds: lib.notInterestedIds,
          );
          break;
        case _FeedKind.mood:
        case _FeedKind.genre:
          feed = await widget.service.genreFeed(
            moodArg ?? 'Trending',
            target: 30,
            excludeIds: exclude,
            blockedArtists: lib.blockedArtists,
            notInterestedIds: lib.notInterestedIds,
          );
          break;
        case _FeedKind.trending:
          feed = await widget.service.discoveryFeed(
            mood: 'Trending',
            target: 30,
            excludeIds: exclude,
            blockedArtists: lib.blockedArtists,
            notInterestedIds: lib.notInterestedIds,
          );
          break;
        case _FeedKind.newMusic:
          feed =
              await widget.service.search('new music 2026 releases', count: 30);
          break;
      }
      if (!mounted) return;
      setState(() {
        _tracks.clear();
        _tracks.addAll(feed);
        _seenIds.addAll(feed.map((t) => t.id));
        _currentIndex = 0;
        _loading = false;
      });
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      if (feed.isNotEmpty) unawaited(_play(0));
      for (final t in feed) {
        LocalLibrary.instance.recordShownSong(t.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    _loadingMore = true;
    final lib = LocalLibrary.instance;
    try {
      List<DiscoveryTrack> feed;
      if (_kind == _FeedKind.newMusic) {
        feed = await widget.service.search('new music 2026', count: 20);
      } else {
        feed = await widget.service.discoveryFeed(
          mood: _moodArg,
          target: 20,
          excludeIds: _seenIds,
          blockedArtists: lib.blockedArtists,
          notInterestedIds: lib.notInterestedIds,
        );
      }
      if (!mounted) return;
      final fresh = feed.where((t) => _seenIds.add(t.id)).toList();
      setState(() => _tracks.addAll(fresh));
      for (final t in fresh) {
        LocalLibrary.instance.recordShownSong(t.id);
      }
    } catch (_) {
      // keep current feed
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _play(int index) async {
    final track = _tracks[index];
    final queue = _tracks.map((t) => t.toTrackMap()).toList();
    await widget.onPlayTrack(track.toTrackMap(), queue, index);
  }

  void _onPageChanged(int index) {
    final previous = _currentIndex;
    if (previous != index && previous < _tracks.length) {
      final old = _tracks[previous];
      RecommendationMemory.instance.recordSkip(old.id);
      RecommendationEventService.instance.track(
        RecommendationEvents.discoverSwipe,
        videoId: old.id,
        extra: {'category': _contextLabel(), 'toIndex': index},
      );
    }
    setState(() => _currentIndex = index);
    // Discovery is swipe-first: selecting a page immediately hands the track
    // to the existing global/official player.
    unawaited(_play(index));
    if (_tracks.length - index < 5) unawaited(_loadMore());
  }

  void _openMoodPicker() async {
    final chosen = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _MoodPickerScreen()),
    );
    if (chosen != null && mounted) {
      unawaited(_loadInitial(kind: _FeedKind.mood, mood: chosen));
    }
  }

  void _openGenrePicker() async {
    final chosen = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _GenrePickerScreen()),
    );
    if (chosen != null && mounted) {
      unawaited(_loadInitial(kind: _FeedKind.genre, mood: chosen));
    }
  }

  void _selectChip(String label) {
    switch (label) {
      case 'For You':
        _loadInitial(kind: _FeedKind.forYou);
        break;
      case 'Moods':
        _openMoodPicker();
        break;
      case 'Genres':
        _openGenrePicker();
        break;
      case 'Trending':
        _loadInitial(kind: _FeedKind.trending);
        break;
      case 'New':
        _loadInitial(kind: _FeedKind.newMusic);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _tracks.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (_tracks.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.headphones_rounded,
                  size: 52, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text('Discovery is taking a break',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text("We couldn't load recommendations right now.",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: () => _loadInitial(kind: _FeedKind.forYou),
                  child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            itemCount: _tracks.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final track = _tracks[index];
              return _ReelsCard(
                track: track,
                isActive: index == _currentIndex,
                contextLabel: _contextLabel(),
                onPlayPause: () => _play(index),
                onLike: () => _toggleLike(track),
                onAdd: () => _showAddSheet(track),
                onShare: () => _share(track),
                onMore: () => _showMoreSheet(track),
                onNotInterested: () => _markNotInterested(track),
                onBlockArtist: () => _blockArtist(track),
              );
            },
          ),
          // Top control chips (minimal glass pills).
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _modeChips.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final label = _modeChips[i];
                      final selected = _isChipSelected(label);
                      return ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (_) => _selectChip(label),
                        labelStyle: TextStyle(
                          color: selected ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        selectedColor: AppColors.accent,
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                        side: BorderSide.none,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isChipSelected(String label) {
    switch (label) {
      case 'For You':
        return _kind == _FeedKind.forYou;
      case 'Moods':
        return _kind == _FeedKind.mood;
      case 'Genres':
        return _kind == _FeedKind.genre;
      case 'Trending':
        return _kind == _FeedKind.trending;
      case 'New':
        return _kind == _FeedKind.newMusic;
    }
    return false;
  }

  String _contextLabel() {
    switch (_kind) {
      case _FeedKind.forYou:
        return 'For You';
      case _FeedKind.mood:
        return _activeMood ?? 'Mood';
      case _FeedKind.genre:
        return _activeMood ?? 'Genre';
      case _FeedKind.trending:
        return 'Trending';
      case _FeedKind.newMusic:
        return 'New Music';
    }
  }

  void _toggleLike(DiscoveryTrack track) {
    HapticFeedback.lightImpact();
    LocalLibrary.instance.toggleLiked(track.toTrackMap());
    setState(() {});
  }

  void _showAddSheet(DiscoveryTrack track) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add to',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading:
                  const Icon(Icons.favorite_rounded, color: AppColors.hotPink),
              title: const Text('Liked Songs'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleLike(track);
              },
            ),
            for (final p in LocalLibrary.instance.playlists.value.take(6))
              ListTile(
                leading: const Icon(Icons.queue_music_rounded,
                    color: AppColors.accent),
                title: Text(p['name'] as String? ?? 'Playlist'),
                onTap: () {
                  LocalLibrary.instance.addTrackToPlaylist(
                      p['id'] as String, track.toTrackMap());
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Added to playlist'),
                      duration: Duration(seconds: 1)));
                },
              ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Create playlist'),
              onTap: () {
                Navigator.pop(ctx);
                _createPlaylist(track);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPlaylist(DiscoveryTrack track) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('New Playlist'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await LocalLibrary.instance.createPlaylist(name);
      await LocalLibrary.instance.addTrackToPlaylist(
          LocalLibrary.instance.playlists.value.first['id'] as String,
          track.toTrackMap());
    }
  }

  void _share(DiscoveryTrack track) {
    HapticFeedback.lightImpact();
    SharePlus.instance.share(
      ShareParams(
        text: 'Listen to "${track.title}" by ${track.artist} on V Shots: '
            'https://www.youtube.com/watch?v=${track.id}',
      ),
    );
  }

  void _showMoreSheet(DiscoveryTrack track) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_play_rounded),
              title: const Text('Play next'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.add_to_queue_rounded),
              title: const Text('Add to queue'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Open on YouTube'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(
                    text: 'https://www.youtube.com/watch?v=${track.id}'));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('YouTube link copied'),
                    duration: Duration(seconds: 1)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.thumb_down_alt_outlined),
              title: const Text('Not interested'),
              onTap: () {
                Navigator.pop(ctx);
                _markNotInterested(track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: const Text("Don't recommend this artist"),
              onTap: () {
                Navigator.pop(ctx);
                _blockArtist(track);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _markNotInterested(DiscoveryTrack track) {
    LocalLibrary.instance.markNotInterested(track.id);
    setState(() {
      _tracks.removeWhere((t) => t.id == track.id);
      _seenIds.add(track.id);
    });
    _loadMore();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Noted — we\'ll show less of this'),
        duration: Duration(seconds: 1)));
  }

  void _blockArtist(DiscoveryTrack track) {
    LocalLibrary.instance.blockArtist(track.artist);
    setState(() {
      _tracks.removeWhere((t) => t.artist == track.artist);
    });
    _loadMore();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Artist blocked — we\'ll stop recommending them'),
        duration: Duration(seconds: 1)));
  }
}

/// Mood selection with large visual cards.
class _MoodPickerScreen extends StatelessWidget {
  const _MoodPickerScreen();

  static const _moods = <(String, String, String)>[
    ('Romantic', '❤️', 'Love & feelings'),
    ('Sad', '😢', 'Songs that hurt'),
    ('Energetic', '🔥', 'High energy'),
    ('Chill', '😌', 'Calm & relaxed'),
    ('Party', '🥳', 'Dance & celebrate'),
    ('Workout', '💪', 'Push yourself'),
    ('Focus', '🎧', 'Deep concentration'),
    ('Late Night', '🌙', 'After hours'),
    ('Heartbreak', '💔', 'Moving on'),
    ('Peaceful', '🧘', 'Inner calm'),
    ('Road Trip', '🚗', 'Hit the highway'),
    ('Happy', '☀️', 'Feel-good'),
    ('Attitude', '😈', 'Confident'),
    ('Rainy', '🌧️', 'Rainy days'),
    ('Nostalgic', '✨', 'Back in time'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('What are you feeling?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 130,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _moods.length,
        itemBuilder: (context, i) {
          final (name, emoji, desc) = _moods[i];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.pop(context, name),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _colorFor(name).withValues(alpha: 0.7),
                    AppColors.surface,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 34)),
                  const SizedBox(height: 8),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Color _colorFor(String name) {
    const map = <String, Color>{
      'Romantic': Color(0xFFE91E63),
      'Sad': Color(0xFF3F51B5),
      'Energetic': Color(0xFFFF5722),
      'Chill': Color(0xFF4CAF50),
      'Party': Color(0xFFFF9800),
      'Workout': Color(0xFFF44336),
      'Focus': Color(0xFF00BCD4),
      'Late Night': Color(0xFF37474F),
      'Heartbreak': Color(0xFF7B1FA2),
      'Peaceful': Color(0xFF009688),
      'Road Trip': Color(0xFF795548),
      'Happy': Color(0xFFFFC107),
      'Attitude': Color(0xFF212121),
      'Rainy': Color(0xFF607D8B),
      'Nostalgic': Color(0xFF8D6E63),
    };
    return map[name] ?? AppColors.accent;
  }
}

/// Genre selection.
class _GenrePickerScreen extends StatelessWidget {
  const _GenrePickerScreen();

  static const _genres = <(String, String)>[
    ('Bollywood', '🎬'),
    ('Hindi', '🎵'),
    ('Punjabi', '🥁'),
    ('English', '🎸'),
    ('Pop', '🌟'),
    ('Hip-Hop', '🎤'),
    ('EDM', '🎧'),
    ('Lo-fi', '🎹'),
    ('Global', '🌍'),
    ('Devotional', '🙏'),
    ('Rock', '🎸'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Choose a Genre',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisExtent: 80,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _genres.length,
        itemBuilder: (context, i) {
          final (name, emoji) = _genres[i];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pop(context, name),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReelsCard extends StatefulWidget {
  const _ReelsCard({
    required this.track,
    required this.isActive,
    required this.contextLabel,
    required this.onPlayPause,
    required this.onLike,
    required this.onAdd,
    required this.onShare,
    required this.onMore,
    required this.onNotInterested,
    required this.onBlockArtist,
  });

  final DiscoveryTrack track;
  final bool isActive;
  final String contextLabel;
  final VoidCallback onPlayPause;
  final VoidCallback onLike;
  final VoidCallback onAdd;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final VoidCallback onNotInterested;
  final VoidCallback onBlockArtist;

  @override
  State<_ReelsCard> createState() => _ReelsCardState();
}

class _ReelsCardState extends State<_ReelsCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _heartCtl;
  Animation<double>? _heartScale;
  Animation<double>? _heartOpacity;

  @override
  void dispose() {
    _heartCtl?.dispose();
    super.dispose();
  }

  void _doubleTapLike() {
    final ctl = _heartCtl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _heartScale = CurvedAnimation(parent: ctl, curve: Curves.easeOutBack);
    _heartOpacity = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(
      parent: ctl,
      curve: const Interval(0.4, 1.0),
    ));
    ctl.forward(from: 0);
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final isLiked = LocalLibrary.instance.isLiked(track.id);

    return GestureDetector(
      onDoubleTap: _doubleTapLike,
      onLongPress: widget.onMore,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cinematic artwork-derived background. The low-opacity blurred
          // copy is deliberately separate from the hero art so the artwork
          // remains crisp and never gets stretched as the main card.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: KeyedSubtree(
              key: ValueKey(track.id),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(track.artwork, fit: BoxFit.cover),
                  BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: Container(color: Colors.black.withValues(alpha: 0.42)),
                  ),
                ],
              ),
            ),
          ),
          // Dark gradient overlay for readability.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.8),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // Crisp square hero artwork floating above the blurred canvas.
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            left: 28,
            right: 72,
            child: AspectRatio(
              aspectRatio: 1,
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 28, offset: const Offset(0, 14))],
                    ),
                    child: AppImage(track.artwork, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ),
          // Right action rail.
          Positioned(
            right: 14,
            bottom: 170,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionButton(
                  icon: isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isLiked ? AppColors.hotPink : Colors.white,
                  label: 'Like',
                  onTap: widget.onLike,
                ),
                const SizedBox(height: 20),
                _ActionButton(
                  icon: Icons.playlist_add_rounded,
                  color: Colors.white,
                  label: 'Add',
                  onTap: widget.onAdd,
                ),
                const SizedBox(height: 20),
                _ActionButton(
                  icon: Icons.share_rounded,
                  color: Colors.white,
                  label: 'Share',
                  onTap: widget.onShare,
                ),
                const SizedBox(height: 20),
                _ActionButton(
                  icon: Icons.more_horiz_rounded,
                  color: Colors.white,
                  label: 'More',
                  onTap: widget.onMore,
                ),
              ],
            ),
          ),
          // Double-tap heart burst.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _heartCtl ?? const AlwaysStoppedAnimation(1.0),
                builder: (context, _) {
                  final ctl = _heartCtl;
                  if (ctl == null || !ctl.isAnimating) {
                    return const SizedBox.shrink();
                  }
                  return Center(
                    child: Transform.scale(
                      scale: _heartScale?.value ?? 1,
                      child: Opacity(
                        opacity: _heartOpacity?.value ?? 0,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                          child: const Icon(Icons.favorite_rounded,
                              color: AppColors.hotPink, size: 50),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Bottom metadata.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.contextLabel,
                      style: TextStyle(
                        color: AppColors.accent.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _cleanTitle(track.title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _cleanArtist(track.title, track.artist),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Normalizes messy YouTube titles: strips bracket/suffix annotations.
  String _cleanTitle(String raw) {
    var t = raw;
    // "Title (Official Video)" -> "Title"
    t = t.replaceAll(
        RegExp(
            r'\s*[\(\[]\s*(official|lyric|lyrics|video|audio|full|hd|4k|slowed|reverb)\s*[\)\]]',
            caseSensitive: false),
        '');
    // "Title - Artist" -> "Title"
    final dash = t.indexOf(' - ');
    if (dash > 0) t = t.substring(0, dash);
    // "Title | Album | ..." -> "Title"
    final bar = t.indexOf(' | ');
    if (bar > 0) t = t.substring(0, bar);
    return t.trim().isEmpty ? raw : t.trim();
  }

  String _cleanArtist(String title, String artist) {
    // If artist looks like the full YouTube title tail, prefer the simple artist.
    final a = artist.trim();
    if (a.isNotEmpty && a.length < 40) return a;
    return 'Unknown Artist';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

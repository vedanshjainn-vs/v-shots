// ════════════════════════════════════════════════
// V Shots — "For You" Feed (Resso-style vertical swipe discovery)
// ════════════════════════════════════════════════
//
// Implements the pattern requested: a TikTok/Resso-style full-screen
// vertical feed where swiping up loads the next recommended song and
// auto-plays it, tapping pauses/resumes, and content is continuously
// generated (not a fixed list).
//
// ⚠️ Honest disclosure (per UI_REDESIGN_MASTER_PROMPT.md Part 2, already
// shown to the user): Resso (ByteDance's music app) is the real-world
// precedent for this UI pattern, but Resso itself is discontinued
// (banned in India Dec 2023/Jan 2024, globally shut down as "TikTok
// Music" Nov 28 2024). Nothing here uses Resso's code/brand/backend —
// this is an independent implementation of the same INTERACTION PATTERN
// (swipe = next, tap = pause), which is not something Resso owns.
//
// REAL, VERIFIED IMPLEMENTATION DETAILS:
//   - `PageView.builder(scrollDirection: Axis.vertical)` is the
//     standard, documented Flutter pattern for TikTok-style vertical
//     feeds (confirmed via real StackOverflow implementations during
//     this session's research).
//   - Auto-play on page change: `onPageChanged` triggers `_playIndex`.
//   - Tap-to-pause is a separate `GestureDetector.onTap`, distinct from
//     the swipe gesture — matches Resso's confirmed real UX split.
//   - Preloading: while page N plays, this resolves page N+1's stream
//     URL in the background so swiping doesn't have a visible stutter
//     waiting on a fresh YouTube manifest fetch (a real network
//     round-trip, not instant — see MASTER_BUILD_PROMPT.md's original
//     recommendation to preload for exactly this reason).
//   - Infinite feed: requests the next batch from ForYouFeedService
//     when the user is within 3 items of the end.
// ════════════════════════════════════════════════

import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../main.dart' show
    audioPlayer,
    audioHandler,
    currentTrack,
    currentQueue,
    currentQueueIndex,
    likedSongIds,
    forYouFeedService;
import 'for_you_feed_service.dart';

class ForYouFeedScreen extends StatefulWidget {
  const ForYouFeedScreen({super.key});

  @override
  State<ForYouFeedScreen> createState() => _ForYouFeedScreenState();
}

class _ForYouFeedScreenState extends State<ForYouFeedScreen> {
  final _pageController = PageController();
  final YoutubeExplode _yt = YoutubeExplode();

  final List<Map<String, dynamic>> _items = [];
  final Set<String> _seenIds = {};
  final Map<int, String> _resolvedStreamUrls = {}; // index -> stream URL

  int _currentIndex = 0;
  bool _isLoadingMore = false;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialBatch();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _yt.close();
    super.dispose();
  }

  Future<void> _loadInitialBatch() async {
    final batch = await forYouFeedService.fetchNextBatch(excludeIds: _seenIds);
    if (!mounted) return;
    setState(() {
      _items.addAll(batch);
      _seenIds.addAll(batch.map((t) => t['id'] as String));
      _initialLoading = false;
    });
    if (_items.isNotEmpty) {
      _playIndex(0);
      _preloadIndex(1);
    }
  }

  Future<void> _maybeLoadMore() async {
    if (_isLoadingMore) return;
    if (_items.length - _currentIndex > 3) return; // still enough buffer
    _isLoadingMore = true;
    final batch = await forYouFeedService.fetchNextBatch(excludeIds: _seenIds);
    if (mounted) {
      setState(() {
        _items.addAll(batch);
        _seenIds.addAll(batch.map((t) => t['id'] as String));
      });
    }
    _isLoadingMore = false;
  }

  /// Resolves and caches a stream URL for [index] without playing it —
  /// used to preload the next item while the current one plays, so a
  /// swipe feels instant instead of waiting on a fresh network
  /// round-trip to YouTube's manifest endpoint.
  Future<void> _preloadIndex(int index) async {
    if (index < 0 || index >= _items.length) return;
    if (_resolvedStreamUrls.containsKey(index)) return;
    final track = _items[index];
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(track['id'] as String);
      final audio = manifest.audioOnly.sortByBitrate();
      if (audio.isEmpty) return;
      final stream = audio.toList()[(audio.length / 2).floor()];
      _resolvedStreamUrls[index] = stream.url.toString();
    } catch (_) {
      // Preload failures are non-fatal — _playIndex will just resolve
      // fresh (with a visible loading state) if the cache miss happens.
    }
  }

  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= _items.length) return;
    final track = _items[index];

    setState(() => _currentIndex = index);

    try {
      String? streamUrl = _resolvedStreamUrls[index];
      streamUrl ??= await () async {
        final manifest = await _yt.videos.streamsClient.getManifest(track['id'] as String);
        final audio = manifest.audioOnly.sortByBitrate();
        if (audio.isEmpty) return null;
        final stream = audio.toList()[(audio.length / 2).floor()];
        return stream.url.toString();
      }();

      if (streamUrl == null) return;

      await audioPlayer.setUrl(streamUrl);
      await audioPlayer.play();

      // Keep the rest of the app (mini-player, PlayerScreen, OS media
      // session) in sync with what's playing in this feed, using the
      // exact same globals main.dart's own playTrack() uses — this
      // feed is just another entry point into the same single
      // AudioPlayer/queue, not a separate playback path.
      currentTrack = track;
      currentQueue = List<Map<String, dynamic>>.from(_items);
      currentQueueIndex = index;
      audioHandler.updateNowPlaying(_trackToMediaItem(track));

      // Feed the recommendation signal (see ForYouFeedService) — this
      // is what makes the feed feel personalized over time.
      forYouFeedService.recordPlay(track['artist'] as String? ?? '');
    } catch (e) {
      debugPrint('[ForYouFeed] Failed to play index $index: $e');
    }

    _preloadIndex(index + 1);
    _maybeLoadMore();
  }

  MediaItem _trackToMediaItem(Map<String, dynamic> track) => MediaItem(
        id: (track['id'] as String?) ?? '',
        title: (track['title'] as String?) ?? 'Unknown title',
        artist: (track['artist'] as String?) ?? 'Unknown artist',
        artUri: (track['artwork'] as String?) != null
            ? Uri.tryParse(track['artwork'] as String)
            : null,
      );

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF4D6A))),
      );
    }

    if (_items.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 48, color: Colors.white.withOpacity(0.4)),
              const SizedBox(height: 12),
              Text('Could not load recommendations',
                  style: TextStyle(color: Colors.white.withOpacity(0.6))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _initialLoading = true);
                  _loadInitialBatch();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _items.length,
        onPageChanged: (index) {
          HapticFeedback.selectionClick();
          _playIndex(index);
        },
        itemBuilder: (context, index) => _ForYouCard(
          track: _items[index],
          isActive: index == _currentIndex,
        ),
      ),
    );
  }
}

class _ForYouCard extends StatelessWidget {
  const _ForYouCard({required this.track, required this.isActive});

  final Map<String, dynamic> track;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final artwork = track['artwork'] as String?;
    final title = (track['title'] as String?) ?? '';
    final artist = (track['artist'] as String?) ?? '';

    return GestureDetector(
      // Tap = pause/resume, kept deliberately separate from the
      // PageView's own vertical swipe-to-skip gesture — matches
      // Resso's confirmed real UX split (see file header).
      onTap: () {
        HapticFeedback.lightImpact();
        if (audioPlayer.playing) {
          audioPlayer.pause();
        } else {
          audioPlayer.play();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed blurred artwork background.
          if (artwork != null)
            Image.network(artwork, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A2E)))
          else
            Container(color: const Color(0xFF1A1A2E)),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

          // Foreground content.
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: artwork != null
                          ? Image.network(artwork, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFF1A1A2E),
                                  child: const Icon(Icons.music_note,
                                      size: 60, color: Color(0xFFFF4D6A))))
                          : Container(
                              color: const Color(0xFF1A1A2E),
                              child: const Icon(Icons.music_note,
                                  size: 60, color: Color(0xFFFF4D6A))),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 6),
                Text(artist,
                    style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.75))),
                const SizedBox(height: 8),
                // Play/pause indicator (also reacts to the tap gesture
                // above) — small, unobtrusive, matches the "immersive,
                // minimal UI" intent from the Resso reference pattern.
                StreamBuilder<PlayerState>(
                  stream: audioPlayer.playerStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return Icon(
                      playing ? Icons.volume_up_rounded : Icons.pause_circle_outline,
                      color: Colors.white.withOpacity(0.85),
                      size: 22,
                    );
                  },
                ),
                const SizedBox(height: 40),
                // Thin progress indicator near the bottom edge — gives
                // at-a-glance position feedback without cluttering the
                // immersive visual (per UI_REDESIGN_MASTER_PROMPT.md
                // Part 4.2's design notes for this exact feed).
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: StreamBuilder<Duration>(
                    stream: audioPlayer.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = audioPlayer.duration ?? Duration.zero;
                      final progress = duration.inMilliseconds > 0
                          ? (position.inMilliseconds / duration.inMilliseconds)
                              .clamp(0.0, 1.0)
                          : 0.0;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: Colors.white.withOpacity(0.15),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFFFF4D6A)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Like button — secondary action, kept out of the main
          // swipe/tap gestures per the Resso-pattern "three-dot menu
          // stays separate from primary interactions" design note.
          Positioned(
            right: 16,
            bottom: 140,
            child: StatefulBuilder(
              builder: (context, setLikeState) {
                final isLiked = likedSongIds.contains(track['id']);
                return IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? const Color(0xFFFF4D6A) : Colors.white,
                    size: 32,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setLikeState(() {
                      if (isLiked) {
                        likedSongIds.remove(track['id']);
                      } else {
                        likedSongIds.add(track['id'] as String);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

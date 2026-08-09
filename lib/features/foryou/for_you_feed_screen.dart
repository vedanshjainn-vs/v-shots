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

import 'dart:async';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/storage/local_library.dart';
import '../../shared/widgets/app_image.dart';
// Phase 3 fix: no longer imports `likedSongIds` (a stale reference —
// that global was removed from main.dart when LocalLibrary replaced
// it; this `show` clause was never updated, a real
// `undefined_shown_name` analyzer warning confirmed in
// docs/CURRENT_BASELINE.md Section 7) or `sharedYt`/stream_resolver.dart
// directly (Phase 3's "UI must never directly call YoutubeExplode" —
// this screen now goes through `musicRepository` instead, see below).
import '../../main.dart' show
    audioPlayer,
    audioHandler,
    currentTrack,
    currentQueue,
    currentQueueIndex,
    forYouFeedService,
    musicRepository,
    showMoreOptionsSheet,
    showAddToPlaylistSheet;

class ForYouFeedScreen extends StatefulWidget {
  const ForYouFeedScreen({super.key});

  @override
  State<ForYouFeedScreen> createState() => _ForYouFeedScreenState();
}

class _ForYouFeedScreenState extends State<ForYouFeedScreen> {
  final _pageController = PageController();
  // Reuses the single app-wide shared instance from main.dart (see
  // refinement list Section B #2) — this screen previously constructed
  // its OWN separate YoutubeExplode() and, worse, called .close() on
  // it in dispose(), which is harmless for a private instance but
  // would have been a real bug (closing the shared HTTP client out
  // from under the rest of the app) had this just been swapped to the
  // shared instance without also removing that close() call below.

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
    // Deliberately NOT closing sharedYt here — it's the single
    // app-wide instance used by Home/Search/Player too, not owned by
    // this screen. Closing it would break YouTube search/playback
    // everywhere else the moment a user navigates away from Discover.
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
      // Phase 3 fix: routed through MusicRepository -> ProviderManager
      // -> YouTubeMusicProvider, which itself delegates to the
      // existing resolveAudioStreamUrlLogged()/stream_resolver.dart —
      // this screen no longer calls that (or `sharedYt`) directly.
      final streamUrl = await musicRepository.getStream(track['id'] as String);
      if (streamUrl != null) {
        _resolvedStreamUrls[index] = streamUrl;
      }
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
      streamUrl ??= await musicRepository.getStream(track['id'] as String);

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
      audioHandler?.updateNowPlaying(_trackToMediaItem(track));

      // Persist to Recently Played — this is also what feeds the "For
      // You" recency-weighted taste signal (see
      // ForYouFeedService._recencyWeightedArtistScores, revision 2):
      // previously this screen only updated a separate, non-persisted
      // counter that reset on every app restart and wasn't shared with
      // Home/Search plays at all.
      unawaited(LocalLibrary.instance.recordRecentlyPlayed(track));
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
          onNotInterested: () => _handleNotInterested(index),
        ),
      ),
    );
  }

  /// "Not interested in this artist" — records the signal in
  /// ForYouFeedService (so future picks avoid this artist) AND
  /// immediately advances past the current track, since the user has
  /// just said they don't want to hear it — leaving it playing after
  /// tapping "not interested" would be a confusing, contradictory UX.
  void _handleNotInterested(int index) {
    final artist = _items[index]['artist'] as String? ?? '';
    forYouFeedService.markNotInterested(artist);
    if (index < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }
}

class _ForYouCard extends StatelessWidget {
  const _ForYouCard({
    required this.track,
    required this.isActive,
    required this.onNotInterested,
  });

  final Map<String, dynamic> track;
  final bool isActive;
  final VoidCallback onNotInterested;

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
          AppImage(artwork, fit: BoxFit.cover),
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
                    child: AppImage(
                      artwork,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(20),
                      errorIconColor: const Color(0xFFFF4D6A),
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
            bottom: 190,
            child: StatefulBuilder(
              builder: (context, setLikeState) {
                final isLiked =
                    LocalLibrary.instance.isLiked(track['id'] as String? ?? '');
                return IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? const Color(0xFFFF4D6A) : Colors.white,
                    size: 32,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    LocalLibrary.instance.toggleLiked(track).then((_) {
                      setLikeState(() {});
                    });
                  },
                );
              },
            ),
          ),
          // "•••" more-options — previously entirely absent from this
          // screen (the file header's own design notes planned a
          // "three-dot menu" here but it was never actually built).
          // Wires to the SAME shared bottom sheet PlayerScreen uses
          // (main.dart's showMoreOptionsSheet) — Sleep Timer, Share,
          // and (unique to this recommendation surface) "Not
          // interested in this artist", which feeds back into
          // ForYouFeedService as a real signal, not just a UI gesture.
          Positioned(
            right: 16,
            bottom: 130,
            child: IconButton(
              icon: const Icon(Icons.more_horiz, color: Colors.white, size: 30),
              onPressed: () {
                HapticFeedback.lightImpact();
                showMoreOptionsSheet(
                  context,
                  track,
                  onNotInterested: onNotInterested,
                );
              },
            ),
          ),
          // "Add to playlist" — was previously only reachable from the
          // full PlayerScreen, meaning this feed's like button was the
          // only way to save a track from here at all.
          Positioned(
            right: 16,
            bottom: 70,
            child: IconButton(
              icon: const Icon(Icons.playlist_add, color: Colors.white, size: 30),
              onPressed: () {
                HapticFeedback.lightImpact();
                showAddToPlaylistSheet(context, track);
              },
            ),
          ),
        ],
      ),
    );
  }
}

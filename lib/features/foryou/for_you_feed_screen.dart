// ═════════════════════════════════════════════════════════════════════════════
// V Shots — "For You" Feed (Nova Vertical Swipe Discovery)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/motion/motion.dart';
import '../../core/recommendation/feed_intent.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';
import '../../shared/widgets/comment_sheet.dart';
import '../../main.dart' show
    audioPlayer,
    audioHandler,
    currentTrack,
    currentQueue,
    currentQueueIndex,
    forYouFeedService,
    musicRepository,
    playbackSignalTracker,
    recommendationEngine,
    showMoreOptionsSheet,
    showAddToPlaylistSheet;

class ForYouFeedScreen extends StatefulWidget {
  const ForYouFeedScreen({super.key});

  @override
  State<ForYouFeedScreen> createState() => _ForYouFeedScreenState();
}

class _ForYouFeedScreenState extends State<ForYouFeedScreen> {
  final PageController _pageController = PageController();

  final List<Map<String, dynamic>> _items = [];
  final Set<String> _seenIds = {};
  final Map<int, String> _resolvedStreamUrls = {}; // index -> stream URL

  int _currentIndex = 0;
  int _playSeq = 0;
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
    super.dispose();
  }

  Future<void> _loadInitialBatch() async {
    final batch = await _fetchDiscoverBatch();
    if (!mounted) return;
    setState(() {
      _items.addAll(batch);
      _seenIds.addAll(batch.map((t) => t['id'] as String));
      _initialLoading = false;
    });
    if (_items.isNotEmpty) {
      unawaited(_playIndex(0));
      unawaited(_preloadIndex(1));
      unawaited(_preloadIndex(2));
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDiscoverBatch() async {
    try {
      final scored = await recommendationEngine.generateFeed(
        intent: FeedIntent.discoverSomethingNew,
        excludeIds: _seenIds,
        count: 8,
      );
      if (scored.isNotEmpty) {
        return scored.map((s) => s.track.toTrackMap()).toList();
      }
    } catch (e) {
      debugPrint('[ForYouFeed] Engine discover batch failed, falling back: $e');
    }
    return forYouFeedService.fetchNextBatch(excludeIds: _seenIds);
  }

  Future<void> _maybeLoadMore() async {
    if (_isLoadingMore) return;
    if (_items.length - _currentIndex > 3) return;
    _isLoadingMore = true;
    final batch = await _fetchDiscoverBatch();
    if (mounted) {
      setState(() {
        _items.addAll(batch);
        _seenIds.addAll(batch.map((t) => t['id'] as String));
      });
    }
    _isLoadingMore = false;
  }

  Future<void> _preloadIndex(int index) async {
    if (index < 0 || index >= _items.length) return;
    if (_resolvedStreamUrls.containsKey(index)) return;
    final track = _items[index];
    try {
      final streamUrl = await musicRepository.getStream(track['id'] as String);
      if (streamUrl != null) {
        _resolvedStreamUrls[index] = streamUrl;
      }
    } catch (_) {
      // Non-fatal
    }
  }

  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= _items.length) return;
    final track = _items[index];
    final seq = ++_playSeq;

    setState(() => _currentIndex = index);

    try {
      String? streamUrl = _resolvedStreamUrls[index];
      streamUrl ??= await musicRepository.getStream(track['id'] as String);

      if (streamUrl == null || seq != _playSeq || !mounted) return;

      await audioPlayer.setUrl(streamUrl);
      if (seq != _playSeq || !mounted) return;
      await audioPlayer.play();

      currentTrack = track;
      currentQueue = List<Map<String, dynamic>>.from(_items);
      currentQueueIndex = index;
      audioHandler?.updateNowPlaying(_trackToMediaItem(track));

      unawaited(LocalLibrary.instance.recordRecentlyPlayed(track));
      playbackSignalTracker.onTrackStarted(track);
    } catch (e) {
      debugPrint('[ForYouFeed] Failed to play index $index: $e');
    }

    unawaited(_preloadIndex(index + 1));
    unawaited(_preloadIndex(index + 2));
    unawaited(_maybeLoadMore());
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
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryLight)),
      );
    }

    if (_items.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: AppColors.textSubtle),
              const SizedBox(height: 12),
              const Text('Could not load recommendations',
                  style: TextStyle(color: AppColors.textMuted)),
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
        itemBuilder: (context, index) => RepaintBoundary(
          child: _ForYouCard(
            track: _items[index],
            isActive: index == _currentIndex,
            onNotInterested: () => _handleNotInterested(index),
          ),
        ),
      ),
    );
  }

  void _handleNotInterested(int index) {
    final artist = _items[index]['artist'] as String? ?? '';
    forYouFeedService.markNotInterested(artist);
    playbackSignalTracker.onTrackEnded(completed: false);
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
    final trackId = track['id'] as String? ?? '';

    return GestureDetector(
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
          // Blurred background
          AppImage(artwork, fit: BoxFit.cover),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(color: Colors.black.withValues(alpha: 0.45)),
          ),

          // Foreground Content
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
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 36,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: AppImage(
                      artwork,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(24),
                      errorIconColor: AppColors.primaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  artist,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<PlayerState>(
                  stream: audioPlayer.playerStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return AnimatedSwitcher(
                      duration: AppMotion.micro,
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Icon(
                        playing ? Icons.volume_up_rounded : Icons.pause_circle_outline,
                        key: ValueKey(playing),
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 24,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 36),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: StreamBuilder<Duration>(
                    stream: audioPlayer.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = audioPlayer.duration ?? Duration.zero;
                      final progress = duration.inMilliseconds > 0
                          ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                          : 0.0;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation(AppColors.primaryLight),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Right Side Action Buttons
          Positioned(
            right: 16,
            bottom: 220,
            child: StatefulBuilder(
              builder: (context, setLikeState) {
                final isLiked = LocalLibrary.instance.isLiked(trackId);
                return IconButton(
                  icon: LikePop(
                    liked: isLiked,
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? AppColors.hotPink : Colors.white,
                      size: 32,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final wasLiked = isLiked;
                    LocalLibrary.instance.toggleLiked(track).then((_) {
                      if (wasLiked) {
                        playbackSignalTracker.onUnliked(track);
                      } else {
                        playbackSignalTracker.onLiked(track);
                      }
                      setLikeState(() {});
                    });
                  },
                );
              },
            ),
          ),

          // Comments Sheet Button
          Positioned(
            right: 16,
            bottom: 165,
            child: IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 28),
              onPressed: () {
                HapticFeedback.lightImpact();
                CommentSheet.show(context, shotId: trackId, commentCount: 18);
              },
            ),
          ),

          // More Options Sheet
          Positioned(
            right: 16,
            bottom: 110,
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

          // Add to Playlist
          Positioned(
            right: 16,
            bottom: 55,
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

// ═════════════════════════════════════════════════════════════════════════════
// V Shots — "For You" Discover Feed (Reels-Style Swipe Playback & Vibe Picker)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/motion/motion.dart';
import '../../core/recommendation/feed_intent.dart';
import '../../core/storage/local_library.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_image.dart';
import '../../shared/widgets/comment_sheet.dart';
import 'for_you_feed_service.dart';
import '../../main.dart'
    show
        currentTrack,
        currentTrackNotifier,
        currentQueue,
        currentQueueIndex,
        forYouFeedService,
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

  int _currentIndex = 0;
  bool _isLoadingMore = false;
  bool _initialLoading = true;
  String _currentVibeLabel = 'Trending Hits';

  YoutubePlayerController? _feedYtController;
  String? _activeVideoId;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _currentVibeLabel = forYouFeedService.activeMood ?? 'Trending Hits';
    _loadInitialBatch();
  }

  @override
  void dispose() {
    _feedYtController?.close();
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
      _initOrLoadVideo(_items[0]['id'] as String? ?? 'kJQP7kiw5Fk');
    }
  }

  void _initOrLoadVideo(String videoId) {
    if (!mounted) return;
    try {
      if (_feedYtController == null) {
        _feedYtController = YoutubePlayerController.fromVideoId(
          videoId: videoId,
          autoPlay: true,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: false,
            mute: false,
            loop: true,
            enableCaption: false,
            showVideoAnnotations: false,
          ),
        );
        _activeVideoId = videoId;
        _isPlaying = true;
      } else if (_activeVideoId != videoId) {
        unawaited(_feedYtController!.loadVideoById(videoId: videoId));
        _activeVideoId = videoId;
        _isPlaying = true;
      }
    } catch (_) {
      // Graceful in headless widget test environments
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDiscoverBatch() async {
    try {
      if (forYouFeedService.activeMoodQuery == null) {
        final scored = await recommendationEngine.generateFeed(
          intent: FeedIntent.discoverSomethingNew,
          excludeIds: _seenIds,
          count: 12,
        );
        if (scored.isNotEmpty) {
          return scored.map((s) => s.track.toTrackMap()).toList();
        }
      }
    } catch (e) {
      debugPrint('[ForYouFeed] Engine discover batch failed, falling back: $e');
    }
    return forYouFeedService.fetchNextBatch(excludeIds: _seenIds, count: 12);
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

  void _onPageChanged(int index) {
    if (index < 0 || index >= _items.length) return;
    unawaited(HapticFeedback.selectionClick());
    final track = _items[index];
    setState(() => _currentIndex = index);

    currentTrack = track;
    currentTrackNotifier.value = track;
    currentQueue = List<Map<String, dynamic>>.from(_items);
    currentQueueIndex = index;

    final videoId = track['id'] as String? ?? 'kJQP7kiw5Fk';
    _initOrLoadVideo(videoId);

    unawaited(LocalLibrary.instance.recordRecentlyPlayed(track));
    playbackSignalTracker.onTrackStarted(track);
    unawaited(_maybeLoadMore());
  }

  void _showMoodPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MoodPickerSheet(
        currentMood: _currentVibeLabel,
        onMoodSelected: (label, query) {
          Navigator.pop(ctx);
          setState(() {
            _currentVibeLabel = label;
            _initialLoading = true;
            _items.clear();
            _seenIds.clear();
            _currentIndex = 0;
          });
          forYouFeedService.setMood(label, query);
          _loadInitialBatch();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryLight),
        ),
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
              const Text(
                'Could not load recommendations',
                style: TextStyle(color: AppColors.textMuted),
              ),
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
      body: Stack(
        children: [
          // Vertical Reel-Style Swipe PageView
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            itemCount: _items.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final isCurrent = index == _currentIndex;
              return RepaintBoundary(
                child: _ForYouCard(
                  track: _items[index],
                  isActive: isCurrent,
                  playerController: isCurrent ? _feedYtController : null,
                  isPlaying: _isPlaying,
                  onPlayPauseToggle: () {
                    if (_feedYtController != null) {
                      if (_isPlaying) {
                        unawaited(_feedYtController!.pauseVideo());
                      } else {
                        unawaited(_feedYtController!.playVideo());
                      }
                      setState(() => _isPlaying = !_isPlaying);
                    }
                  },
                  onNotInterested: () => _handleNotInterested(index),
                  onSkipPrevious: index > 0
                      ? () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        )
                      : null,
                  onSkipNext: index < _items.length - 1
                      ? () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        )
                      : null,
                ),
              );
            },
          ),

          // Top Floating Mood & Vibe Selector Pill
          Positioned(
            top: 50,
            left: 20,
            child: SafeArea(
              child: GestureDetector(
                onTap: _showMoodPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        color: AppColors.accent,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _currentVibeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.accent,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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

class _MoodPickerSheet extends StatelessWidget {
  const _MoodPickerSheet({
    required this.currentMood,
    required this.onMoodSelected,
  });

  final String currentMood;
  final void Function(String label, String query) onMoodSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Your Vibe',
                      style: TextStyle(
                        color: AppColors.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Discover tracks tailored to your current mood',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ForYouFeedService.availableMoods.map((m) {
                    final isSelected = m['label'] == currentMood;
                    return GestureDetector(
                      onTap: () => onMoodSelected(m['label']!, m['query']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? AppColors.primaryGradient
                              : null,
                          color: isSelected ? null : AppColors.surface2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : AppColors.border,
                            width: 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              m['icon'] ?? '🎵',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              m['label'] ?? '',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textMain,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ForYouCard extends StatelessWidget {
  const _ForYouCard({
    required this.track,
    required this.isActive,
    required this.playerController,
    required this.isPlaying,
    required this.onPlayPauseToggle,
    required this.onNotInterested,
    this.onSkipPrevious,
    this.onSkipNext,
  });

  final Map<String, dynamic> track;
  final bool isActive;
  final YoutubePlayerController? playerController;
  final bool isPlaying;
  final VoidCallback onPlayPauseToggle;
  final VoidCallback onNotInterested;
  final VoidCallback? onSkipPrevious;
  final VoidCallback? onSkipNext;

  @override
  Widget build(BuildContext context) {
    final artwork = track['artwork'] as String?;
    final title = (track['title'] as String?) ?? '';
    final artist = (track['artist'] as String?) ?? '';
    final trackId = track['id'] as String? ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Artwork Blur
        AppImage(artwork, fit: BoxFit.cover),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),

        // Centered Content Layout
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Centered In-Card YouTube Player / Artwork
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 340),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 36,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: isActive && playerController != null
                            ? YoutubePlayer(
                                controller: playerController!,
                                aspectRatio: 16 / 9,
                              )
                            : AppImage(artwork, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Centered Title
                  Text(
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
                  const SizedBox(height: 4),

                  // Centered Artist
                  Text(
                    artist,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Attribution Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_circle_filled_rounded,
                          size: 14,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Powered by YouTube',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Playback Controls Row: Prev, Play/Pause Toggle, Next
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.skip_previous_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                        onPressed: onSkipPrevious,
                      ),
                      const SizedBox(width: 16),

                      // In-Card Play/Pause Toggle
                      GestureDetector(
                        onTap: onPlayPauseToggle,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                        onPressed: onSkipNext,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Right Side Action Buttons (Like, Comments, Playlist, More)
        Positioned(
          right: 16,
          bottom: 110,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatefulBuilder(
                builder: (context, setLikeState) {
                  final isLiked = LocalLibrary.instance.isLiked(trackId);
                  return IconButton(
                    icon: LikePop(
                      liked: isLiked,
                      child: Icon(
                        isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isLiked ? AppColors.hotPink : Colors.white,
                        size: 32,
                      ),
                    ),
                    onPressed: () {
                      unawaited(HapticFeedback.lightImpact());
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
              const SizedBox(height: 12),
              IconButton(
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  unawaited(HapticFeedback.lightImpact());
                  CommentSheet.show(context, shotId: trackId, commentCount: 18);
                },
              ),
              const SizedBox(height: 12),
              IconButton(
                icon: const Icon(
                  Icons.playlist_add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () {
                  unawaited(HapticFeedback.lightImpact());
                  showAddToPlaylistSheet(context, track);
                },
              ),
              const SizedBox(height: 12),
              IconButton(
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () {
                  unawaited(HapticFeedback.lightImpact());
                  showMoreOptionsSheet(
                    context,
                    track,
                    onNotInterested: onNotInterested,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

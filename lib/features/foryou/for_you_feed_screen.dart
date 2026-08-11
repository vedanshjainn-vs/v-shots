// ═════════════════════════════════════════════════════════════════════════════
// V Shots — "For You" Discover Feed (Reels-Style Swipe Playback & Vibe Picker)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';

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
        currentTabIndexNotifier,
        ensureGlobalPlayer,
        forYouFeedService,
        globalYtController,
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

  String? _activeVideoId;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _currentVibeLabel = forYouFeedService.activeMood ?? 'Trending Hits';
    // Rebuild when the user switches to/from the Discover tab so the active
    // card correctly (re)attaches the single global IFrame.
    currentTabIndexNotifier.addListener(_onTabChanged);
    _loadInitialBatch();
  }

  void _onTabChanged() {
    if (!mounted) return;
    setState(() {});
    // When the user returns to the Discover tab, if the current video is cued
    // but not playing, start it (gesture-initiated, so permitted to autoplay).
    if (_onDiscoverTab && !_isPlaying && _items.isNotEmpty) {
      final videoId =
          _activeVideoId ?? (_items[_currentIndex]['id'] as String? ?? '');
      if (videoId.isNotEmpty) {
        ensureGlobalPlayer(videoId: videoId, autoPlay: true);
        _isPlaying = true;
      }
    }
  }

  @override
  void dispose() {
    currentTabIndexNotifier.removeListener(_onTabChanged);
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

  /// Plays through the SINGLE global YouTube engine. The swipe/page-change is
  /// a user gesture, so loading + playing the next video here is gesture-
  /// initiated and therefore permitted by Android/YouTube autoplay policies.
  /// Loading a different [videoId] into the same engine stops the previous
  /// video in-place — no second playback engine is ever created.
  void _initOrLoadVideo(String videoId) {
    if (!mounted) return;
    try {
      if (_activeVideoId == videoId && globalYtController != null) {
        // Already current — (re)start it (only when Discover is foreground).
        if (_onDiscoverTab) {
          unawaited(globalYtController!.playVideo());
          _isPlaying = true;
        }
        return;
      }
      // Autoplay only when the Discover tab is actually in the foreground —
      // IndexedStack builds every tab at startup, so we must NOT start audio
      // while the user is on Home/Search/Profile.
      ensureGlobalPlayer(videoId: videoId, autoPlay: _onDiscoverTab);
      _activeVideoId = videoId;
      _isPlaying = _onDiscoverTab;
    } catch (_) {
      // Graceful in headless widget test environments
    }
  }

  void _togglePlayPause() {
    if (globalYtController == null) return;
    if (_isPlaying) {
      unawaited(globalYtController!.pauseVideo());
      _isPlaying = false;
    } else {
      final videoId = _activeVideoId ??
          (_items.isNotEmpty
              ? (_items[_currentIndex]['id'] as String? ?? '')
              : '');
      if (videoId.isNotEmpty) {
        ensureGlobalPlayer(videoId: videoId, autoPlay: true);
      }
      _isPlaying = true;
    }
    setState(() {});
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

  bool get _onDiscoverTab => currentTabIndexNotifier.value == 1;

  /// The single always-mounted YouTube player used as the full-screen
  /// background of the Discover feed. It is mounted in a FIXED position (not
  /// inside any PageView card) so the WebView is never torn down on swipe;
  /// swiping simply loads the next video into this same controller.
  Widget _buildBackgroundPlayer() {
    final controller = globalYtController;
    if (controller == null) {
      // No controller yet — fall back to the current track's artwork until the
      // first video is created.
      final artwork = (_items.isNotEmpty
          ? (_items[_currentIndex]['artwork'] as String?)
          : null);
      return Container(
        color: Colors.black,
        child: artwork != null ? AppImage(artwork, fit: BoxFit.cover) : null,
      );
    }
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: YoutubePlayer(
              controller: controller,
              aspectRatio: 16 / 9,
            ),
          ),
        ),
      ),
    );
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
        fit: StackFit.expand,
        children: [
          // 1. Single ALWAYS-MOUNTED YouTube player (background layer).
          //
          // The player is rendered ONCE at a fixed position and never moves
          // between cards. Swiping only calls loadVideoById on the same
          // controller, which is what makes video switching + autoplay reliable.
          // (Rendering the player inside each PageView card re-created the
          // WebView on every swipe, which is what made the video appear stuck
          // on the first song and stop playing.)
          if (_onDiscoverTab) _buildBackgroundPlayer(),

          // 2. Vertical Reel-Style Swipe PageView (transparent metadata overlay
          // on top of the always-mounted player).
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
                  isPlaying: _isPlaying,
                  onPlayPauseToggle: _togglePlayPause,
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
                          gradient:
                              isSelected ? AppColors.primaryGradient : null,
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
    required this.isPlaying,
    required this.onPlayPauseToggle,
    required this.onNotInterested,
    this.onSkipPrevious,
    this.onSkipNext,
  });

  final Map<String, dynamic> track;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onPlayPauseToggle;
  final VoidCallback onNotInterested;
  final VoidCallback? onSkipPrevious;
  final VoidCallback? onSkipNext;

  @override
  Widget build(BuildContext context) {
    final title = (track['title'] as String?) ?? '';
    final artist = (track['artist'] as String?) ?? '';
    final trackId = track['id'] as String? ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Transparent metadata overlay — the always-mounted background player
        // (single WebView) shows the actual video behind this card. A subtle
        // scrim keeps text readable over bright video frames.
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.30),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.60),
                ],
                stops: const [0.0, 0.35, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // Clear Play interaction over the video when the active video is cued
        // but not yet playing (YouTube/Android can block autoplay-with-sound).
        // First tap starts playback.
        if (isActive && !isPlaying)
          GestureDetector(
            onTap: onPlayPauseToggle,
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.5),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),
            ),
          ),

        // Bottom metadata + play controls
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  Text(
                    artist,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

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
                      const SizedBox(width: 20),

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
                      const SizedBox(width: 20),

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
          bottom: 150,
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

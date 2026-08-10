// ═════════════════════════════════════════════════════════════════════════════
// V Shots — "For You" Discover Feed (Official YouTube Discovery & Vibe Picker)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        playTrack,
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

  @override
  void initState() {
    super.initState();
    _currentVibeLabel = forYouFeedService.activeMood ?? 'Trending Hits';
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
  }

  Future<List<Map<String, dynamic>>> _fetchDiscoverBatch() async {
    try {
      if (forYouFeedService.activeMoodQuery == null) {
        final scored = await recommendationEngine.generateFeed(
          intent: FeedIntent.discoverSomethingNew,
          excludeIds: _seenIds,
          count: 8,
        );
        if (scored.isNotEmpty) {
          return scored.map((s) => s.track.toTrackMap()).toList();
        }
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

  void _onTrackSelected(int index) {
    if (index < 0 || index >= _items.length) return;
    final track = _items[index];
    setState(() => _currentIndex = index);

    currentTrack = track;
    currentTrackNotifier.value = track;
    currentQueue = List<Map<String, dynamic>>.from(_items);
    currentQueueIndex = index;

    playTrack(context, track, _items, index);
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
          // Vertical swipe PageView
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            itemCount: _items.length,
            onPageChanged: (index) {
              unawaited(HapticFeedback.selectionClick());
              setState(() => _currentIndex = index);
              unawaited(_maybeLoadMore());
            },
            itemBuilder: (context, index) => RepaintBoundary(
              child: _ForYouCard(
                track: _items[index],
                isActive: index == _currentIndex,
                onPlayTap: () => _onTrackSelected(index),
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
            ),
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
                    color: Colors.black.withValues(alpha: 0.6),
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
            // Handle bar
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
            Wrap(
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
                      gradient: isSelected ? AppColors.primaryGradient : null,
                      color: isSelected ? null : AppColors.surface2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected ? Colors.transparent : AppColors.border,
                        width: 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
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
                            color:
                                isSelected ? Colors.white : AppColors.textMain,
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
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
    required this.onPlayTap,
    required this.onNotInterested,
    this.onSkipPrevious,
    this.onSkipNext,
  });

  final Map<String, dynamic> track;
  final bool isActive;
  final VoidCallback onPlayTap;
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
        // Blurred background
        AppImage(artwork, fit: BoxFit.cover),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(color: Colors.black.withValues(alpha: 0.55)),
        ),

        // Centered Content Layout
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Centered Large Artwork
                  GestureDetector(
                    onTap: onPlayTap,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AppImage(
                            artwork,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(24),
                            errorIconColor: AppColors.primaryLight,
                          ),
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.5),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Centered Title
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Centered Artist
                  Text(
                    artist,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Official YouTube Attribution Badge
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
                  const SizedBox(height: 24),

                  // Playback Controls Row: Prev, Play/Open, Next
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Previous Track
                      IconButton(
                        icon: const Icon(
                          Icons.skip_previous_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                        onPressed: onSkipPrevious,
                      ),
                      const SizedBox(width: 16),

                      // Large Play/Open Toggle
                      GestureDetector(
                        onTap: onPlayTap,
                        child: Container(
                          width: 68,
                          height: 68,
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
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Next Track
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                          size: 36,
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
          bottom: 120,
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
                        isLiked ? Icons.favorite : Icons.favorite_border,
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
                  Icons.playlist_add,
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
                  Icons.more_horiz,
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

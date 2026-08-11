// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Diagnostic Playback & Hybrid Streaming Engine (Nova Edition)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'core/audio/vshots_audio_handler.dart';
import 'core/backend/auth_service.dart';
import 'core/backend/supabase_service.dart';
import 'core/cache/search_cache.dart';
import 'core/lyrics/lyrics_service.dart';
import 'core/models/profile_model.dart';
import 'core/motion/motion.dart';
import 'core/player/queue_controller.dart';
import 'core/player/repeat_mode.dart';
import 'core/player/sleep_timer.dart';
import 'core/providers/adapters/youtube/youtube_data_api_client.dart';
import 'core/providers/provider_bootstrap.dart';
import 'core/recommendation/feed_intent.dart';
import 'core/recommendation/recommendation_engine.dart';
import 'core/recommendation/recommendation_service.dart';
import 'core/recommendation/signal_recorder.dart';
import 'core/recommendation/signal_store.dart';
import 'core/services/profile_service.dart';
import 'core/theme/app_colors.dart';
import 'shared/widgets/animated_equalizer.dart';
import 'shared/widgets/app_avatar.dart';
import 'shared/widgets/app_button.dart';
import 'shared/widgets/app_image.dart';
import 'shared/widgets/bottom_tab_bar.dart';
import 'core/storage/local_library.dart';
import 'features/auth/auth_modal.dart';
import 'features/foryou/for_you_feed_screen.dart';
import 'features/foryou/for_you_feed_service.dart';
import 'features/library/local_import_service.dart';
import 'features/profile/artist_details_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/profile/settings_screen.dart';
import 'features/shots/upload_shot_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    SupabaseService.initialize(),
    LocalLibrary.instance.initialize(),
    SignalStore.instance.initialize(),
  ]);

  await AuthService.instance.initializeGoogleSignIn();

  audioHandler = await AudioService.init(
    builder: () => VShotsAudioHandler(audioPlayer),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.vshots.live.channel.audio',
      androidNotificationChannelName: 'V Shots playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const VShotsApp());
}

// ═══════════════════════════════════════════════
// APP ROOT
// ═══════════════════════════════════════════════

class VShotsApp extends StatelessWidget {
  const VShotsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V Shots',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: AppColors.accent,
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const SplashScreen(),
    );
  }
}

// ═══════════════════════════════════════════════
// GLOBAL STATE & PERSISTENT AUDIO ENGINE
// ═══════════════════════════════════════════════

final AudioPlayer audioPlayer = AudioPlayer();
VShotsAudioHandler? audioHandler;
List<Map<String, dynamic>> currentQueue = [];
int currentQueueIndex = 0;
Map<String, dynamic>? currentTrack;

final ValueNotifier<Map<String, dynamic>?> currentTrackNotifier =
    ValueNotifier<Map<String, dynamic>?>(null);

final ValueNotifier<bool> isPlayerExpandedNotifier = ValueNotifier<bool>(false);

YoutubePlayerController? globalYtController;
String? globalPlayingVideoId;

bool isCurrentlyPlaying = false;
RepeatMode repeatMode = RepeatMode.off;
bool isShuffleOn = false;
List<int> shuffleOrder = [];

final YouTubeDataApiClient sharedYtApiClient = YouTubeDataApiClient();
final musicRepository = buildMusicRepository(apiClient: sharedYtApiClient);
final forYouFeedService = ForYouFeedService(musicRepository);
final recommendationEngine = RecommendationEngine(musicRepository);
final playbackSignalTracker = PlaybackSignalTracker(recommendationEngine);

void _log(String message) {
  debugPrint('[VShots] $message');
}

/// Plays the next/previous track in the current global queue.
Future<void> _playAdjacentInQueue(BuildContext? context, int delta) async {
  if (currentQueue.isEmpty) return;
  if (isShuffleOn && shuffleOrder.length != currentQueue.length) {
    QueueController.rebuildShuffleOrder(keepCurrentAt: currentQueueIndex);
  }
  final nextIndex = QueueController.computeSkip(
    queueLength: currentQueue.length,
    currentIndex: currentQueueIndex,
    delta: delta,
    shuffleOn: isShuffleOn,
    order: shuffleOrder,
  );
  final nextTrack = currentQueue[nextIndex];
  await playTrack(context, nextTrack, currentQueue, nextIndex);
}

void _handleTrackCompleted(BuildContext? context) {
  _log('[QUEUE] Track natural completion received');
  playbackSignalTracker.onTrackEnded(completed: true);
  if (currentQueue.isEmpty) return;

  if (repeatMode == RepeatMode.one) {
    _log('[QUEUE] RepeatMode.one — replaying current track');
    final current = currentQueue[currentQueueIndex];
    playTrack(context, current, currentQueue, currentQueueIndex);
    return;
  }

  if (isShuffleOn && shuffleOrder.length != currentQueue.length) {
    QueueController.rebuildShuffleOrder(keepCurrentAt: currentQueueIndex);
  }

  final nextIndex = QueueController.computeCompletion(
    queueLength: currentQueue.length,
    currentIndex: currentQueueIndex,
    repeatMode: repeatMode,
    shuffleOn: isShuffleOn,
    order: shuffleOrder,
  );

  if (nextIndex == null) {
    _log('[QUEUE] End of queue reached, playback stopped');
    return;
  }

  _log('[QUEUE] Auto-advancing to queue index $nextIndex');
  final nextTrack = currentQueue[nextIndex];
  playTrack(context, nextTrack, currentQueue, nextIndex);
}

MediaItem _trackToMediaItem(Map<String, dynamic> track) => MediaItem(
  id: (track['id'] as String?) ?? '',
  title: (track['title'] as String?) ?? 'Unknown title',
  artist: (track['artist'] as String?) ?? 'Unknown artist',
  artUri: (track['artwork'] as String?) != null
      ? Uri.tryParse(track['artwork'] as String)
      : null,
);

// ═══════════════════════════════════════════════
// SPLASH SCREEN
// ═══════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _c.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const MainShell()),
        );
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _c,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'V Shots',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Official YouTube Music & Video',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// MAIN SHELL & PERSISTENT APP OVERLAY
// ═══════════════════════════════════════════════

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    audioPlayer.playerStateStream.listen((state) {
      isCurrentlyPlaying = state.playing;
    });

    audioHandler?.onSkipNext = () => _playAdjacentInQueue(context, 1);
    audioHandler?.onSkipPrevious = () => _playAdjacentInQueue(context, -1);
    audioHandler?.onTrackCompleted = () => _handleTrackCompleted(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 4 Clean Tabs (Home, Discover, Search, Profile)
          IndexedStack(
            index: _index.clamp(0, 3),
            children: const [
              HomeScreen(),
              ForYouFeedScreen(),
              SearchScreen(),
              ProfileScreen(),
            ],
          ),

          // Persistent Overlay: Dual-State Player (Full screen & Mini-Player)
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: currentTrackNotifier,
            builder: (context, track, _) {
              if (track == null) return const SizedBox.shrink();
              return ValueListenableBuilder<bool>(
                valueListenable: isPlayerExpandedNotifier,
                builder: (context, isExpanded, _) {
                  return _PersistentPlayerOverlay(
                    track: track,
                    isExpanded: isExpanded,
                    onToggleExpand: (val) {
                      isPlayerExpandedNotifier.value = val;
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: isPlayerExpandedNotifier,
        builder: (context, isExpanded, _) {
          if (isExpanded) return const SizedBox.shrink();
          return BottomTabBar(
            currentIndex: _index.clamp(0, 3),
            onTap: (i) {
              setState(() => _index = i.clamp(0, 3));
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// PERSISTENT PLAYER OVERLAY (FULL & MINI RESIZE)
// ═══════════════════════════════════════════════

class _PersistentPlayerOverlay extends StatefulWidget {
  const _PersistentPlayerOverlay({
    required this.track,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  final Map<String, dynamic> track;
  final bool isExpanded;
  final ValueChanged<bool> onToggleExpand;

  @override
  State<_PersistentPlayerOverlay> createState() =>
      _PersistentPlayerOverlayState();
}

class _PersistentPlayerOverlayState extends State<_PersistentPlayerOverlay> {
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _isLiked = LocalLibrary.instance.isLiked(
      widget.track['id'] as String? ?? '',
    );
    LocalLibrary.instance.likedSongs.addListener(_onLikedChange);
  }

  @override
  void didUpdateWidget(covariant _PersistentPlayerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track['id'] != widget.track['id']) {
      setState(() {
        _isLiked = LocalLibrary.instance.isLiked(
          widget.track['id'] as String? ?? '',
        );
      });
    }
  }

  @override
  void dispose() {
    LocalLibrary.instance.likedSongs.removeListener(_onLikedChange);
    super.dispose();
  }

  void _onLikedChange() {
    if (mounted) {
      setState(() {
        _isLiked = LocalLibrary.instance.isLiked(
          widget.track['id'] as String? ?? '',
        );
      });
    }
  }

  void _toggleLiked() async {
    unawaited(HapticFeedback.lightImpact());
    final wasLiked = _isLiked;
    await LocalLibrary.instance.toggleLiked(widget.track);
    if (wasLiked) {
      playbackSignalTracker.onUnliked(widget.track);
    } else {
      playbackSignalTracker.onLiked(widget.track);
    }
    if (mounted) {
      setState(() {
        _isLiked = LocalLibrary.instance.isLiked(
          widget.track['id'] as String? ?? '',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackId = widget.track['id'] as String? ?? '';
    final title = widget.track['title'] as String? ?? '';
    final artist = widget.track['artist'] as String? ?? '';
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;

    if (!widget.isExpanded) {
      // ── MINI PLAYER DOCK VIEW ───────────────────────────────────────────
      return Positioned(
        left: 8,
        right: 8,
        bottom: 64,
        child: GestureDetector(
          onTap: () => widget.onToggleExpand(true),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 96,
                    height: 54,
                    child: globalYtController != null
                        ? YoutubePlayer(
                            controller: globalYtController!,
                            aspectRatio: 16 / 9,
                          )
                        : AppImage(
                            widget.track['artwork'] as String?,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.play_circle_filled_rounded,
                            size: 11,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.open_in_full_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                  tooltip: 'Full Player',
                  onPressed: () => widget.onToggleExpand(true),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.skip_next_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  onPressed: () => _playAdjacentInQueue(context, 1),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      );
    }

    // ── FULLSCREEN EXPANDED PLAYER VIEW ─────────────────────────────────
    return Positioned.fill(
      child: Material(
        color: AppColors.background,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.accent.withValues(alpha: 0.12),
                AppColors.background,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top Bar with Minimize Action
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 32,
                        ),
                        onPressed: () => widget.onToggleExpand(false),
                      ),
                      Column(
                        children: [
                          Text(
                            'PLAYING FROM',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            'Official YouTube Player',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded),
                        onPressed: () =>
                            showMoreOptionsSheet(context, widget.track),
                      ),
                    ],
                  ),
                ),

                // Large 16:9 Visible YouTube Player
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: globalYtController != null
                          ? YoutubePlayer(
                              controller: globalYtController!,
                              aspectRatio: 16 / 9,
                            )
                          : const SizedBox(height: 200),
                    ),
                  ),
                ),

                // Attribution Badge
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.play_circle_filled_rounded,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Powered by YouTube',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse('https://www.youtube.com/t/terms'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text(
                          'YouTube Terms',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSubtle,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Track Title & Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              artist,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: LikePop(
                          liked: _isLiked,
                          child: Icon(
                            _isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 28,
                            color: _isLiked
                                ? AppColors.hotPink
                                : Colors.white70,
                          ),
                        ),
                        onPressed: _toggleLiked,
                      ),
                      IconButton(
                        icon: const Icon(Icons.playlist_add_rounded, size: 26),
                        tooltip: 'Add to playlist',
                        onPressed: () =>
                            showAddToPlaylistSheet(context, widget.track),
                      ),
                      IconButton(
                        icon: const Icon(Icons.lyrics_outlined, size: 24),
                        tooltip: 'Lyrics',
                        onPressed: () => Navigator.push(
                          context,
                          AppPageRoute<void>(
                            builder: (_) => LyricsScreen(track: widget.track),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_rounded, size: 22),
                        tooltip: 'Share',
                        onPressed: () {
                          SharePlus.instance.share(
                            ShareParams(
                              text:
                                  'Listen to $title on V Shots! https://www.youtube.com/watch?v=$trackId',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Controls Row (Prev / Shuffle / Next)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded, size: 34),
                        color: Colors.white,
                        onPressed: () => _playAdjacentInQueue(context, -1),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: Icon(
                          isShuffleOn
                              ? Icons.shuffle_on_rounded
                              : Icons.shuffle_rounded,
                          size: 22,
                          color: isShuffleOn
                              ? AppColors.accent
                              : Colors.white60,
                        ),
                        onPressed: () {
                          setState(() {
                            isShuffleOn = !isShuffleOn;
                            if (isShuffleOn) {
                              QueueController.rebuildShuffleOrder(
                                keepCurrentAt: currentQueueIndex,
                              );
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, size: 34),
                        color: Colors.white,
                        onPressed: () => _playAdjacentInQueue(context, 1),
                      ),
                    ],
                  ),
                ),

                const Divider(color: AppColors.borderSubtle, height: 1),

                // Up Next Queue Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Up Next in Queue',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                      ),
                      Text(
                        '${currentQueue.length} tracks',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Queue List
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding + 16),
                    itemCount: currentQueue.length,
                    itemBuilder: (context, index) {
                      final item = currentQueue[index];
                      final isSelected = index == currentQueueIndex;
                      final itemArtwork = item['artwork'] as String?;
                      final itemTitle = (item['title'] as String?) ?? '';
                      final itemArtist = (item['artist'] as String?) ?? '';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: isSelected
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AppImage(
                            itemArtwork,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(
                          itemTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.textMain,
                          ),
                        ),
                        subtitle: Text(
                          itemArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        trailing: isSelected
                            ? const AnimatedEqualizer(
                                isPlaying: true,
                                color: AppColors.accent,
                                size: 16,
                              )
                            : const Icon(
                                Icons.play_arrow_rounded,
                                color: AppColors.textSubtle,
                                size: 20,
                              ),
                        onTap: () {
                          playTrack(context, item, currentQueue, index);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// CREATOR GATING & UPLOAD FLOW
// ═══════════════════════════════════════════════

Future<void> _handleCreatorUpload(BuildContext context) async {
  unawaited(HapticFeedback.selectionClick());
  final profile = await ProfileService.instance.getCurrentProfile();
  final isCreator = profile.isCreator;
  if (!context.mounted) return;
  if (isCreator) {
    unawaited(
      Navigator.push(
        context,
        AppPageRoute<void>(builder: (_) => const UploadShotScreen()),
      ),
    );
  } else {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => const _CreatorGatingSheet(),
      ),
    );
  }
}

class _CreatorGatingSheet extends StatelessWidget {
  const _CreatorGatingSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Creator Upload — Limited Access',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMain,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Creator uploads are currently limited to verified creators. Request access to upload your original music, audio shots, and videos to V Shots.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              text: 'Request Access',
              icon: Icons.send_rounded,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.large,
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Creator access request submitted! Our team will review your application.',
                    ),
                    backgroundColor: AppColors.accent,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            AppButton(
              text: 'Maybe Later',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.medium,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// OFFICIAL YOUTUBE PLAYBACK PIPELINE
// ═══════════════════════════════════════════════

Future<void> playTrack(
  BuildContext? context,
  Map<String, dynamic> track,
  List<Map<String, dynamic>> queue,
  int index,
) async {
  _log('═══ PLAYBACK START ═══');
  _log('Track: ${track['title']} (${track['id']})');
  unawaited(HapticFeedback.selectionClick());

  currentTrack = track;
  currentTrackNotifier.value = track;
  currentQueue = queue;
  currentQueueIndex = index;

  final videoId = (track['id'] as String?) ?? 'kJQP7kiw5Fk';
  if (globalYtController == null) {
    globalYtController = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
        loop: false,
        enableCaption: false,
        showVideoAnnotations: false,
      ),
    );
    globalPlayingVideoId = videoId;
  } else if (globalPlayingVideoId != videoId) {
    globalYtController!.loadVideoById(videoId: videoId);
    globalPlayingVideoId = videoId;
  }

  isPlayerExpandedNotifier.value = true;
  unawaited(LocalLibrary.instance.recordRecentlyPlayed(track));
  playbackSignalTracker.onTrackStarted(track);
}

// ═══════════════════════════════════════════════
// HOME SCREEN (AUTO-REFRESH & DATA-DRIVEN)
// ═══════════════════════════════════════════════

enum _SectionStatus { loading, loaded, error }

class _HomeSectionState {
  _HomeSectionState({
    required this.query,
    required this.title,
    this.order = 'relevance',
    this.isPersonalized = false,
    this.isBecauseListened = false,
    this.intent,
  });

  final String query;
  final String title;
  final String order;
  final bool isPersonalized;
  final bool isBecauseListened;
  final FeedIntent? intent;
  _SectionStatus status = _SectionStatus.loading;
  List<Map<String, dynamic>> tracks = [];
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final Set<String> _activeFetches = <String>{};
  Timer? _autoRefreshTimer;

  static const List<Map<String, String>> _officialArtists = [
    {
      'name': 'Arijit Singh',
      'role': 'Singer & Composer',
      'image':
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&q=80',
      'query': 'Arijit Singh top hit songs official audio',
    },
    {
      'name': 'Diljit Dosanjh',
      'role': 'Punjabi Pop Icon',
      'image':
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&q=80',
      'query': 'Diljit Dosanjh hit songs official audio',
    },
    {
      'name': 'Karan Aujla',
      'role': 'Desi Hip-Hop',
      'image':
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&q=80',
      'query': 'Karan Aujla new songs official audio',
    },
    {
      'name': 'Shreya Ghoshal',
      'role': 'Melody Queen',
      'image':
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&q=80',
      'query': 'Shreya Ghoshal romantic hit songs official audio',
    },
    {
      'name': 'Anuv Jain',
      'role': 'Acoustic / Indie',
      'image':
          'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=400&q=80',
      'query': 'Anuv Jain songs official audio',
    },
    {
      'name': 'AP Dhillon',
      'role': 'Punjabi Wave',
      'image':
          'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400&q=80',
      'query': 'AP Dhillon hit songs official audio',
    },
    {
      'name': 'Taylor Swift',
      'role': 'Global Pop Icon',
      'image':
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&q=80',
      'query': 'Taylor Swift top songs official audio',
    },
    {
      'name': 'The Weeknd',
      'role': 'R&B / Synthwave',
      'image':
          'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&q=80',
      'query': 'The Weeknd top hits official audio',
    },
  ];

  late final List<_HomeSectionState> _sections = [
    _HomeSectionState(
      query: 'trending songs official music video 2026',
      title: 'Trending Now',
      order: 'viewCount',
    ),
    _HomeSectionState(
      query: 'new music friday official audio 2026',
      title: 'New Releases',
      order: 'date',
    ),
    _HomeSectionState(
      query: '__made_for_you__',
      title: 'Made For You',
      isPersonalized: true,
    ),
    _HomeSectionState(
      query: '__because_you_listened__',
      title: 'Because You Listened To',
      isBecauseListened: true,
    ),
    _HomeSectionState(
      query: 'top bollywood hindi songs official music video',
      title: 'India Hits (Bollywood)',
    ),
    _HomeSectionState(
      query: 'latest punjabi pop hits official audio',
      title: 'Punjabi Bangers',
    ),
    _HomeSectionState(
      query: 'hindi indie acoustic songs official audio',
      title: 'Hindi Indie & Acoustic',
    ),
    _HomeSectionState(
      query: 'billboard top global pop hits official audio',
      title: 'International Pop 100',
    ),
    _HomeSectionState(
      query: 'chill lofi late night beats official audio',
      title: 'Chill & Lofi',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (final section in _sections) {
      unawaited(_loadSection(section));
    }
    // Auto-refresh periodically (every 20 minutes in foreground)
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 20), (_) {
      unawaited(_refreshAll());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAll());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait(
      _sections.map((s) => _loadSection(s, forceRefresh: true)),
    );
  }

  Future<void> _loadSection(
    _HomeSectionState section, {
    bool forceRefresh = false,
  }) async {
    if (_activeFetches.contains(section.query)) return;
    _activeFetches.add(section.query);

    final queryKey = section.isPersonalized
        ? RecommendationService.instance.getPersonalizedHomeQuery()
        : section.isBecauseListened
        ? RecommendationService.instance.getBecauseYouListenedQuery()
        : section.query;

    final cached = forceRefresh ? null : SearchCache.instance.get(queryKey);
    if (cached != null) {
      if (mounted) {
        setState(() {
          section.tracks = cached;
          section.status = _SectionStatus.loaded;
        });
      }
      if (SearchCache.instance.isFresh(queryKey)) {
        _activeFetches.remove(section.query);
        return;
      }
    } else if (mounted) {
      setState(() => section.status = _SectionStatus.loading);
    }

    try {
      final results = await musicRepository.search(
        queryKey,
        order: section.order,
        limit: 15,
      );
      if (!mounted) return;
      if (results.isEmpty && cached == null) {
        setState(() => section.status = _SectionStatus.error);
        return;
      }
      if (results.isNotEmpty) {
        SearchCache.instance.set(queryKey, results);
        setState(() {
          section.tracks = results;
          section.status = _SectionStatus.loaded;
        });
      }
    } catch (_) {
      if (mounted && cached == null) {
        setState(() => section.status = _SectionStatus.error);
      }
    } finally {
      _activeFetches.remove(section.query);
    }
  }

  void _playArtistSpotlight(Map<String, String> artist) {
    unawaited(HapticFeedback.selectionClick());
    Navigator.push(
      context,
      AppPageRoute<void>(
        builder: (_) => ArtistDetailsScreen(
          name: artist['name']!,
          role: artist['role']!,
          imageUrl: artist['image']!,
          query: artist['query']!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        onRefresh: _refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'V Shots',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: () => _handleCreatorUpload(context),
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
                  label: const Text(
                    'Create',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Discover official releases & trending tracks',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildArtistsSpotlightSliver(),
            for (final section in _sections) _buildSectionSliver(section),
            const SliverToBoxAdapter(child: SizedBox(height: 160)),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistsSpotlightSliver() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Icon(Icons.verified_rounded, size: 18, color: AppColors.accent),
                SizedBox(width: 6),
                Text(
                  'Top Artists',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 124,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _officialArtists.length,
              itemBuilder: (context, index) {
                final artist = _officialArtists[index];
                return GestureDetector(
                  onTap: () => _playArtistSpotlight(artist),
                  child: Container(
                    width: 86,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.6),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.25),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: AppImage(
                              artist['image'],
                              fit: BoxFit.cover,
                              errorIconColor: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          artist['name']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                        Text(
                          artist['role']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
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
    );
  }

  Widget _buildSectionSliver(_HomeSectionState section) {
    return SliverToBoxAdapter(
      child: switch (section.status) {
        _SectionStatus.loading => _skeletonContent(section.title),
        _SectionStatus.error => _errorContent(section),
        _SectionStatus.loaded => _tracksContent(section),
      },
    );
  }

  Widget _skeletonContent(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Shimmer.fromColors(
            baseColor: AppColors.surface,
            highlightColor: AppColors.surfaceLight,
            child: Container(
              width: 150,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Shimmer.fromColors(
                baseColor: AppColors.surface,
                highlightColor: AppColors.surfaceLight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorContent(_HomeSectionState section) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Couldn\'t load "${section.title}"',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
            TextButton(
              onPressed: () => _loadSection(section),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tracksContent(_HomeSectionState section) {
    final isPersonalized =
        section.title == 'Made For You' ||
        section.title == 'Because You Listened To';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
          child: Row(
            children: [
              if (isPersonalized) ...[
                const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                section.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: section.tracks.length,
            itemBuilder: (context, i) {
              final track = section.tracks[i];
              return StaggeredEntrance(
                index: i,
                child: PressableScale(
                  onTap: () => playTrack(context, track, section.tracks, i),
                  child: RepaintBoundary(
                    child: Container(
                      width: 150,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AppImage(
                                    (track['artwork'] as String?) ?? '',
                                    fit: BoxFit.cover,
                                    width: 150,
                                    height: 150,
                                    errorIconColor: AppColors.accent,
                                  ),
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child:
                                        ValueListenableBuilder<
                                          Map<String, dynamic>?
                                        >(
                                          valueListenable: currentTrackNotifier,
                                          builder: (context, current, _) {
                                            final isThisPlaying =
                                                current?['id'] == track['id'];
                                            return Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: isThisPlaying
                                                    ? AppColors.primary
                                                    : AppColors.accent,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color:
                                                        (isThisPlaying
                                                                ? AppColors
                                                                      .primary
                                                                : AppColors
                                                                      .accent)
                                                            .withValues(
                                                              alpha: 0.4,
                                                            ),
                                                    blurRadius: 8,
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: isThisPlaying
                                                    ? const AnimatedEqualizer(
                                                        size: 16,
                                                        color: Colors.white,
                                                      )
                                                    : const Icon(
                                                        Icons.play_arrow,
                                                        size: 20,
                                                        color: Colors.white,
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
                          const SizedBox(height: 8),
                          Text(
                            (track['title'] as String?) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            (track['artist'] as String?) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
// SEARCH SCREEN
// ═══════════════════════════════════════════════

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum _SearchStatus { idle, loading, loaded, error }

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  _SearchStatus _status = _SearchStatus.idle;
  String? _lastQuery;
  final _searchFocusNode = FocusNode();
  bool _searchFocused = false;
  Timer? _debounce;
  int _requestSeq = 0;

  static const _categories = [
    ('Bollywood', '🎵', Color(0xFFE91E63)),
    ('Hindi', '🎤', Color(0xFF9C27B0)),
    ('English', '🎸', Color(0xFF2196F3)),
    ('Pop', '🎵', Color(0xFFE91E63)),
    ('Punjabi', '🥁', Color(0xFFFF9800)),
    ('Hip-Hop', '🎤', Color(0xFF673AB7)),
    ('EDM', '🎧', Color(0xFF00BCD4)),
    ('Chill', '😌', Color(0xFF4CAF50)),
    ('Workout', '💪', Color(0xFFFF5722)),
    ('Devotional', '🙏', Color(0xFFFFC107)),
  ];

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _status = _SearchStatus.idle;
        _results = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;

    final cached = SearchCache.instance.get(query);
    final isFresh = SearchCache.instance.isFresh(query);
    if (cached != null) {
      setState(() {
        _results = cached;
        _status = _SearchStatus.loaded;
        _lastQuery = query;
      });
      if (isFresh) return;
    } else {
      setState(() {
        _status = _SearchStatus.loading;
        _lastQuery = query;
      });
    }

    final seq = ++_requestSeq;

    try {
      final detailed = await musicRepository.searchDetailed(query);
      if (seq != _requestSeq || !mounted) return;

      if (!detailed.success) {
        if (cached == null) {
          setState(() => _status = _SearchStatus.error);
        }
        return;
      }

      final seenIds = <String>{};
      final uniqueResults = detailed.tracks.where((track) {
        final id = track['id'] as String? ?? '';
        if (id.isEmpty) return false;
        return seenIds.add(id);
      }).toList();

      SearchCache.instance.set(query, uniqueResults);
      unawaited(LocalLibrary.instance.recordRecentSearch(query));
      playbackSignalTracker.onSearched(query);

      setState(() {
        _results = uniqueResults;
        _status = _SearchStatus.loaded;
      });
    } catch (_) {
      if (seq != _requestSeq || !mounted) return;
      if (cached == null) {
        setState(() => _status = _SearchStatus.error);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocusNode.hasFocus);
    });
    LocalLibrary.instance.recentSearches.addListener(_onRecentSearchesChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocusNode.dispose();
    _controller.dispose();
    LocalLibrary.instance.recentSearches.removeListener(
      _onRecentSearchesChanged,
    );
    super.dispose();
  }

  void _onRecentSearchesChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedContainer(
                duration: AppMotion.short,
                curve: AppMotion.standard,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _searchFocused ? AppColors.accent : AppColors.border,
                    width: _searchFocused ? 1.5 : 1.0,
                  ),
                  boxShadow: _searchFocused
                      ? [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _searchFocusNode,
                  onChanged: _onQueryChanged,
                  onSubmitted: _search,
                  style: const TextStyle(color: AppColors.textMain),
                  decoration: InputDecoration(
                    hintText: 'Search songs, artists, hits...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textMuted,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () {
                              _controller.clear();
                              _onQueryChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_status) {
      _SearchStatus.idle => _buildIdleState(),
      _SearchStatus.loading => _buildLoadingState(),
      _SearchStatus.error => _buildErrorState(),
      _SearchStatus.loaded =>
        _results.isEmpty ? _buildEmptyState() : _buildResultsList(),
    };
  }

  Widget _buildIdleState() {
    final recents = LocalLibrary.instance.recentSearches.value;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (recents.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: () => LocalLibrary.instance.clearRecentSearches(),
                child: const Text(
                  'Clear',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recents
                .map(
                  (q) => ActionChip(
                    label: Text(q),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.border),
                    onPressed: () {
                      _controller.text = q;
                      _search(q);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
        ],
        const Text(
          'Browse Categories',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, i) {
            final (name, icon, color) = _categories[i];
            return GestureDetector(
              onTap: () {
                final q = '$name songs official audio';
                _controller.text = q;
                _search(q);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Shimmer.fromColors(
          baseColor: AppColors.surface,
          highlightColor: AppColors.surfaceLight,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: AppColors.textSubtle),
          const SizedBox(height: 12),
          const Text(
            'Search request failed',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (_lastQuery != null) _search(_lastQuery!);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: AppColors.textSubtle),
          SizedBox(height: 12),
          Text(
            'No matching music found',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final track = _results[i];
        final title = (track['title'] as String?) ?? '';
        final artist = (track['artist'] as String?) ?? '';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppImage(
              track['artwork'] as String?,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          trailing: const Icon(
            Icons.play_arrow_rounded,
            color: AppColors.accent,
            size: 26,
          ),
          onTap: () => playTrack(context, track, _results, i),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════
// PROFILE SCREEN
// ═══════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  ProfileModel? _profile;
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
    LocalLibrary.instance.likedSongs.addListener(_onLibraryChange);
    LocalLibrary.instance.playlists.addListener(_onLibraryChange);
    LocalLibrary.instance.recentlyPlayed.addListener(_onLibraryChange);
  }

  @override
  void dispose() {
    _tabController.dispose();
    LocalLibrary.instance.likedSongs.removeListener(_onLibraryChange);
    LocalLibrary.instance.playlists.removeListener(_onLibraryChange);
    LocalLibrary.instance.recentlyPlayed.removeListener(_onLibraryChange);
    super.dispose();
  }

  void _onLibraryChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final profile = await ProfileService.instance.getCurrentProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final isSignedIn = user != null;
    final profile =
        _profile ??
        ProfileModel(
          id: 'self',
          username: 'vshots_listener',
          fullName: user?.email ?? 'Music Listener',
          bio: 'Listening on V Shots',
        );

    final likedSongs = LocalLibrary.instance.likedSongs.value;
    final playlists = LocalLibrary.instance.playlists.value;
    final recentlyPlayed = LocalLibrary.instance.recentlyPlayed.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'My Music Profile',
          style: TextStyle(
            color: AppColors.textMain,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textMain,
            ),
            onPressed: () => Navigator.push(
              context,
              AppPageRoute<void>(builder: (_) => const SettingsScreen()),
            ).then((_) => _loadProfileData()),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight),
            )
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              color: AppColors.primaryLight,
              backgroundColor: AppColors.surface2,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          Center(
                            child: AppAvatar(
                              avatarUrl: profile.avatarUrl,
                              name: profile.fullName,
                              size: 84,
                              hasGradientBorder: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            profile.fullName,
                            style: const TextStyle(
                              color: AppColors.textMain,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isSignedIn
                                ? (user.email ?? '@${profile.username}')
                                : 'Guest Session',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Music Stats Row
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMusicStat(
                                  'Liked Songs',
                                  '${likedSongs.length}',
                                  Icons.favorite,
                                  AppColors.hotPink,
                                ),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: AppColors.border,
                                ),
                                _buildMusicStat(
                                  'Playlists',
                                  '${playlists.length}',
                                  Icons.playlist_play,
                                  AppColors.accent,
                                ),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: AppColors.border,
                                ),
                                _buildMusicStat(
                                  'Played',
                                  '${recentlyPlayed.length}',
                                  Icons.history,
                                  AppColors.warning,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Action Buttons Row
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  text: 'Edit Profile',
                                  icon: Icons.edit_outlined,
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.medium,
                                  onPressed: () => Navigator.push(
                                    context,
                                    AppPageRoute<void>(
                                      builder: (_) => EditProfileScreen(
                                        initialProfile: profile,
                                        onProfileUpdated: (p) =>
                                            setState(() => _profile = p),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AppButton(
                                  text: isSignedIn ? 'Settings' : 'Sign In',
                                  icon: isSignedIn
                                      ? Icons.settings_outlined
                                      : Icons.login_rounded,
                                  variant: isSignedIn
                                      ? AppButtonVariant.secondary
                                      : AppButtonVariant.primary,
                                  size: AppButtonSize.medium,
                                  onPressed: () {
                                    if (isSignedIn) {
                                      Navigator.push(
                                        context,
                                        AppPageRoute<void>(
                                          builder: (_) =>
                                              const SettingsScreen(),
                                        ),
                                      ).then((_) => _loadProfileData());
                                    } else {
                                      AuthModal.show(
                                        context,
                                      ).then((_) => _loadProfileData());
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Creator Hub Card
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: profile.isCreator
                                    ? AppColors.accent.withValues(alpha: 0.4)
                                    : AppColors.border,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppColors.primaryGradient,
                                  ),
                                  child: Icon(
                                    profile.isCreator
                                        ? Icons.video_library_rounded
                                        : Icons.stars_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile.isCreator
                                            ? 'Creator Studio'
                                            : 'Become a Creator',
                                        style: const TextStyle(
                                          color: AppColors.textMain,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        profile.isCreator
                                            ? 'Upload original music & shots'
                                            : 'Share music with listeners',
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _handleCreatorUpload(context),
                                  child: Text(
                                    profile.isCreator ? 'Upload' : 'Request',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ProfileTabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        indicatorColor: AppColors.accent,
                        indicatorWeight: 3,
                        labelColor: AppColors.accent,
                        unselectedLabelColor: AppColors.textMuted,
                        tabs: const [
                          Tab(
                            icon: Icon(Icons.favorite_rounded),
                            text: 'Liked Songs',
                          ),
                          Tab(
                            icon: Icon(Icons.playlist_play_rounded),
                            text: 'Playlists',
                          ),
                          Tab(
                            icon: Icon(Icons.history_rounded),
                            text: 'Recently Played',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLikedTracksTab(likedSongs),
                    _buildPlaylistsTab(playlists),
                    _buildRecentlyPlayedTab(recentlyPlayed),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMusicStat(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textMain,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLikedTracksTab(List<Map<String, dynamic>> liked) {
    if (liked.isEmpty) {
      return const Center(
        child: Text(
          'No liked songs yet — tap ♡ on any song to save it here.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: liked.length,
      itemBuilder: (context, index) {
        if (index < 0 || index >= liked.length) return const SizedBox.shrink();
        final t = liked[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppImage(
              t['artwork'] as String?,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          title: Text(
            t['title'] as String? ?? '',
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
          ),
          subtitle: Text(
            t['artist'] as String? ?? '',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            maxLines: 1,
          ),
          trailing: const Icon(
            Icons.play_arrow_rounded,
            color: AppColors.accent,
            size: 22,
          ),
          onTap: () => playTrack(context, t, liked, index),
        );
      },
    );
  }

  Widget _buildPlaylistsTab(List<Map<String, dynamic>> playlists) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          title: const Text(
            'Create Playlist',
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: const Text(
            'Create a new music playlist',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          onTap: () {
            final ctrl = TextEditingController();
            showDialog<void>(
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
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (ctrl.text.trim().isNotEmpty) {
                        LocalLibrary.instance.createPlaylist(ctrl.text.trim());
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('Create'),
                  ),
                ],
              ),
            );
          },
        ),
        for (final p in playlists)
          ListTile(
            leading: const Icon(
              Icons.playlist_play_rounded,
              color: AppColors.accent,
              size: 32,
            ),
            title: Text(p['name'] as String? ?? ''),
            subtitle: Text(
              '${(p['tracks'] as List?)?.length ?? 0} tracks',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentlyPlayedTab(List<Map<String, dynamic>> recent) {
    if (recent.isEmpty) {
      return const Center(
        child: Text(
          'No recently played tracks.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: recent.length,
      itemBuilder: (context, index) {
        if (index < 0 || index >= recent.length) return const SizedBox.shrink();
        final t = recent[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppImage(
              t['artwork'] as String?,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          title: Text(
            t['title'] as String? ?? '',
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
          ),
          subtitle: Text(
            t['artist'] as String? ?? '',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            maxLines: 1,
          ),
          trailing: const Icon(
            Icons.play_arrow_rounded,
            color: AppColors.accent,
            size: 22,
          ),
          onTap: () => playTrack(context, t, recent, index),
        );
      },
    );
  }
}

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  _ProfileTabBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.background, child: _tabBar);
  }

  @override
  bool shouldRebuild(_ProfileTabBarDelegate oldDelegate) {
    return false;
  }
}

// ═══════════════════════════════════════════════
// LYRICS & SHARED BOTTOM SHEETS
// ═══════════════════════════════════════════════

void showAddToPlaylistSheet(BuildContext context, Map<String, dynamic> track) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (ctx) {
      return ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: LocalLibrary.instance.playlists,
        builder: (context, playlists, _) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Add to playlist',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No playlists yet. Create one from Profile first.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                else
                  ...playlists.map(
                    (p) => ListTile(
                      leading: const Icon(Icons.playlist_play),
                      title: Text(p['name'] as String? ?? ''),
                      onTap: () async {
                        await LocalLibrary.instance.addTrackToPlaylist(
                          p['id'] as String,
                          track,
                        );
                        playbackSignalTracker.onPlaylistAdded(track);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added to ${p['name']}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

void showMoreOptionsSheet(
  BuildContext context,
  Map<String, dynamic> track, {
  VoidCallback? onNotInterested,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final title = (track['title'] as String?) ?? 'Unknown Track';
      final artist = (track['artist'] as String?) ?? 'Unknown Artist';
      final trackId = (track['id'] as String?) ?? '';

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppImage(
                    track['artwork'] as String?,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(color: AppColors.borderSubtle),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(ctx);
                  SharePlus.instance.share(
                    ShareParams(
                      text:
                          'Listen to "$title" by $artist on V Shots: https://www.youtube.com/watch?v=$trackId',
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Sleep Timer'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSleepTimerDialog(context);
                },
              ),
              if (onNotInterested != null)
                ListTile(
                  leading: const Icon(Icons.do_not_disturb_on_outlined),
                  title: const Text('Not Interested in this artist'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onNotInterested();
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

void _showSleepTimerDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Sleep Timer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('15 minutes'),
            onTap: () {
              SleepTimer.instance.set(const Duration(minutes: 15));
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('30 minutes'),
            onTap: () {
              SleepTimer.instance.set(const Duration(minutes: 30));
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('45 minutes'),
            onTap: () {
              SleepTimer.instance.set(const Duration(minutes: 45));
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('60 minutes'),
            onTap: () {
              SleepTimer.instance.set(const Duration(minutes: 60));
              Navigator.pop(ctx);
            },
          ),
          if (SleepTimer.instance.isActive)
            ListTile(
              title: const Text(
                'Turn off timer',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                SleepTimer.instance.cancel();
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    ),
  );
}

class LyricsScreen extends StatefulWidget {
  const LyricsScreen({required this.track, super.key});
  final Map<String, dynamic> track;

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  LyricsResult? _result;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
  }

  Future<void> _fetchLyrics() async {
    final title = (widget.track['title'] as String?) ?? '';
    final artist = (widget.track['artist'] as String?) ?? '';
    final duration = (widget.track['duration'] as int?) ?? 0;

    final res = await LyricsService.instance.fetch(
      trackName: title,
      artistName: artist,
      durationSeconds: duration > 0 ? duration : null,
    );

    if (mounted) {
      setState(() {
        _result = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.track['title'] as String?) ?? 'Lyrics';
    final artist = (widget.track['artist'] as String?) ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              artist,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight),
            )
          : (_result == null || !_result!.hasAny)
          ? const Center(
              child: Text(
                'No lyrics available for this track',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Text(
                _result!.plainText ?? 'Instrumental Track',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.8,
                  color: AppColors.textMain,
                ),
              ),
            ),
    );
  }
}

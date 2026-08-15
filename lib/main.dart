// ignore_for_file: prefer_const_constructors, unnecessary_lambdas, curly_braces_in_flow_control_structures, directives_ordering
// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Diagnostic Playback & Hybrid Streaming Engine (Nova Edition)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'core/ads/ad_manager.dart';
import 'core/audio/vshots_audio_handler.dart';
import 'core/backend/auth_service.dart';
import 'core/backend/supabase_sync_service.dart';
import 'core/discovery/home_content_coordinator.dart';
import 'core/discovery/innertube_music_service.dart';
import 'core/preferences/user_preferences.dart';
import 'core/recommendation/recommendation_event_service.dart';
import 'core/remote_config/remote_config_service.dart';
import 'core/backend/supabase_service.dart';
import 'core/cache/search_cache.dart';
import 'core/lyrics/lyrics_service.dart';
import 'core/models/profile_model.dart';
import 'core/motion/motion.dart';
import 'core/player/playback_manager.dart';
import 'core/player/queue_controller.dart';
import 'core/player/repeat_mode.dart';
import 'core/player/sleep_timer.dart';
import 'core/providers/adapters/youtube/youtube_data_api_client.dart';
import 'core/providers/adapters/youtube/youtube_repository.dart';
import 'core/providers/provider_bootstrap.dart';
import 'core/recommendation/recommendation_engine.dart';
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
import 'features/discovery/discovery_reels_screen.dart';
import 'features/foryou/for_you_feed_service.dart';
import 'features/home/archive_home_screen.dart';
import 'features/onboarding/content_preferences_onboarding.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/profile/settings_screen.dart';
import 'features/search/archive_search_screen.dart';
import 'features/shots/upload_shot_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    SupabaseService.initialize(),
    LocalLibrary.instance.initialize(),
    SignalStore.instance.initialize(),
    PreferencesStore.instance.initialize(),
    RemoteConfigService.instance.init(),
  ]);

  await AuthService.instance.initializeGoogleSignIn();

  // Initialize Google AdMob + UMP consent (no-op unless production ad IDs are
  // configured via ADMOB_NATIVE_AD_ID).
  await AdManager.instance.initialize();

  audioHandler = await AudioService.init(
    builder: () => VShotsAudioHandler(audioPlayer),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.vshots.live.channel.audio',
      androidNotificationChannelName: 'V Shots playback',
      androidNotificationOngoing: true,
      // Keep the media session available while the app is backgrounded;
      // the permitted YouTube iframe remains the playback surface.
      androidStopForegroundOnPause: false,
    ),
  );

  // Native audio focus/session configuration. This controls interruptions and
  // headset/Bluetooth focus without extracting or replacing YouTube media.
  final audioSession = await AudioSession.instance;
  await audioSession.configure(AudioSessionConfiguration.music());
  audioSession.interruptionEventStream.listen((event) {
    if (event.begin) {
      unawaited(audioPlayer.pause());
    } else if (event.type == AudioInterruptionType.pause) {
      unawaited(audioPlayer.play());
    }
  });
  audioSession.becomingNoisyEventStream.listen((_) {
    unawaited(audioPlayer.pause());
  });

  // Wire the formal PlaybackManager to the existing single global YouTube
  // engine. It does NOT create a second player — it owns the same controller
  // and mirrors into the global notifiers so existing UI keeps working.
  PlaybackManager.instance.attach(
    controllerProvider: () => globalYtController,
    onTrackChanged: (t) => currentTrackNotifier.value = t,
    onExpandedChanged: (v) => isPlayerExpandedNotifier.value = v,
    onPlayStateChanged: (v) => globalPlaybackStateNotifier.value = v,
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

/// Tracks the currently active bottom-tab index (0=Home,1=Discover,
/// 2=Search,3=Profile). The single global YouTube IFrame is only ever
/// rendered by ONE surface at a time: the Discover feed renders it while
/// the Discover tab is active, and the persistent overlay (mini/full player)
/// renders it on every other tab. This prevents two `YoutubePlayer` widgets
/// sharing the same controller simultaneously.
final ValueNotifier<int> currentTabIndexNotifier = ValueNotifier<int>(0);

YoutubePlayerController? globalYtController;
String? globalPlayingVideoId;

/// Single source of truth for whether the global YouTube player is currently
/// playing (mirrors the official player's onStateChange). This is what the
/// mini-player dock, full player and any UI read to reflect playback state.
final ValueNotifier<bool> globalPlaybackStateNotifier =
    ValueNotifier<bool>(false);

/// Fires whenever the current YouTube video reaches ENDED. The Discover feed
/// listens to this to auto-advance to the next item (record completion ->
/// next page -> load + autoplay next video).
final ValueNotifier<String?> globalVideoEndedNotifier =
    ValueNotifier<String?>(null);

/// There is exactly ONE YouTube IFrame engine in the app: [globalYtController].
///
/// Home, Search, the full player, the mini-player and (when relevant) any
/// global transition all operate on this single controller so that only one
/// logical "current player state" ever exists. Loading a different [videoId]
/// replaces the current media in-place (which stops the previous video) rather
/// than creating a second playback engine.
///
/// When [autoPlay] is true the newly (re)loaded video is started; otherwise it
/// is only cued and must be started by an explicit user interaction (required
/// by YouTube/Android autoplay-with-sound policies).
YoutubePlayerController ensureGlobalPlayer({
  String? videoId,
  bool autoPlay = true,
}) {
  final targetId = videoId ?? 'kJQP7kiw5Fk';
  if (globalYtController == null) {
    final controller = YoutubePlayerController.fromVideoId(
      videoId: targetId,
      autoPlay: autoPlay,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
        loop: false,
        enableCaption: false,
        showVideoAnnotations: false,
      ),
    );
    // Mirror the official player's live state so the mini dock and UI show
    // the true play/pause state (handles autoplay-blocked videos correctly).
    controller.listen((value) {
      final st = value.playerState;
      if (st == PlayerState.playing || st == PlayerState.buffering) {
        globalPlaybackStateNotifier.value = true;
      } else if (st == PlayerState.paused || st == PlayerState.cued) {
        globalPlaybackStateNotifier.value = false;
      } else if (st == PlayerState.ended) {
        globalPlaybackStateNotifier.value = false;
        globalVideoEndedNotifier.value = globalPlayingVideoId;
      }
    });
    globalYtController = controller;
    globalPlayingVideoId = targetId;
  } else if (globalPlayingVideoId != targetId) {
    unawaited(globalYtController!.loadVideoById(videoId: targetId));
    globalPlayingVideoId = targetId;
    if (autoPlay) {
      unawaited(globalYtController!.playVideo());
      globalPlaybackStateNotifier.value = true;
    } else {
      globalPlaybackStateNotifier.value = false;
    }
  } else if (autoPlay) {
    unawaited(globalYtController!.playVideo());
    globalPlaybackStateNotifier.value = true;
  }
  return globalYtController!;
}

bool isCurrentlyPlaying = false;
RepeatMode repeatMode = RepeatMode.off;
bool isShuffleOn = false;
List<int> shuffleOrder = [];

final YouTubeDataApiClient sharedYtApiClient = YouTubeDataApiClient();
final musicRepository = buildMusicRepository(apiClient: sharedYtApiClient);
final forYouFeedService = ForYouFeedService(apiClient: sharedYtApiClient);
final homeContentCoordinator = HomeContentCoordinator(
  repository: YouTubeRepository(client: sharedYtApiClient),
);

/// Shared discovery service (YouTube Music InnerTube metadata browse/search)
/// used by the ArchiveTune-style Home and Discovery screens. Single discovery
/// implementation — playback always goes through the official player below.
final musicDiscoveryService = InnerTubeMusicService();
final YouTubeRepository youTubeRepository = YouTubeRepository(
  client: sharedYtApiClient,
);
final recommendationEngine = RecommendationEngine(musicRepository);
final playbackSignalTracker = PlaybackSignalTracker(recommendationEngine);

void _log(String message) {
  debugPrint('[VShots] $message');
}

/// Resets Home/Discover content caches when preferences change (Phase 19/20)
/// so the next Home load regenerates live, personalized content — no app
/// restart needed.
void resetHomeContentForPreferenceChange() {
  homeContentCoordinator.reset();
  SearchCache.instance.clear();
  _log('[Content] Preference change — Home cache + coordinator reset.');
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

  final nextIndex = QueueController.nextIndexOnCompletion();
  if (nextIndex == null) {
    _log('[QUEUE] End of queue reached, playback stopped');
    return;
  }

  _log('[QUEUE] Auto-advancing to queue index $nextIndex');
  final nextTrack = currentQueue[nextIndex];
  playTrack(context, nextTrack, currentQueue, nextIndex);
}

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
      if (!mounted) return;
      // Phase 1/2: one-time content-preferences onboarding on first install.
      if (PreferencesStore.instance.needsOnboarding) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (onboardCtx) => ContentPreferencesOnboarding(
              // Use the onboarding route's OWN context so navigation to Home
              // works even after the Splash route has been removed.
              onComplete: (ctx) => Navigator.of(ctx).pushReplacement(
                MaterialPageRoute<void>(builder: (_) => const MainShell()),
              ),
            ),
          ),
        );
      } else {
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

class _MainShellState extends State<MainShell>
    with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    currentTabIndexNotifier.value = 0;
    audioPlayer.playerStateStream.listen((state) {
      isCurrentlyPlaying = state.playing;
    });

    audioHandler?.onSkipNext = () => _playAdjacentInQueue(context, 1);
    audioHandler?.onSkipPrevious = () => _playAdjacentInQueue(context, -1);
    audioHandler?.onTrackCompleted = () => _handleTrackCompleted(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lifecycle changes must not recreate or reload the single iframe.
    debugPrint('[BrowserPlayer] lifecycle=$state track=$globalPlayingVideoId');
    if (state == AppLifecycleState.resumed && globalPlayingVideoId != null) {
      audioHandler?.mediaItem.add(MediaItem(
        id: globalPlayingVideoId!,
        title: currentTrack?['title'] as String? ?? 'V Shots',
        artist: currentTrack?['artist'] as String? ?? 'Unknown Artist',
        artUri: Uri.tryParse(currentTrack?['artwork'] as String? ?? ''),
      ));
    }
  }

  Future<bool> _onWillPop() async {
    // 1. If player is currently expanded full screen, minimize down to mini player dock
    if (isPlayerExpandedNotifier.value) {
      isPlayerExpandedNotifier.value = false;
      return false;
    }
    // 2. If on Discover (1), Search (2), or Profile (3), go back to Home (0)
    if (_index != 0) {
      setState(() {
        _index = 0;
        currentTabIndexNotifier.value = 0;
      });
      return false;
    }
    // 3. If on Home tab, show exit confirmation dialog
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: const Text(
          'Exit V Shots?',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Are you sure you want to exit the app?',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.hotPink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Exit',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canExit = await _onWillPop();
        if (canExit) {
          unawaited(SystemNavigator.pop());
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 4 Clean Tabs (Home, Discover, Search, Profile)
            IndexedStack(
              index: _index.clamp(0, 3),
              children: [
                ArchiveHomeScreen(
                  service: musicDiscoveryService,
                  onPlayTrack: (track, queue, index) =>
                      playTrack(context, track, queue, index),
                ),
                DiscoveryReelsScreen(
                  service: musicDiscoveryService,
                  onPlayTrack: (track, queue, index) =>
                      playTrack(context, track, queue, index),
                ),
                ArchiveSearchScreen(
                  service: musicDiscoveryService,
                  onPlayTrack: (track, queue, index) =>
                      playTrack(context, track, queue, index),
                ),
                const ProfileScreen(),
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
                    // Discovery uses the same global player session. Keep the
                    // compact dock visible here as well; the expanded view is
                    // the only surface that owns the single official iframe.
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
                setState(() {
                  _index = i.clamp(0, 3);
                  currentTabIndexNotifier.value = i.clamp(0, 3);
                });
              },
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// PERSISTENT PLAYER OVERLAY (FULL & MINI RESIZE)
// ═══════════════════════════════════════════════

/// One persistent WebView surface for the expanded browser state. It loads
/// the normal YouTube webpage, not an iframe/controller or extracted stream.
/// The widget survives track changes and only navigates the existing WebView.
class _InAppYoutubeBrowser extends StatefulWidget {
  const _InAppYoutubeBrowser({required this.videoId, this.artwork});

  final String videoId;
  final String? artwork;

  @override
  State<_InAppYoutubeBrowser> createState() => _InAppYoutubeBrowserState();
}

class _InAppYoutubeBrowserState extends State<_InAppYoutubeBrowser>
    with AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;
  String? _loadedId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (error) => debugPrint('[BrowserPlayer] ${error.description}'),
      ));
    _load(widget.videoId);
  }

  @override
  void didUpdateWidget(covariant _InAppYoutubeBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) _load(widget.videoId);
  }

  void _load(String id) {
    if (id.isEmpty || id == _loadedId) return;
    _loadedId = id;
    // Normal YouTube webpage. No direct media URL, scraping, extraction or
    // custom playback layer is involved.
    unawaited(_controller.loadRequest(
      Uri.parse('https://m.youtube.com/watch?v=${Uri.encodeComponent(id)}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return WebViewWidget(controller: _controller);
  }
}

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
    // Keep the single global engine aligned with the current track's metadata.
    _ensureExpandedPlayerLoaded();
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
    _ensureExpandedPlayerLoaded();
  }

  /// Guarantees the single global YouTube engine is loaded with the CURRENT
  /// track, never a stale/different video than the metadata being shown.
  /// This is what makes the mini-player and full player consistent even when
  /// the current track originated from the Discover feed (which is played
  /// through the same engine while its own in-feed surface is active).
  void _ensureExpandedPlayerLoaded() {
    final id = widget.track['id'] as String? ?? '';
    if (id.isEmpty) return;
    if (globalPlayingVideoId == id) return;
    ensureGlobalPlayer(videoId: id, autoPlay: widget.isExpanded);
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
    // Phase 9/10: optimistic local update + background Supabase like sync.
    unawaited(SupabaseSyncService.instance.syncLikes());
    RecommendationEventService.instance.track(
      wasLiked ? RecommendationEvents.songLike : RecommendationEvents.songSkip,
      videoId: widget.track['id'] as String?,
    );
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
      // One compact dock shared by every tab. It never creates a second
      // playback surface; tapping/dragging only expands the existing player.
      return Stack(
        children: [
          // Keep the same browser session mounted while collapsed so a swipe
          // updates the current YouTube page without destroying the surface.
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding + 72,
            height: 1,
            child: Opacity(
              opacity: 0.01,
              child: _InAppYoutubeBrowser(
                videoId: trackId,
                artwork: widget.track['artwork'] as String?,
              ),
            ),
          ),
          Positioned(
        left: 12,
        right: 12,
        bottom: bottomPadding + 8,
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta != null && details.primaryDelta! < -8) {
              widget.onToggleExpand(true);
            }
          },
          onTap: () => widget.onToggleExpand(true),
          child: Material(
            color: Colors.transparent,
            child: Container(
              height: 64,
              padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 6))],
              ),
              child: Row(
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: AppImage(widget.track['artwork'] as String?, width: 48, height: 48)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(artist.isEmpty ? 'Unknown Artist' : artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ])),
                  IconButton(icon: const Icon(Icons.expand_less_rounded), tooltip: 'Expand player', onPressed: () => widget.onToggleExpand(true)),
                ],
              ),
            ),
          ),
        ),
      ),
        ],
      );
    }
    // ── FULLSCREEN EXPANDED PLAYER VIEW ─────────────────────────────────
    return Positioned.fill(
      child: Material(
        color: AppColors.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Premium blurred artwork backdrop for depth.
            IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(
                    widget.track['artwork'] as String?,
                    fit: BoxFit.cover,
                  ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Container(
                      color: AppColors.background.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.background.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
            SafeArea(
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
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.18),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: _InAppYoutubeBrowser(
                          videoId: trackId,
                          artwork: widget.track['artwork'] as String?,
                        ),
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
                              color:
                                  _isLiked ? AppColors.hotPink : Colors.white70,
                            ),
                          ),
                          onPressed: _toggleLiked,
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.playlist_add_rounded, size: 26),
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
                          icon:
                              const Icon(Icons.skip_previous_rounded, size: 34),
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
                            color:
                                isShuffleOn ? AppColors.accent : Colors.white60,
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
                      padding:
                          EdgeInsets.fromLTRB(16, 4, 16, bottomPadding + 16),
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
          ],
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
  // Play through the single global YouTube engine (stops/replaces the previous
  // video; does not create a second playback engine).
  ensureGlobalPlayer(videoId: videoId, autoPlay: true);
  globalPlaybackStateNotifier.value = true;

  isPlayerExpandedNotifier.value = true;
  unawaited(LocalLibrary.instance.recordRecentlyPlayed(track));
  playbackSignalTracker.onTrackStarted(track);
  // Phase 9/10: optimistic local update first, then background Supabase sync.
  unawaited(SupabaseSyncService.instance.syncRecentlyPlayed());
  RecommendationEventService.instance.track(
    RecommendationEvents.songPlay,
    videoId: videoId,
    extra: {'title': track['title'] as String? ?? ''},
  );
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
    final profile = _profile ??
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
                        playbackSignalTracker.onPlaylistAdd(track);
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
              SleepTimer.instance.start(const Duration(minutes: 15));
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('30 minutes'),
            onTap: () {
              SleepTimer.instance.start(const Duration(minutes: 30));
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('45 minutes'),
            onTap: () {
              SleepTimer.instance.start(const Duration(minutes: 45));
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text('60 minutes'),
            onTap: () {
              SleepTimer.instance.start(const Duration(minutes: 60));
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

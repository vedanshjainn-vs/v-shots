// ════════════════════════════════════════════════
// V Shots — Diagnostic Playback Fix
// ════════════════════════════════════════════════
//
// ROOT CAUSE FIXES:
// 1. isCurrentlyPlaying only set when player confirms
// 2. Stream URL validation
// 3. Try multiple stream qualities
// 4. Proper error handling with logging
// ════════════════════════════════════════════════

import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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
import 'core/providers/provider_bootstrap.dart';
import 'core/recommendation/feed_intent.dart';
import 'core/recommendation/recommendation_engine.dart';
import 'core/recommendation/signal_recorder.dart';
import 'core/recommendation/signal_store.dart';
import 'core/services/profile_service.dart';
import 'core/theme/app_colors.dart';
import 'shared/widgets/app_avatar.dart';
import 'shared/widgets/app_button.dart';
import 'shared/widgets/app_image.dart';
import 'shared/widgets/bottom_tab_bar.dart';
import 'core/storage/local_library.dart';
import 'features/auth/auth_modal.dart';
import 'features/foryou/for_you_feed_screen.dart';
import 'features/foryou/for_you_feed_service.dart';
import 'features/library/local_import_service.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/profile/settings_screen.dart';
import 'features/shots/upload_shot_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Phase 9 fix (startup concurrency): the audit found these four
  // startup steps ran fully SEQUENTIALLY, one `await` after another,
  // even though most of them touch completely independent subsystems
  // (a Postgres-backed auth SDK, on-device shared_preferences, and an
  // OS media-session registration) with no real data dependency
  // between them — every millisecond one took was pure added latency
  // before the splash screen could even start its own timer.
  //
  // Real dependency that DOES exist and is preserved here:
  //   AuthService.instance.initializeGoogleSignIn() reads
  //   GOOGLE_WEB_CLIENT_ID via `dotenv.maybeGet(...)`, which requires
  //   `dotenv.load(...)` to have already completed — and THAT load
  //   happens inside SupabaseService.initialize() (see that file). So
  //   AuthService genuinely cannot run concurrently with
  //   SupabaseService — it must run after. Everything else below has
  //   no such dependency and is safe to run at the same time:
  //     - SupabaseService.initialize() (network + dotenv load)
  //     - LocalLibrary.instance.initialize() (on-device
  //       shared_preferences reads — zero network, zero shared state
  //       with Supabase)
  //     - AudioService.init(...) (OS media-session registration — zero
  //       shared state with either of the above)
  await Future.wait([
    // Non-blocking-on-failure by design — see supabase_service.dart's
    // file header for why a Supabase outage/misconfiguration must
    // never prevent the app from starting and playing music.
    SupabaseService.initialize(),
    // Local persistence (Liked Songs / Recently Played / Playlists /
    // taste-profile) — see core/storage/local_library.dart. Previously
    // all of this was plain in-memory globals, wiped on every restart.
    LocalLibrary.instance.initialize(),
    // Recommendation engine's persisted signal history (Phase 7,
    // Part I) — same shared_preferences-backed, non-blocking-on-
    // failure pattern as the other two (see SignalStore.initialize()'s
    // own doc: a corrupt/missing signal history must not block
    // startup, recommendations just fall back to cold-start behavior).
    SignalStore.instance.initialize(),
  ]);

  // google_sign_in v7 requires this exactly-once initialize() call
  // before any sign-in UI is shown — see auth_service.dart. Must run
  // AFTER the Future.wait above (depends on SupabaseService having
  // already loaded .env via dotenv.load()).
  await AuthService.instance.initializeGoogleSignIn();

  // Background playback / lock-screen controls — wraps the SAME
  // `audioPlayer` global this app already uses everywhere else (see
  // core/audio/vshots_audio_handler.dart for the full design rationale
  // on why this bridges rather than replaces the existing playback
  // code). Must be initialized before runApp(). Has no dependency on
  // Supabase/LocalLibrary/AuthService, but audio_service's own plugin
  // channel setup does need WidgetsFlutterBinding (already ensured
  // above) — kept as its own awaited step rather than folded into the
  // Future.wait above for exactly that reason (it's not provably
  // independent of plugin-channel init order the way the other two
  // are of EACH OTHER), matching this task's "don't sacrifice
  // reliability for benchmark numbers" rule.
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
// APP
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
// GLOBAL STATE
// ═══════════════════════════════════════════════

final AudioPlayer audioPlayer = AudioPlayer();
// Background-playback bridge (see core/audio/vshots_audio_handler.dart) —
// assigned in main() before runApp(). Every place that starts playback
// (playTrack() below, PlayerScreen._play()) should also call
// audioHandler?.updateNowPlaying(...) so the lock-screen/notification
// stay in sync with what's actually playing.
//
// Nullable (not `late final`) deliberately: widget tests construct
// `VShotsApp` directly without going through main()/AudioService.init()
// (a real gap found and fixed during this session — the app previously
// crashed with a LateInitializationError in any test that built
// MainShell, because `late final` throws if read before main() has run).
// Every call site uses `audioHandler?.` so normal app usage (where
// main() always initializes this before runApp()) is unaffected, while
// tests/any other entry point that skips AudioService.init() degrade
// gracefully instead of crashing.
VShotsAudioHandler? audioHandler;
List<Map<String, dynamic>> currentQueue = [];
int currentQueueIndex = 0;
Map<String, dynamic>? currentTrack;
bool isCurrentlyPlaying = false;
// Liked songs / recently played / recent searches are now persisted
// via LocalLibrary (see core/storage/local_library.dart) — the old
// in-memory-only `likedSongIds`/`recentSearches` lists were removed
// since everything reads/writes through LocalLibrary.instance now.

// Real shuffle/repeat state (Phase 8 fix — previously the Shuffle and
// Repeat buttons in PlayerScreen were empty `onPressed: () {}` stubs
// with no backing state anywhere in the codebase, confirmed during the
// read-only audit). Kept as globals alongside currentQueue/
// currentQueueIndex above (not per-PlayerScreen-instance state)
// because playback continues via the OS media session / mini-player
// after PlayerScreen is popped, and repeat/shuffle must keep applying
// then too — see RepeatMode's own file header for the full design
// rationale and core/player/queue_controller.dart for the shared
// next/previous logic that actually reads these.
RepeatMode repeatMode = RepeatMode.off;
bool isShuffleOn = false;
// When shuffle is on, this holds a shuffled permutation of indices
// into `currentQueue` — `queue_controller.dart` walks THIS order
// instead of `currentQueue`'s natural order, without ever mutating
// `currentQueue` itself (so turning shuffle back off restores the
// original order exactly, and Library/Home/Search screens that read
// `currentQueue` directly are unaffected).
List<int> shuffleOrder = [];

// Single, app-wide shared YoutubeExplode instance. Previously THREE
// separate instances existed (this one, a second one for
// ForYouFeedService, and a third inside for_you_feed_screen.dart) —
// each opened its own HTTP client with no shared connection pooling,
// which is unnecessary overhead on every search/stream-resolve call.
// Made non-private (no leading underscore) specifically so other files
// (for_you_feed_screen.dart) can reuse this exact instance instead of
// constructing their own — see the refinement list's Section B #2.
final YoutubeExplode sharedYt = YoutubeExplode();

// Provider Architecture entry point (see core/providers/). ALL content
// access (search/trending/recommendations/stream resolution) from UI
// code goes through this — see music_repository.dart's file header
// for the full UI -> MusicRepository -> ProviderManager ->
// YouTubeMusicProvider -> existing YouTube implementation -> Stream
// Resolver -> just_audio chain this implements. Built once here, from
// the SAME shared `sharedYt` instance above — this does not construct
// a second YouTube client.
final musicRepository = buildMusicRepository(sharedYt);

// "For You" swipe feed's recommendation service (see
// features/foryou/for_you_feed_service.dart) — Phase 3 fix: now takes
// `musicRepository` (not `sharedYt` directly), so it never calls
// YoutubeExplode itself either.
final forYouFeedService = ForYouFeedService(musicRepository);

// Phase 7 (Part H) — the new hybrid recommendation pipeline. Built
// from the SAME `musicRepository` above (no second YouTube
// integration — the engine only fetches tracks via the existing
// Provider Architecture, per this task's explicit "DO NOT change the
// current YouTube integration" constraint). See
// core/recommendation/recommendation_engine.dart for the full
// pipeline (candidate generation -> scoring -> diversity -> final
// feed) this replaces/augments ForYouFeedService's simpler v1/v2
// logic with, for the surfaces wired to it (Home's "Made For You",
// Discover's exploration feed — see HomeScreen/ForYouFeedScreen).
final recommendationEngine = RecommendationEngine(musicRepository);

// Real playback-signal instrumentation (Part I) — the one place
// main.dart's existing playback call sites report real skip/
// completion/duration/replay/like/playlist/search events into the
// recommendation engine. See core/recommendation/signal_recorder.dart
// for why this is a thin, additive observer, not a second player or a
// duplicated repeat-mode implementation.
final playbackSignalTracker = PlaybackSignalTracker(recommendationEngine);

// ═══════════════════════════════════════════════
// DIAGNOSTIC LOGGER
// ═══════════════════════════════════════════════

void _log(String message) {
  debugPrint('[VShots] $message');
}

/// Plays the next/previous track in the current global queue. This is
/// the single function both the in-app mini-player's skip button AND
/// the OS notification/lock-screen/headset skip buttons route through
/// (see MainShell.initState wiring audioHandler.onSkipNext/onSkipPrevious
/// to this), so there's one real implementation of "what does skip do"
/// rather than two different behaviors depending on where the tap came
/// from.
///
/// Explicit skips always move (see QueueController.nextIndexForSkip's
/// doc — repeat mode never blocks an explicit user/OS skip, only
/// natural track completion does; see _handleTrackCompleted below for
/// that path). Honors shuffle order when `isShuffleOn` is true.
Future<void> _playAdjacentInQueue(BuildContext? context, int delta) async {
  if (currentQueue.isEmpty) return;
  final nextIndex = QueueController.nextIndexForSkip(delta);
  if (nextIndex == null) return;
  final track = currentQueue[nextIndex];
  if (context != null && context.mounted) {
    await playTrack(context, track, currentQueue, nextIndex);
  } else {
    // No BuildContext available (e.g. triggered from a lock-screen tap
    // while the app has no visible Scaffold to attach a SnackBar to) —
    // resolve and play directly without the loading-snackbar UX.
    try {
      final streamUrl = await musicRepository.getStream(track['id'] as String);
      if (streamUrl == null) return;
      await audioPlayer.setUrl(streamUrl);
      await audioPlayer.play();
      currentTrack = track;
      currentQueueIndex = nextIndex;
      audioHandler?.updateNowPlaying(_trackToMediaItem(track));
      // Note: recordRecentlyPlayed() alone feeds the "For You" taste
      // signal now — ForYouFeedService computes recency-weighted
      // scores directly from this persisted history, no separate
      // recordPlay() call needed (see for_you_feed_service.dart's
      // revision-2 header for why the old duplicate signal was removed).
      unawaited(LocalLibrary.instance.recordRecentlyPlayed(track));
      // Phase 7 (Part I): reports the real skip signal for whatever
      // was previously playing (PlaybackSignalTracker.onTrackStarted
      // auto-finalizes a still-open previous track as a skip when a
      // DIFFERENT track starts — see that method's own doc) and
      // starts tracking this new track's real listen time.
      playbackSignalTracker.onTrackStarted(track);
    } catch (e) {
      _log('[SKIP] Background skip failed: $e');
    }
  }
}

/// Handles a track finishing playback ON ITS OWN (not a user/OS skip)
/// — wired to `audioHandler?.onTrackCompleted` in MainShell.initState.
/// This is the one place repeat mode (off/one/all) actually takes
/// effect (Phase 8 fix — previously this always just called
/// `_playAdjacentInQueue(context, 1)` unconditionally, meaning repeat
/// mode did not exist and playback simply always advanced by one,
/// wrapping forever regardless of any button state).
Future<void> _handleTrackCompleted(BuildContext? context) async {
  // Phase 7 (Part I): the track that just finished reached this point
  // via REAL natural completion (ProcessingState.completed, routed
  // through VShotsAudioHandler -> onTrackCompleted -> here) — record
  // that explicitly as SignalType.completed (+ a playDuration signal
  // for however long it was actually listened to) BEFORE starting
  // whatever plays next, in both possible paths below (with/without a
  // BuildContext), rather than letting onTrackStarted's generic
  // "different track started" fallback classify it as an ambiguous
  // skip.
  playbackSignalTracker.onTrackEnded(completed: true);

  final nextIndex = QueueController.nextIndexOnCompletion();
  if (nextIndex == null) {
    // Repeat is off and the queue/shuffle order has genuinely ended —
    // stop rather than looping forever, matching RepeatMode.off's
    // documented contract.
    return;
  }
  final track = currentQueue[nextIndex];
  if (context != null && context.mounted) {
    await playTrack(context, track, currentQueue, nextIndex);
  } else {
    try {
      final streamUrl = await musicRepository.getStream(track['id'] as String);
      if (streamUrl == null) return;
      await audioPlayer.setUrl(streamUrl);
      await audioPlayer.play();
      currentTrack = track;
      currentQueueIndex = nextIndex;
      audioHandler?.updateNowPlaying(_trackToMediaItem(track));
      unawaited(LocalLibrary.instance.recordRecentlyPlayed(track));
      playbackSignalTracker.onTrackStarted(track);
    } catch (e) {
      _log('[AUTO_ADVANCE] Background auto-advance failed: $e');
    }
  }
}

/// Converts one of the app's existing `Map<String, dynamic>` track
/// records into a `MediaItem` — the standard model audio_service (and
/// therefore the OS notification/lock screen) expects. Kept as a single
/// small helper rather than migrating the whole app's track model, to
/// avoid a large invasive rewrite of main.dart's existing, working data
/// flow (see vshots_audio_handler.dart's file header for the same
/// "bridge, don't rewrite" design principle).
MediaItem _trackToMediaItem(Map<String, dynamic> track) {
  return MediaItem(
    id: (track['id'] as String?) ?? '',
    title: (track['title'] as String?) ?? 'Unknown title',
    artist: (track['artist'] as String?) ?? 'Unknown artist',
    artUri: (track['artwork'] as String?) != null
        ? Uri.tryParse(track['artwork'] as String)
        : null,
    duration: track['duration'] is int
        ? Duration(seconds: track['duration'] as int)
        : null,
  );
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
        vsync: this, duration: const Duration(milliseconds: 1200));
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
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _c,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        blurRadius: 32,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: const Icon(Icons.bolt_rounded,
                    size: 56, color: Colors.white),
              ),
              const SizedBox(height: 28),
              const Text('V Shots',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.white)),
              const SizedBox(height: 6),
              const Text('Nova Edition',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.0,
                      color: AppColors.accent)),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// CREATOR PERMISSION FLAG (Configurable)
// ════════════════════════════════════════════════
const bool kCreatorUploadEnabled = false;

// ════════════════════════════════════════════════
// MAIN SHELL
// ════════════════════════════════════════════════

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

  void _handleCreateTap(BuildContext context) {
    if (kCreatorUploadEnabled) {
      Navigator.of(context).push(
        AppPageRoute<void>(
          builder: (_) => const UploadShotScreen(),
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: AppColors.accent, size: 22),
              SizedBox(width: 8),
              Text(
                'Creator Upload',
                style: TextStyle(
                  color: AppColors.textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Limited Access',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Uploading is currently available to selected/approved creators.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Maybe Later', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Access requested! Our team will review your account.'),
                    backgroundColor: AppColors.surface2,
                  ),
                );
              },
              child: const Text('Request Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: const [
              HomeScreen(),
              ForYouFeedScreen(),
              UploadShotScreen(),
              SearchScreen(),
              ProfileScreen(),
            ],
          ),
          Positioned(
            left: 8, right: 8, bottom: 68,
            child: MiniPlayerTransition(
              visible: currentTrack != null && _index != 1,
              child: currentTrack != null
                  ? _MiniPlayer(
                      track: currentTrack!,
                      onTap: () => _openPlayer(context),
                    )
                  : const SizedBox(height: 64),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomTabBar(
        currentIndex: _index,
        onTap: (i) {
          if (i == 2) {
            _handleCreateTap(context);
          } else {
            setState(() => _index = i);
          }
        },
      ),
    );
  }

  void _openPlayer(BuildContext context) {
    if (currentTrack == null) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => PlayerScreen(
          track: currentTrack!,
          queue: currentQueue,
          currentIndex: currentQueueIndex,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1), end: Offset.zero,
            ).animate(CurvedAnimation(
                parent: animation, curve: AppMotion.enter)),
            child: child,
          );
        },
        transitionDuration: AppMotion.medium + const Duration(milliseconds: 80),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// MINI PLAYER — Uses real player state
// ═══════════════════════════════════════════════

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({
    required this.track,
    required this.onTap,
  });

  final Map<String, dynamic> track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4), blurRadius: 12),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Hero(
              tag: 'artwork-${track['id']}',
              child: AppImage(
                (track['artwork'] as String?) ?? '',
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((track['title'] as String?) ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text((track['artist'] as String?) ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                ],
              ),
            ),
            StreamBuilder<PlayerState>(
              stream: audioPlayer.playerStateStream,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data?.playing ?? false;
                return IconButton(
                  icon: PlayPauseMorph(isPlaying: isPlaying, size: 30),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    if (isPlaying) {
                      audioPlayer.pause();
                    } else {
                      audioPlayer.play();
                    }
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
              onPressed: () => _playAdjacentInQueue(context, 1),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// NOTE: title cleaning ("Artist - Song (Official Video)" -> "Song")
// now lives in shared/utils/text_utils.dart's cleanTitle() — this used
// to be a local copy here, but nothing in main.dart calls it directly
// any more (Home/Search/Player all resolve tracks via
// `musicRepository`, which returns already-cleaned titles from
// YoutubeMusicMapper — see that file and text_utils.dart's headers for
// why the two previously-separate copies were consolidated).
// ═══════════════════════════════════════════════
// FIX: Play track with proper diagnostics
// ═══════════════════════════════════════════════

Future<void> playTrack(
  BuildContext context,
  Map<String, dynamic> track,
  List<Map<String, dynamic>> queue,
  int index,
) async {
  _log('═══ PLAYBACK START ═══');
  _log('Track: ${track['title']} (${track['id']})');
  // Immediate tactile feedback on tap — previously the only feedback
  // was the loading snackbar a moment later, which reads as "did my
  // tap register?" on a slower connection.
  unawaited(HapticFeedback.selectionClick());

  try {
    // Step 1: Show loading
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        const SizedBox(width: 12),
        Text('Loading ${track['title']}...'),
      ]),
      backgroundColor: AppColors.surface,
      duration: const Duration(seconds: 10),
    ));

    // Step 2: Resolve stream — routed through MusicRepository ->
    // ProviderManager -> YouTubeMusicProvider, which itself calls the
    // EXISTING resolveAudioStreamUrlLogged()/stream_resolver.dart
    // multi-client fallback (see that file's header for why this must
    // never be a plain, unfixed getManifest() call, and
    // youtube_music_provider.dart's getStream() for the delegation).
    _log('[YT] Resolving stream for: ${track['id']}');
    final streamUrl = await musicRepository.getStream(track['id'] as String);

    if (streamUrl == null || streamUrl.isEmpty) {
      throw Exception('Could not resolve a playable stream for this track');
    }
    _log('[YT] Stream URL obtained (length: ${streamUrl.length})');

    // Step 6: Set URL on player

    _log('[PLAYER] Setting URL...');
    await audioPlayer.setUrl(streamUrl);
    _log('[PLAYER] URL set successfully');

    // Step 7: Wait for player to be ready
    _log('[PLAYER] Waiting for ready state...');
    await audioPlayer.playerStateStream
        .firstWhere((state) => state.processingState == ProcessingState.ready)
        .timeout(const Duration(seconds: 10));
    _log('[PLAYER] Player is READY');

    // Step 8: Play
    _log('[PLAYER] Calling play()...');
    await audioPlayer.play();
    _log('[PLAYER] play() called');

    // Step 9: Update state (only after play is called)
    currentTrack = track;
    currentQueue = queue;
    currentQueueIndex = index;
    // isCurrentlyPlaying is set by the listener in MainShell

    // Step 10: Sync the OS media session (notification/lock screen) so
    // it reflects this track — without this, background playback would
    // work but the notification would show stale/no metadata. See
    // core/audio/vshots_audio_handler.dart.
    audioHandler?.updateNowPlaying(_trackToMediaItem(track));

    // Step 11: Persist to Recently Played + feed the "For You"
    // taste-profile signal — previously this ONLY happened when
    // playing from the Discover/For You feed itself, meaning normal
    // Home/Search plays never improved recommendations at all.
    unawaited(LocalLibrary.instance.recordRecentlyPlayed(track));
    // Phase 7 (Part I): real playback signal for the new
    // recommendation engine — this is THE primary entry point for
    // Home/Search/Library taps, so this is where most PLAY signals
    // originate. If a different track was previously playing,
    // onTrackStarted auto-finalizes it as a real (explicit) skip.
    playbackSignalTracker.onTrackStarted(track);

    _log('═══ PLAYBACK SUCCESS ═══');

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  } catch (e) {
    _log('═══ PLAYBACK FAILED ═══');
    _log('Error: $e');

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to play: ${e.toString().substring(0, 100)}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => playTrack(context, track, queue, index),
          ),
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════

// A single Home section's load state — tracked independently per
// section (see refinement list Section B #3) so one slow/failed query
// doesn't block the others from showing the instant they're ready.
enum _SectionStatus { loading, loaded, error }

class _HomeSectionState {
  _HomeSectionState({required this.query, required this.title, this.intent});
  final String query;
  final String title;
  // Phase 7 (Part V): when set, this section is powered by the new
  // RecommendationEngine (candidate generation -> scoring -> diversity)
  // instead of a single raw search query — used for "Made For You" and
  // "Because You Listened To". `query` is still kept (used as this
  // section's SearchCache key) even for engine-backed sections, so
  // caching/pull-to-refresh work identically either way.
  final FeedIntent? intent;
  _SectionStatus status = _SectionStatus.loading;
  List<Map<String, dynamic>> tracks = [];
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Each section loads and renders independently — previously both
  // sections were fetched via a single Future.wait and the ENTIRE
  // screen stayed on a full shimmer until both returned, so a single
  // slow query held back a section that was actually already ready.
  //
  // REVISION (per user request: "need to add more categories and all
  // categories should have true recommendations ... it should update
  // automatically"):
  //   - Expanded from 2 hardcoded sections to a real category set
  //     (Trending, New Releases, then genuine genre/language buckets —
  //     Bollywood, Punjabi, Hindi, English, Hip-Hop, EDM/Party, Chill —
  //     matching the same category vocabulary Search already uses, so
  //     "Bollywood" on Home and "Bollywood" in Search mean the same
  //     thing, not two different ad-hoc query strings).
  //   - Query strings are deliberately more specific than the old
  //     generic "new music releases 2024" (which was already stale by
  //     the time this shipped) — using year-agnostic, genre-qualified
  //     queries like "official audio" / "hit songs" that YouTube's own
  //     ranking naturally keeps current, rather than baking in a
  //     hardcoded year that goes stale.
  //   - "Made For You": a genuinely personalized section built from
  //     the SAME recency-weighted taste profile that drives the
  //     Discover/For You feed (LocalLibrary.instance.artistPlayCounts)
  //     — reuses ForYouFeedService's query-building logic instead of a
  //     second, divergent implementation. Only shown once the user has
  //     real play history (an empty/generic section here would be
  //     worse than not showing it at all).
  //   - "Auto-update": each section already used SearchCache's
  //     stale-while-revalidate (5 min TTL) — kept — PLUS pull-to-
  //     refresh (RefreshIndicator) now force-bypasses the cache so the
  //     user can explicitly ask for fresh results at any time, not
  //     just wait for the TTL to lapse.
  final Set<String> _activeFetches = <String>{};

  late final List<_HomeSectionState> _sections = [
    _HomeSectionState(query: 'trending music today official audio', title: 'Trending Now'),
    _HomeSectionState(query: 'new music releases official audio', title: 'New Releases'),
    if (forYouFeedService.hasTasteProfile) ...[
      _HomeSectionState(
        query: '__engine_made_for_you__',
        title: 'Made For You',
        intent: FeedIntent.madeForYou,
      ),
      _HomeSectionState(
        query: '__engine_because_you_listened__',
        title: 'Because You Listened To',
        intent: FeedIntent.becauseYouListenedTo,
      ),
    ],
    _HomeSectionState(query: 'top indian songs official audio', title: 'India Hits'),
    _HomeSectionState(query: 'punjabi hit songs official audio', title: 'Punjabi Hits'),
    _HomeSectionState(query: 'hindi hit songs official audio', title: 'Hindi Hits'),
    _HomeSectionState(query: 'international pop hits official audio', title: 'International Pop'),
    _HomeSectionState(query: 'hip hop rap songs official audio', title: 'Hip-Hop & Rap'),
    _HomeSectionState(query: 'edm dance party songs official audio', title: 'EDM & Party'),
    _HomeSectionState(query: 'chill lofi acoustic music', title: 'Chill & Lofi'),
  ];

  @override
  void initState() {
    super.initState();
    for (final section in _sections) {
      _loadSection(section);
    }
  }

  /// Pull-to-refresh: force-bypasses SearchCache for every section so
  /// the user can explicitly request fresh results on demand, on top
  /// of the existing automatic 5-minute stale-while-revalidate cache.
  Future<void> _refreshAll() async {
    await Future.wait(_sections.map((s) => _loadSection(s, forceRefresh: true)));
  }

  Future<void> _loadSection(_HomeSectionState section, {bool forceRefresh = false}) async {
    if (_activeFetches.contains(section.query)) return;
    _activeFetches.add(section.query);

    final cached = forceRefresh ? null : SearchCache.instance.get(section.query);
    if (cached != null) {
      if (mounted) {
        setState(() {
          section.tracks = cached;
          section.status = _SectionStatus.loaded;
        });
      }
      if (SearchCache.instance.isFresh(section.query)) {
        _activeFetches.remove(section.query);
        return;
      }
    } else if (mounted) {
      setState(() => section.status = _SectionStatus.loading);
    }

    try {
      final results = section.intent != null
          ? await _generateEngineFeed(section.intent!)
          : await _search(section.query);
      if (!mounted) return;
      if (results.isEmpty && cached == null) {
        setState(() => section.status = _SectionStatus.error);
        return;
      }
      SearchCache.instance.set(section.query, results);
      setState(() {
        section.tracks = results;
        section.status = _SectionStatus.loaded;
      });
    } catch (e) {
      _log('Home section "${section.title}" load failed: $e');
      if (mounted && cached == null) {
        setState(() => section.status = _SectionStatus.error);
      }
    } finally {
      _activeFetches.remove(section.query);
    }
  }

  /// Runs the new RecommendationEngine pipeline (Part H/V) for
  /// engine-backed Home sections ("Made For You"/"Because You
  /// Listened To") and converts its `ScoredTrack` results back to the
  /// app's existing `Map<String, dynamic>` track shape — same
  /// conversion the Provider Architecture already established
  /// (`ProviderTrack.toTrackMap()`), so nothing downstream (playTrack,
  /// LocalLibrary, the tracks-row UI) needs to know a different
  /// pipeline produced these tracks.
  Future<List<Map<String, dynamic>>> _generateEngineFeed(FeedIntent intent) async {
    final scored = await recommendationEngine.generateFeed(
      intent: intent,
      excludeIds: const {},
      count: 15,
    );
    return scored.map((s) => s.track.toTrackMap()).toList();
  }

  // Phase 3 fix: HomeScreen no longer calls `sharedYt.search.search()`
  // directly — routed through MusicRepository -> ProviderManager ->
  // YouTubeMusicProvider, which applies the exact same
  // filter/clean/map logic this method used to do inline (see
  // YoutubeMusicMapper — same 15-min cap, same podcast/compilation
  // exclusion, same title cleaning), just consolidated into one shared
  // place instead of 3 near-duplicate copies (Home/Search/For You each
  // had their own).
  Future<List<Map<String, dynamic>>> _search(String q) {
    return musicRepository.search(q, limit: 15);
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        onRefresh: _refreshAll,
        child: CustomScrollView(
        // A RefreshIndicator needs a scrollable that can always be
        // dragged (even when content is short), hence
        // AlwaysScrollableScrollPhysics — without this, pull-to-refresh
        // silently does nothing on a Home screen short enough to not
        // naturally overflow.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            title: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Text('V Shots', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            ]),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(greeting, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('What do you want to listen to?',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
              ]),
            ),
          ),
          for (final section in _sections) _buildSectionSliver(section),
          const SliverToBoxAdapter(child: SizedBox(height: 160)),
        ],
        ),
      ),
    );
  }

  Widget _buildSectionSliver(_HomeSectionState section) {
    // Phase 7 (Part D): skeleton -> content (and error) transitions
    // now cross-fade via AnimatedSwitcher instead of an abrupt widget
    // swap — each status's content is wrapped in one SliverToBoxAdapter
    // with a KeyedSubtree per status so the switcher can detect the
    // change. A section that resolved with too few results to look
    // intentional (e.g. an odd query returning 1-2 hits) is still
    // simply omitted, same behavior as before.
    final Widget content = switch (section.status) {
      _SectionStatus.loading =>
        KeyedSubtree(key: const ValueKey('loading'), child: _shimmerContent()),
      _SectionStatus.error =>
        KeyedSubtree(key: const ValueKey('error'), child: _errorContent(section)),
      _SectionStatus.loaded when section.tracks.length < 3 =>
        const KeyedSubtree(key: ValueKey('empty'), child: SizedBox.shrink()),
      _SectionStatus.loaded =>
        KeyedSubtree(key: const ValueKey('loaded'), child: _tracksContent(section)),
    };

    return SliverToBoxAdapter(
      child: AnimatedSwitcher(
        duration: AppMotion.fast,
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        child: content,
      ),
    );
  }

  Widget _shimmerContent() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Shimmer.fromColors(
            baseColor: AppColors.surface,
            highlightColor: AppColors.surfaceLight,
            child: Container(width: 150, height: 22,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4))),
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 150, height: 150,
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14))),
                  const SizedBox(height: 8),
                  Container(width: 120, height: 14,
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 4),
                  Container(width: 80, height: 12,
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4))),
                ]),
              ),
            ),
          ),
        ),
      ]);

  }

  /// Real error/retry UI — previously a failed section silently
  /// rendered NOTHING (an empty gap in the scroll view), giving no
  /// indication anything had gone wrong or how to recover.
  Widget _errorContent(_HomeSectionState section) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Icon(Icons.wifi_off, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Couldn\'t load "${section.title}"',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
            ),
            TextButton(
              onPressed: () => _loadSection(section),
              child: const Text('Retry'),
            ),
          ]),
        ),
      );
  }

  Widget _tracksContent(_HomeSectionState section) {
    final isPersonalized = section.title == 'Made For You';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
          child: Row(children: [
            if (isPersonalized) ...[
              const Icon(Icons.auto_awesome, size: 18, color: AppColors.accent),
              const SizedBox(width: 6),
            ],
            Text(section.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ]),
        ),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: section.tracks.length,
            itemBuilder: (context, i) {
              final track = section.tracks[i];
              // Phase 7 (Part D): each card gets a capped staggered
              // fade+rise entrance on first appearance, and
              // PressableScale for real tap feedback (previously a
              // bare GestureDetector with zero visual press response).
              return StaggeredEntrance(
                index: i,
                child: PressableScale(
                  onTap: () => playTrack(context, track, section.tracks, i),
                  child: RepaintBoundary(
                  child: Container(
                  width: 150,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(fit: StackFit.expand, children: [
                          AppImage(
                            (track['artwork'] as String?) ?? '',
                            fit: BoxFit.cover,
                            // Phase 7 fix (UI_PERFORMANCE_AUDIT.md
                            // issue #3): explicit width/height so
                            // AppImage's own memCacheWidth/Height
                            // sizing actually activates — this card is
                            // laid out at a fixed 150-wide slot, but
                            // the raw YouTube thumbnail URL
                            // (`highResUrl`, 480x360) was previously
                            // decoded at full native resolution with
                            // no cache-size hint at all.
                            width: 150,
                            height: 150,
                            errorIconColor: AppColors.accent,
                          ),
                          Positioned(
                            right: 8, bottom: 8,
                            child: Container(
                              width: 36, height: 36,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow,
                                  size: 20, color: Colors.white),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text((track['title'] as String?) ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text((track['artist'] as String?) ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                  ]),
                  ),
                  ),
                ),
              );
            },
          ),
        ),
      ]);
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

// A search screen's real load state — mirrors HomeScreen's own
// loading/loaded/error split (Phase 7 fix) so Search can finally show
// a genuine "search failed, try again" state distinct from "zero
// results for this query," which the audit flagged as identical UI
// before this fix.
enum _SearchStatus { idle, loading, loaded, error }

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  _SearchStatus _status = _SearchStatus.idle;
  String? _lastQuery;

  // Phase 7 (Part E): drives the search field's subtle focus
  // animation (see build()'s AnimatedContainer) — a real focus signal,
  // not a fake/simulated one.
  final _searchFocusNode = FocusNode();
  bool _searchFocused = false;

  // Phase 7 fix: live-as-you-type debounce, instead of only firing on
  // Enter/search-icon press. 400ms is chosen to comfortably outlast
  // normal typing cadence (so a fast typist doesn't fire a request per
  // keystroke) while still feeling responsive.
  Timer? _debounce;

  // Phase 7 fix: guards against a slow, stale request's result landing
  // AFTER a newer request already returned (e.g. user types "a", then
  // quickly "ab" — if "a"'s request is slower, it must not overwrite
  // "ab"'s already-displayed results). Each request captures its own
  // query at call time and only applies its result if it's still the
  // most recent query when it completes.
  int _requestSeq = 0;

  static const _categories = [
    ('Bollywood', '🎵', Color(0xFFE91E63)),
    ('Hindi', '🎤', Color(0xFF9C27B0)),
    ('English', '🎸', Color(0xFF2196F3)),
    ('Pop', '🎵', Color(0xFFE91E63)),
    ('Hip-Hop', '🎤', Color(0xFF673AB7)),
    ('EDM', '🎧', Color(0xFF00BCD4)),
    ('Chill', '😌', Color(0xFF4CAF50)),
    ('Workout', '💪', Color(0xFFFF5722)),
  ];

  /// Called on every keystroke — debounces, then delegates to
  /// [_search]. Kept separate from [_search] so category chips/recent
  /// searches (which want to search IMMEDIATELY, not after a delay)
  /// can still call [_search] directly.
  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _status = _SearchStatus.idle;
        _results = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;

    // Phase 7 fix: reuse SearchCache (previously Home-only) so
    // repeating the same search term within the TTL window doesn't
    // re-hit the network — instant results + a silent background
    // refresh, same stale-while-revalidate pattern Home already uses.
    final cached = SearchCache.instance.get(query);
    final isFresh = SearchCache.instance.isFresh(query);
    if (cached != null) {
      setState(() {
        _results = cached;
        _status = _SearchStatus.loaded;
        _lastQuery = query;
      });
      if (isFresh) return; // fresh enough — skip the network round-trip
    } else {
      setState(() {
        _status = _SearchStatus.loading;
        _lastQuery = query;
      });
    }

    unawaited(LocalLibrary.instance.recordRecentSearch(query));
    // Phase 7 (Part I): real search-behavior signal for the
    // recommendation engine's candidate generation.
    playbackSignalTracker.onSearched(query);

    // Phase 7 fix: prevent duplicate simultaneous requests / stale
    // results — see _requestSeq's doc above.
    final seq = ++_requestSeq;

    try {
      final detailed = await musicRepository.searchDetailed(query, limit: 30);
      if (!mounted || seq != _requestSeq) return; // superseded by a newer query

      if (!detailed.success) {
        if (cached == null) {
          setState(() => _status = _SearchStatus.error);
        }
        // else: keep showing the cached results rather than surfacing
        // a background-refresh failure as a hard error (matches
        // HomeScreen's existing _loadSection() behavior).
        return;
      }

      // Phase 7 fix: de-duplicate by track id — YouTube search can
      // return the same video id twice (e.g. across differently
      // sorted result pages within one response); previously nothing
      // de-duplicated this.
      final seenIds = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final track in detailed.tracks) {
        final id = track['id'] as String? ?? '';
        if (id.isEmpty || seenIds.add(id)) deduped.add(track);
      }

      SearchCache.instance.set(query, deduped);
      setState(() {
        _results = deduped;
        _status = _SearchStatus.loaded;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      if (cached == null) setState(() => _status = _SearchStatus.error);
    }
  }

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Phase 7 (Part E): subtle focus animation on the search
        // field's container — a slightly brighter fill + accent
        // border while focused, so typing "feels instant" from the
        // very first tap rather than the field looking identical
        // focused vs. unfocused.
        title: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _searchFocused ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _searchFocused
                  ? AppColors.accent.withValues(alpha: 0.6)
                  : Colors.transparent,
            ),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _searchFocusNode,
            // Phase 7 fix: live-as-you-type (debounced) search, not
            // submit-only — onSubmitted kept too so pressing
            // Enter/search still works instantly without waiting out
            // the debounce.
            onChanged: (q) {
              setState(() {});
              _onQueryChanged(q);
            },
            onSubmitted: _search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search songs, artists...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.4)),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted, size: 18),
                      onPressed: () {
                        _controller.clear();
                        _onQueryChanged('');
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      // Phase 7 (Part E): every state (loading/error/empty/loaded/idle)
      // now cross-fades via AnimatedSwitcher instead of an instant
      // widget swap — "search feels instant" refers to the DEBOUNCED
      // REQUEST timing (unchanged, still 400ms in _onQueryChanged),
      // not to skipping visual feedback; the transition itself is
      // fast (AppMotion.fast = 220ms) so it never feels laggy.
      body: AnimatedSwitcher(
        duration: AppMotion.fast,
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        child: switch (_status) {
        _SearchStatus.loading => KeyedSubtree(
            key: const ValueKey('loading'),
            child: _searchSkeleton(),
          ),
        _SearchStatus.error => KeyedSubtree(
            key: const ValueKey('error'),
            child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, size: 40, color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text('Search failed — check your connection',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _search(_lastQuery ?? _controller.text),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          ),
        _SearchStatus.loaded when _results.isEmpty => KeyedSubtree(
            key: const ValueKey('empty'),
            child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off, size: 40, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                // Phase 7 fix: this is now a GENUINE "zero results"
                // state (distinct from _SearchStatus.error above) —
                // the request succeeded, it just found nothing.
                Text('No results for "${_lastQuery ?? _controller.text}"',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
              ],
            ),
          ),
          ),
        _SearchStatus.loaded => ListView.builder(
            key: const ValueKey('loaded'),
            padding: const EdgeInsets.all(16),
            itemCount: _results.length,
            itemBuilder: (ctx, i) {
              final track = _results[i];
              // Phase 7 (Part E): capped staggered entrance for result
              // rows, matching Home's card entrance treatment so the
              // two surfaces feel consistent.
              return StaggeredEntrance(
                index: i,
                child: ListTile(
                leading: AppImage(
                  (track['artwork'] as String?) ?? '',
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.circular(8),
                ),
                title: Text((track['title'] as String?) ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text((track['artist'] as String?) ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                onTap: () => playTrack(context, track, _results, i),
                ),
              );
            },
          ),
        _SearchStatus.idle => ListView(
                  key: const ValueKey('idle'),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (LocalLibrary.instance.recentSearches.value.isNotEmpty) ...[
                      const Text('Recent Searches',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ...LocalLibrary.instance.recentSearches.value.take(5).map((s) => ListTile(
                            leading: Icon(Icons.history, color: Colors.white.withValues(alpha: 0.5)),
                            title: Text((s['query'] as String?) ?? ''),
                            onTap: () {
                              _controller.text = (s['query'] as String?) ?? '';
                              _search((s['query'] as String?) ?? '');
                            },
                          )),
                      const SizedBox(height: 24),
                    ],
                    const Text('Browse Categories',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10, runSpacing: 10,
                      children: _categories
                          .map((c) => PressableScale(
                                onTap: () {
                                  _controller.text = c.$1;
                                  _search(c.$1);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: c.$3.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: c.$3.withValues(alpha: 0.3)),
                                  ),
                                  child: Text('${c.$2} ${c.$1}',
                                      style: TextStyle(
                                          color: c.$3, fontWeight: FontWeight.w500)),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
      },
      ),
    );
  }

  /// Skeleton shown while a search request is in flight — matches
  /// Home's shimmer treatment (same colors/shapes) so loading states
  /// feel consistent across the app instead of Search using a bare
  /// spinner while Home uses a rich skeleton.
  Widget _searchSkeleton() {
    return ListView.builder(
      key: const ValueKey('loading-list'),
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Shimmer.fromColors(
          baseColor: AppColors.surface,
          highlightColor: AppColors.surfaceLight,
          child: Row(children: [
            Container(width: 48, height: 48,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: double.infinity, height: 14,
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(width: 120, height: 12,
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// LIBRARY SCREEN
// ═══════════════════════════════════════════════

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    // Rebuild whenever any persisted library list changes, so counts
    // on this screen stay live (e.g. liking a song elsewhere in the
    // app immediately updates "Liked Songs 3" here without needing to
    // leave and re-enter the tab).
    LocalLibrary.instance.likedSongs.addListener(_refresh);
    LocalLibrary.instance.recentlyPlayed.addListener(_refresh);
    LocalLibrary.instance.playlists.addListener(_refresh);
    LocalLibrary.instance.downloadedTracks.addListener(_refresh);
  }

  @override
  void dispose() {
    LocalLibrary.instance.likedSongs.removeListener(_refresh);
    LocalLibrary.instance.recentlyPlayed.removeListener(_refresh);
    LocalLibrary.instance.playlists.removeListener(_refresh);
    LocalLibrary.instance.downloadedTracks.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _importLocalFiles() async {
    final tracks = await LocalImportService.instance.pickAudioFiles();
    for (final t in tracks) {
      await LocalLibrary.instance.addDownloadedTrack(t);
    }
    if (mounted && tracks.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${tracks.length} file(s)')),
      );
    }
  }

  Future<void> _createPlaylistDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await LocalLibrary.instance.createPlaylist(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = LocalLibrary.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _item(
            context,
            Icons.favorite,
            'Liked Songs',
            const Color(0xFFE91E63),
            lib.likedSongs.value.length,
            () => Navigator.push(
              context,
              AppPageRoute<void>(
                builder: (_) => TrackListScreen(
                  title: 'Liked Songs',
                  tracks: lib.likedSongs.value,
                  emptyMessage:
                      'No liked songs yet — tap ♡ on any track to save it here.',
                ),
              ),
            ),
          ),
          _item(
            context,
            Icons.download_done,
            'Downloads (Imported)',
            const Color(0xFF4CAF50),
            lib.downloadedTracks.value.length,
            () => Navigator.push(
              context,
              AppPageRoute<void>(
                builder: (_) => TrackListScreen(
                  title: 'Downloads',
                  tracks: lib.downloadedTracks.value,
                  emptyMessage:
                      'No imported files yet — tap "Import" below to add audio files already on your device.',
                  onRemove: (t) =>
                      LocalLibrary.instance.removeDownloadedTrack(t['id'] as String),
                ),
              ),
            ),
          ),
          _item(
            context,
            Icons.history,
            'Recently Played',
            const Color(0xFFFF9800),
            lib.recentlyPlayed.value.length,
            () => Navigator.push(
              context,
              AppPageRoute<void>(
                builder: (_) => TrackListScreen(
                  title: 'Recently Played',
                  tracks: lib.recentlyPlayed.value,
                  emptyMessage: 'Nothing played yet — go play something!',
                  onClearAll: LocalLibrary.instance.clearRecentlyPlayed,
                ),
              ),
            ),
          ),
          _item(
            context,
            Icons.playlist_play,
            'Playlists',
            const Color(0xFF2196F3),
            lib.playlists.value.length,
            () => Navigator.push(
              context,
              AppPageRoute<void>(builder: (_) => const PlaylistsScreen()),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _importLocalFiles,
            icon: const Icon(Icons.add),
            label: const Text('Import audio files from device'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _createPlaylistDialog,
            icon: const Icon(Icons.playlist_add),
            label: const Text('Create new playlist'),
          ),
          const SizedBox(height: 32),
          if (lib.likedSongs.value.isEmpty &&
              lib.recentlyPlayed.value.isEmpty &&
              lib.playlists.value.isEmpty &&
              lib.downloadedTracks.value.isEmpty)
            Center(
              child: Column(children: [
                Icon(Icons.library_music, size: 48, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                Text('Your library is empty',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label, Color color,
      int count, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$count', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════
// GENERIC TRACK LIST SCREEN (Liked Songs / Recently Played / Downloads)
// ═══════════════════════════════════════════════

class TrackListScreen extends StatelessWidget {
  const TrackListScreen({
    required this.title,
    required this.tracks,
    required this.emptyMessage,
    this.onRemove,
    this.onClearAll,
    super.key,
  });

  final String title;
  final List<Map<String, dynamic>> tracks;
  final String emptyMessage;
  final void Function(Map<String, dynamic> track)? onRemove;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (onClearAll != null && tracks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              onPressed: () {
                onClearAll!();
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: tracks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tracks.length,
              itemBuilder: (ctx, i) {
                final track = tracks[i];
                final isLocal = track['isLocal'] == true;
                return ListTile(
                  leading: isLocal
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                              width: 48, height: 48,
                              color: AppColors.surface,
                              child: const Icon(Icons.music_note, color: Color(0xFF4CAF50))))
                      : AppImage(
                          (track['artwork'] as String?) ?? '',
                          width: 48,
                          height: 48,
                          borderRadius: BorderRadius.circular(8),
                        ),
                  title: Text((track['title'] as String?) ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text((track['artist'] as String?) ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                  trailing: onRemove != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => onRemove!(track),
                        )
                      : null,
                  onTap: () {
                    if (isLocal) {
                      _playLocalTrack(context, track);
                    } else {
                      playTrack(context, track, tracks, i);
                    }
                  },
                );
              },
            ),
    );
  }

  Future<void> _playLocalTrack(
      BuildContext context, Map<String, dynamic> track) async {
    final path = track['localPath'] as String?;
    if (path == null || !LocalImportService.instance.fileStillExists(path)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This file is no longer available on your device.')),
      );
      return;
    }
    try {
      await audioPlayer.setFilePath(path);
      await audioPlayer.play();
      currentTrack = track;
      audioHandler?.updateNowPlaying(_trackToMediaItem(track));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play file: $e')),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════
// PLAYLISTS
// ═══════════════════════════════════════════════

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  @override
  void initState() {
    super.initState();
    LocalLibrary.instance.playlists.addListener(_refresh);
  }

  @override
  void dispose() {
    LocalLibrary.instance.playlists.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final playlists = LocalLibrary.instance.playlists.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      body: playlists.isEmpty
          ? Center(
              child: Text(
                'No playlists yet — create one from the Library tab.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: playlists.length,
              itemBuilder: (ctx, i) {
                final playlist = playlists[i];
                final tracks =
                    List<Map<String, dynamic>>.from(playlist['tracks'] as List? ?? []);
                return ListTile(
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.playlist_play, color: Color(0xFF2196F3)),
                  ),
                  title: Text(playlist['name'] as String? ?? ''),
                  subtitle: Text('${tracks.length} tracks'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () =>
                        LocalLibrary.instance.deletePlaylist(playlist['id'] as String),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    AppPageRoute<void>(
                      builder: (_) => TrackListScreen(
                        title: playlist['name'] as String? ?? 'Playlist',
                        tracks: tracks,
                        emptyMessage: 'This playlist is empty.',
                        onRemove: (t) => LocalLibrary.instance
                            .removeTrackFromPlaylist(playlist['id'] as String, t['id'] as String),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ════════════════════════════════════════════════
// PROFILE SCREEN (Music-Focused)
// ════════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
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

  Future<void> _createPlaylistDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'New Playlist',
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textMain),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: AppColors.textSubtle),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                LocalLibrary.instance.createPlaylist(name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final isSignedIn = user != null;
    final profile = _profile ?? ProfileModel(
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
            icon: const Icon(Icons.settings_outlined, color: AppColors.textMain),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                            isSignedIn ? (user.email ?? '@${profile.username}') : 'Guest Session',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Music Stats Row
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border, width: 1),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMusicStat('Liked Songs', '${likedSongs.length}', Icons.favorite, AppColors.hotPink),
                                Container(width: 1, height: 24, color: AppColors.border),
                                _buildMusicStat('Playlists', '${playlists.length}', Icons.playlist_play, AppColors.accent),
                                Container(width: 1, height: 24, color: AppColors.border),
                                _buildMusicStat('Played', '${recentlyPlayed.length}', Icons.history, AppColors.warning),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Action Buttons
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
                                        onProfileUpdated: (p) => setState(() => _profile = p),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AppButton(
                                  text: isSignedIn ? 'Settings' : 'Sign In',
                                  icon: isSignedIn ? Icons.settings_outlined : Icons.login_rounded,
                                  variant: isSignedIn ? AppButtonVariant.secondary : AppButtonVariant.primary,
                                  size: AppButtonSize.medium,
                                  onPressed: () {
                                    if (isSignedIn) {
                                      Navigator.push(
                                        context,
                                        AppPageRoute<void>(builder: (_) => const SettingsScreen()),
                                      ).then((_) => _loadProfileData());
                                    } else {
                                      AuthModal.show(context).then((_) => _loadProfileData());
                                    }
                                  },
                                ),
                              ),
                            ],
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
                          Tab(icon: Icon(Icons.favorite_rounded), text: 'Liked Songs'),
                          Tab(icon: Icon(Icons.playlist_play_rounded), text: 'Playlists'),
                          Tab(icon: Icon(Icons.history_rounded), text: 'Recently Played'),
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

  Widget _buildMusicStat(String label, String value, IconData icon, Color iconColor) {
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
        child: Text('No liked songs yet — tap ♡ on any song to save it here.', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: liked.length,
      itemBuilder: (context, index) {
        final t = liked[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppImage(t['artwork'] as String?, width: 48, height: 48, fit: BoxFit.cover),
          ),
          title: Text(t['title'] as String? ?? '', style: const TextStyle(color: AppColors.textMain, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1),
          subtitle: Text(t['artist'] as String? ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 12), maxLines: 1),
          trailing: const Icon(Icons.favorite, color: AppColors.hotPink, size: 20),
          onTap: () => playTrack(context, t, liked, index),
        );
      },
    );
  }

  Widget _buildPlaylistsTab(List<Map<String, dynamic>> playlists) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        OutlinedButton.icon(
          onPressed: _createPlaylistDialog,
          icon: const Icon(Icons.add, color: AppColors.accent),
          label: const Text('Create New Playlist', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.accent),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),
        if (playlists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No playlists yet.', style: TextStyle(color: AppColors.textMuted)),
            ),
          )
        else
          ...playlists.map((playlist) {
            final tracks = List<Map<String, dynamic>>.from(playlist['tracks'] as List? ?? []);
            return ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.playlist_play, color: AppColors.accent),
              ),
              title: Text(playlist['name'] as String? ?? 'Playlist', style: const TextStyle(color: AppColors.textMain, fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text('${tracks.length} songs', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textSubtle),
                onPressed: () => LocalLibrary.instance.deletePlaylist(playlist['id'] as String),
              ),
              onTap: () => Navigator.push(
                context,
                AppPageRoute<void>(
                  builder: (_) => TrackListScreen(
                    title: playlist['name'] as String? ?? 'Playlist',
                    tracks: tracks,
                    emptyMessage: 'This playlist is empty.',
                    onRemove: (t) => LocalLibrary.instance.removeTrackFromPlaylist(playlist['id'] as String, t['id'] as String),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRecentlyPlayedTab(List<Map<String, dynamic>> recent) {
    if (recent.isEmpty) {
      return const Center(
        child: Text('Nothing played yet — go explore and play music!', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: recent.length,
      itemBuilder: (context, index) {
        final t = recent[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppImage(t['artwork'] as String?, width: 48, height: 48, fit: BoxFit.cover),
          ),
          title: Text(t['title'] as String? ?? '', style: const TextStyle(color: AppColors.textMain, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1),
          subtitle: Text(t['artist'] as String? ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 12), maxLines: 1),
          trailing: const Icon(Icons.play_arrow_rounded, color: AppColors.accent, size: 22),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_ProfileTabBarDelegate oldDelegate) {
    return false;
  }
}

// ═══════════════════════════════════════════════
// PLAYER SCREEN
// ═══════════════════════════════════════════════

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    required this.track,
    required this.queue,
    required this.currentIndex,
    super.key,
  });

  final Map<String, dynamic> track;
  final List<Map<String, dynamic>> queue;
  final int currentIndex;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  late Map<String, dynamic> _currentTrack;
  late int _currentIndex;
  bool _isLiked = false;

  // Phase 7 fix (UI_PERFORMANCE_AUDIT.md issue #2): this screen
  // previously never stored or cancelled these 3 subscriptions to the
  // app-wide, whole-lifetime `audioPlayer` — every open+close of the
  // full player screen leaked 3 more listeners forever, each still
  // calling setState() on an already-unmounted State object (harmless
  // only because of the `if (mounted)` guards, but still pure wasted
  // work + a real, growing memory leak the longer a session runs).
  // Same disposal pattern LyricsScreen's `_positionSub` already uses
  // correctly elsewhere in this file.
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  @override
  void initState() {
    super.initState();
    _currentTrack = widget.track;
    _currentIndex = widget.currentIndex;
    _isLiked = LocalLibrary.instance.isLiked(_currentTrack['id'] as String? ?? '');

    // Listen to REAL player state
    _playerStateSub = audioPlayer.playerStateStream.listen((s) {
      if (mounted) setState(() => _isPlaying = s.playing);
    });
    _positionSub = audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSub = audioPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              AppColors.accent.withValues(alpha: 0.12),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Column(children: [
                    Text('PLAYING FROM',
                        style: TextStyle(fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.5))),
                    Text('Search',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.7))),
                  ]),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => showMoreOptionsSheet(context, _currentTrack),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Artwork
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Container(
                width: double.infinity, height: 320,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.25),
                        blurRadius: 40, offset: const Offset(0, 20)),
                  ],
                ),
                // Phase 7 (Part F): matches the mini-player's Hero tag
                // for the SAME track id, producing a real shared-
                // element "fly" transition from the mini-player into
                // this full artwork when opened via _openPlayer(). If
                // this screen was opened some other way (e.g. directly
                // from a Home/Search tap with no mini-player visible
                // yet), Hero degrades gracefully to a plain fade (no
                // matching source Hero to fly from).
                //
                // ArtworkFadeIn wraps it too so navigating between
                // tracks WITHIN this same screen (next/prev, which
                // don't re-push the route) still gets a gentle scale
                // +fade on every track change instead of an abrupt
                // artwork swap.
                child: Hero(
                  tag: 'artwork-${_currentTrack['id']}',
                  child: ArtworkFadeIn(
                    key: ValueKey(_currentTrack['id']),
                    child: AppImage(
                      (_currentTrack['artwork'] as String?) ?? '',
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(24),
                      errorIconColor: AppColors.accent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Track info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(children: [
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((_currentTrack['title'] as String?) ?? '',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text((_currentTrack['artist'] as String?) ?? '',
                          style: TextStyle(fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.7)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                IconButton(
                  // Phase 7 (Part F): LikePop plays a real one-shot
                  // "pop" (scale up then settle) whenever the track
                  // transitions to liked, matching the celebratory
                  // feel of every real music app's like button —
                  // previously this was a bare, unanimated Icon swap.
                  icon: LikePop(
                    liked: _isLiked,
                    child: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 28,
                      color: _isLiked ? AppColors.accent : Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  onPressed: () async {
                    unawaited(HapticFeedback.lightImpact());
                    final wasLiked = _isLiked;
                    await LocalLibrary.instance.toggleLiked(_currentTrack);
                    // Phase 7 (Part I): real like/unlike signal for the
                    // recommendation engine.
                    if (wasLiked) {
                      playbackSignalTracker.onUnliked(_currentTrack);
                    } else {
                      playbackSignalTracker.onLiked(_currentTrack);
                    }
                    if (mounted) {
                      setState(() {
                        _isLiked = LocalLibrary.instance.isLiked(_currentTrack['id'] as String);
                      });
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_add, size: 26),
                  tooltip: 'Add to playlist',
                  onPressed: () => showAddToPlaylistSheet(context, _currentTrack),
                ),
                IconButton(
                  icon: const Icon(Icons.lyrics_outlined, size: 24),
                  tooltip: 'Lyrics',
                  onPressed: () => Navigator.push(
                    context,
                    AppPageRoute<void>(
                      builder: (_) => LyricsScreen(track: _currentTrack),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // Progress — REAL player state
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    thumbColor: AppColors.accent,
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: _duration.inMilliseconds > 0
                        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0,
                    onChanged: (v) => audioPlayer.seek(
                        Duration(milliseconds: (v * _duration.inMilliseconds).round())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(_position),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                      Text(_fmt(_duration),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Shuffle — real toggle (Phase 8 fix; was an empty
                // onPressed stub with no state). Rebuilds shuffleOrder
                // (see core/player/queue_controller.dart) keeping the
                // currently-playing track first, so turning shuffle on
                // doesn't jump away from what's playing right now.
                IconButton(
                    icon: Icon(Icons.shuffle, size: 24,
                        color: isShuffleOn
                            ? AppColors.accent
                            : Colors.white.withValues(alpha: 0.6)),
                    tooltip: isShuffleOn ? 'Shuffle on' : 'Shuffle off',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        isShuffleOn = !isShuffleOn;
                        if (isShuffleOn) {
                          QueueController.rebuildShuffleOrder(
                              keepCurrentAt: currentQueueIndex);
                        }
                      });
                    }),
                IconButton(
                    icon: const Icon(Icons.skip_previous, size: 40),
                    onPressed: _prev),
                // Phase 7 (Part F): PressableScale gives real tactile
                // press feedback on the primary play/pause control
                // (previously a bare GestureDetector with zero visual
                // response to a press-down beyond the eventual state
                // change), and PlayPauseMorph replaces the unanimated
                // Icon swap with the same cross-fade+scale used
                // everywhere else this control appears.
                PressableScale(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (_isPlaying) {
                      audioPlayer.pause();
                    } else {
                      audioPlayer.play();
                    }
                  },
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentLight]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.4),
                            blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Center(
                      child: PlayPauseMorph(
                        isPlaying: _isPlaying,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.skip_next, size: 40),
                    onPressed: _next),
                // Repeat — real 3-state toggle (off -> one -> all ->
                // off), Phase 8 fix. See core/player/repeat_mode.dart
                // and _handleTrackCompleted() in this file for where
                // this state actually changes playback behavior (on
                // natural track completion, not on skip).
                IconButton(
                    icon: Icon(
                        repeatMode == RepeatMode.one
                            ? Icons.repeat_one
                            : Icons.repeat,
                        size: 24,
                        color: repeatMode == RepeatMode.off
                            ? Colors.white.withValues(alpha: 0.6)
                            : AppColors.accent),
                    tooltip: switch (repeatMode) {
                      RepeatMode.off => 'Repeat off',
                      RepeatMode.one => 'Repeat one',
                      RepeatMode.all => 'Repeat all',
                    },
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => repeatMode = repeatMode.next());
                    }),
              ],
            ),
            const Spacer(),
          ]),
        ),
      ),
    );
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> _next() async {
    if (widget.queue.isEmpty) return;
    if (isShuffleOn && shuffleOrder.length != widget.queue.length) {
      QueueController.rebuildShuffleOrder(keepCurrentAt: _currentIndex);
    }
    _currentIndex = QueueController.computeSkip(
      queueLength: widget.queue.length,
      currentIndex: _currentIndex,
      delta: 1,
      shuffleOn: isShuffleOn,
      order: shuffleOrder,
    );
    _currentTrack = widget.queue[_currentIndex];
    await _play();
  }

  Future<void> _prev() async {
    if (widget.queue.isEmpty) return;
    if (isShuffleOn && shuffleOrder.length != widget.queue.length) {
      QueueController.rebuildShuffleOrder(keepCurrentAt: _currentIndex);
    }
    _currentIndex = QueueController.computeSkip(
      queueLength: widget.queue.length,
      currentIndex: _currentIndex,
      delta: -1,
      shuffleOn: isShuffleOn,
      order: shuffleOrder,
    );
    _currentTrack = widget.queue[_currentIndex];
    await _play();
  }

  Future<void> _play() async {
    try {
      _log('[PLAYER] Resolving track: ${_currentTrack['id']}');
      final streamUrl =
          await musicRepository.getStream(_currentTrack['id'] as String);

      if (streamUrl != null) {
        _log('[PLAYER] Setting URL...');
        await audioPlayer.setUrl(streamUrl);
        _log('[PLAYER] Playing...');
        await audioPlayer.play();

        currentTrack = _currentTrack;
        currentQueueIndex = _currentIndex;
        // Keep the OS media session (notification/lock screen) in sync
        // with in-app next/previous taps too — see
        // core/audio/vshots_audio_handler.dart.
        audioHandler?.updateNowPlaying(_trackToMediaItem(_currentTrack));
        unawaited(LocalLibrary.instance.recordRecentlyPlayed(_currentTrack));
        // Phase 7 (Part I): PlayerScreen's own next/prev buttons are a
        // real, explicit user skip of whatever was playing before —
        // onTrackStarted's "different track started" auto-finalize
        // correctly records that as SignalType.skip.
        playbackSignalTracker.onTrackStarted(_currentTrack);
        if (mounted) {
          setState(() {
            _isLiked = LocalLibrary.instance
                .isLiked(_currentTrack['id'] as String? ?? '');
          });
        }
      } else {
        _log('[PLAYER] No stream could be resolved for this track.');
      }
    } catch (e) {
      _log('[PLAYER] Error: $e');
    }
  }

}

// ═══════════════════════════════════════════════
// SHARED BOTTOM SHEETS — reused by PlayerScreen and ForYouFeedScreen so
// "Add to playlist" / "Sleep timer" / "Share" / "Not interested" behave
// identically everywhere instead of having a second, drifting copy.
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
                  child: Text('Add to playlist',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No playlists yet. Create one from the Library tab first.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  )
                else
                  ...playlists.map((p) => ListTile(
                        leading: const Icon(Icons.playlist_play),
                        title: Text(p['name'] as String? ?? ''),
                        onTap: () async {
                          await LocalLibrary.instance
                              .addTrackToPlaylist(p['id'] as String, track);
                          // Phase 7 (Part I): a deliberate curation
                          // action — real, strong positive signal.
                          playbackSignalTracker.onAddedToPlaylist(track);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Added to ${p['name']}')),
                            );
                          }
                        },
                      )),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    },
  );
}

/// The "•••" / "more_vert" sheet — Sleep Timer, Share, and (only when
/// [onNotInterested] is provided, i.e. from a recommendation surface
/// like the For You feed, not from a user-initiated Search/Home play)
/// "Not interested in this artist" — a real feedback signal into
/// ForYouFeedService, not just a UI gesture with no effect.
void showMoreOptionsSheet(
  BuildContext context,
  Map<String, dynamic> track, {
  VoidCallback? onNotInterested,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('Sleep timer'),
              onTap: () {
                Navigator.pop(ctx);
                showSleepTimerSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(ctx);
                final title = (track['title'] as String?) ?? 'this track';
                final artist = (track['artist'] as String?) ?? '';
                SharePlus.instance.share(
                  ShareParams(text: 'Listening to "$title" by $artist on V Shots 🎵'),
                );
              },
            ),
            if (onNotInterested != null)
              ListTile(
                leading: const Icon(Icons.thumb_down_outlined),
                title: const Text('Not interested in this artist'),
                subtitle: const Text('We\'ll show fewer songs like this'),
                onTap: () {
                  Navigator.pop(ctx);
                  onNotInterested();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Got it — adjusting your recommendations')),
                  );
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}

/// The sleep-timer picker itself — a live countdown/"Off" state via
/// [SleepTimer.instance], shared by every entry point (PlayerScreen's
/// more-options sheet, For You's more-options sheet).
void showSleepTimerSheet(BuildContext context) {
  const presets = [5, 10, 15, 30, 45, 60];
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (ctx) {
      return ValueListenableBuilder<Duration?>(
        valueListenable: SleepTimer.instance.remaining,
        builder: (context, remaining, _) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Sleep timer',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                if (remaining != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(children: [
                      Text(
                        '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')} remaining',
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
                      ),
                      TextButton(
                        onPressed: () {
                          SleepTimer.instance.cancel();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Turn off timer'),
                      ),
                    ]),
                  ),
                ...presets.map((minutes) => ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: Text('$minutes minutes'),
                      onTap: () {
                        SleepTimer.instance.start(Duration(minutes: minutes));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Playback will pause in $minutes minutes')),
                        );
                      },
                    )),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    },
  );
}

// ═══════════════════════════════════════════════
// LYRICS SCREEN (LRCLIB — see core/lyrics/lyrics_service.dart)
// ═══════════════════════════════════════════════

class LyricsScreen extends StatefulWidget {
  const LyricsScreen({required this.track, super.key});
  final Map<String, dynamic> track;

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  LyricsResult? _result;
  bool _loading = true;
  int _activeLine = -1;
  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
    _load();
    _positionSub = audioPlayer.positionStream.listen(_onPosition);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await LyricsService.instance.fetch(
      trackName: (widget.track['title'] as String?) ?? '',
      artistName: (widget.track['artist'] as String?) ?? '',
      durationSeconds: widget.track['duration'] as int?,
    );
    if (mounted) setState(() { _result = result; _loading = false; });
  }

  void _onPosition(Duration position) {
    final synced = _result?.syncedLines;
    if (synced == null || synced.isEmpty) return;
    int newIndex = -1;
    for (var i = 0; i < synced.length; i++) {
      if (synced[i].timestamp <= position) {
        newIndex = i;
      } else {
        break;
      }
    }
    if (newIndex != _activeLine && mounted) {
      setState(() => _activeLine = newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lyrics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final result = _result;
    if (result == null || !result.hasAny) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lyrics_outlined, size: 56, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              Text(
                'Lyrics not available for this track',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      );
    }

    if (result.instrumental) {
      return Center(
        child: Text('🎵 Instrumental — no lyrics',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
      );
    }

    if (result.hasSynced) {
      final lines = result.syncedLines!;
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        itemCount: lines.length,
        itemBuilder: (ctx, i) {
          final isActive = i == _activeLine;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              lines[i].text.isEmpty ? '♪' : lines[i].text,
              style: TextStyle(
                fontSize: isActive ? 20 : 16,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? AppColors.accent : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          );
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Text(
        result.plainText ?? '',
        style: const TextStyle(fontSize: 16, height: 1.6),
      ),
    );
  }
}

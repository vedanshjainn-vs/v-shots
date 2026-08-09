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
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'core/audio/stream_resolver.dart';
import 'core/audio/vshots_audio_handler.dart';
import 'core/backend/auth_service.dart';
import 'core/backend/supabase_service.dart';
import 'core/cache/search_cache.dart';
import 'core/lyrics/lyrics_service.dart';
import 'core/player/sleep_timer.dart';
import 'core/theme/app_colors.dart';
import 'shared/widgets/app_image.dart';
import 'core/storage/local_library.dart';
import 'features/foryou/for_you_feed_screen.dart';
import 'features/foryou/for_you_feed_service.dart';
import 'features/library/local_import_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Non-blocking-on-failure by design — see supabase_service.dart's
  // file header for why a Supabase outage/misconfiguration must never
  // prevent the app from starting and playing music.
  await SupabaseService.initialize();
  // Local persistence (Liked Songs / Recently Played / Playlists /
  // taste-profile) — see core/storage/local_library.dart. Previously
  // all of this was plain in-memory globals, wiped on every restart.
  await LocalLibrary.instance.initialize();
  // google_sign_in v7 requires this exactly-once initialize() call
  // before any sign-in UI is shown — see auth_service.dart.
  await AuthService.instance.initializeGoogleSignIn();

  // Background playback / lock-screen controls — wraps the SAME
  // `audioPlayer` global this app already uses everywhere else (see
  // core/audio/vshots_audio_handler.dart for the full design rationale
  // on why this bridges rather than replaces the existing playback
  // code). Must be initialized before runApp().
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

// Single, app-wide shared YoutubeExplode instance. Previously THREE
// separate instances existed (this one, a second one for
// ForYouFeedService, and a third inside for_you_feed_screen.dart) —
// each opened its own HTTP client with no shared connection pooling,
// which is unnecessary overhead on every search/stream-resolve call.
// Made non-private (no leading underscore) specifically so other files
// (for_you_feed_screen.dart) can reuse this exact instance instead of
// constructing their own — see the refinement list's Section B #2.
final YoutubeExplode sharedYt = YoutubeExplode();

// "For You" swipe feed's recommendation service (see
// features/foryou/for_you_feed_service.dart) — now reuses the single
// shared instance above instead of constructing its own.
final forYouFeedService = ForYouFeedService(sharedYt);

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
Future<void> _playAdjacentInQueue(BuildContext? context, int delta) async {
  if (currentQueue.isEmpty) return;
  final nextIndex =
      (currentQueueIndex + delta + currentQueue.length) % currentQueue.length;
  final track = currentQueue[nextIndex];
  if (context != null && context.mounted) {
    await playTrack(context, track, currentQueue, nextIndex);
  } else {
    // No BuildContext available (e.g. triggered from a lock-screen tap
    // while the app has no visible Scaffold to attach a SnackBar to) —
    // resolve and play directly without the loading-snackbar UX.
    try {
      final streamUrl = await resolveAudioStreamUrlLogged(
        sharedYt,
        track['id'] as String,
        tag: 'SKIP',
      );
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
    } catch (e) {
      _log('[SKIP] Background skip failed: $e');
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
          MaterialPageRoute(builder: (_) => const MainShell()),
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
                  gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentLight]),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.accent.withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: const Icon(Icons.music_note,
                    size: 52, color: Colors.white),
              ),
              const SizedBox(height: 28),
              const Text('V Shots',
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// MAIN SHELL
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
    // Listen to real player state for mini player
    audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          isCurrentlyPlaying = state.playing;
        });
      }
    });

    // Route OS media-session commands (lock screen / notification /
    // headset / Android Auto skip buttons) back to the app's real
    // queue-navigation logic — see core/audio/vshots_audio_handler.dart
    // and _playAdjacentInQueue's doc comment for the full design.
    audioHandler?.onSkipNext = () => _playAdjacentInQueue(context, 1);
    audioHandler?.onSkipPrevious = () => _playAdjacentInQueue(context, -1);

    // Auto-advance to the next track when the current one finishes.
    // ⚠️ Real gap found and fixed: this callback existed in
    // VShotsAudioHandler (wired to just_audio's processingStateStream)
    // but was never actually assigned anywhere in the app — meaning a
    // song finishing playback did nothing at all; playback would just
    // silently stop rather than advancing to the next queued track.
    // Wired here (not inside PlayerScreen) specifically so auto-advance
    // keeps working even when the user has navigated away from the
    // full-screen player back to Home/Search/Library — matching how
    // every real music app behaves (music keeps playing/advancing in
    // the background regardless of which screen is currently open).
    audioHandler?.onTrackCompleted = () => _playAdjacentInQueue(context, 1);
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
              SearchScreen(),
              LibraryScreen(),
              ProfileScreen(),
            ],
          ),
          // Mini-player is hidden on the Discover tab (index 1):
          // ForYouFeedScreen is already a full-screen immersive
          // now-playing surface (its own artwork/title/progress/
          // play-pause are the primary content, not a secondary
          // overlay) — stacking the global mini-player on top of it
          // duplicated playback controls and ate into the swipeable
          // card's visible area for no benefit. Every other tab keeps
          // the mini-player exactly as before.
          if (currentTrack != null && _index != 1)
            Positioned(
              left: 8, right: 8, bottom: 72,
              child: _MiniPlayer(
                track: currentTrack!,
                onTap: () => _openPlayer(context),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.background.withOpacity(0.95),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome_rounded),
              label: 'Discover'),
          NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search_rounded),
              label: 'Search'),
          NavigationDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music_rounded),
              label: 'Library'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile'),
        ],
      ),
    );
  }

  void _openPlayer(BuildContext context) {
    if (currentTrack == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
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
                parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
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
          color: AppColors.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4), blurRadius: 12),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            AppImage(
              (track['artwork'] as String?) ?? '',
              width: 48,
              height: 48,
              borderRadius: BorderRadius.circular(8),
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
                          color: Colors.white.withOpacity(0.6), fontSize: 12)),
                ],
              ),
            ),
            // Use StreamBuilder for real state
            StreamBuilder<PlayerState>(
              stream: audioPlayer.playerStateStream,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data?.playing ?? false;
                return IconButton(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 32),
                  onPressed: () {
                    if (isPlaying) {
                      audioPlayer.pause();
                    } else {
                      audioPlayer.play();
                    }
                  },
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// HELPER: Clean title
// ═══════════════════════════════════════════════

String cleanTitle(String title, String artist) {
  var c = title;
  if (c.startsWith('$artist - ')) c = c.substring(artist.length + 3);
  c = c
      .replaceAll(RegExp(r'\s*\(Official.*?\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*\[Official.*?\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*\(Lyric.*?\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*\[Lyric.*?\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*\(Audio.*?\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*\[Audio.*?\]', caseSensitive: false), '')
      .trim();
  return c.isEmpty ? title : c;
}

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
  HapticFeedback.selectionClick();

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

    // Step 2: Resolve stream (multi-client fallback — see
    // core/audio/stream_resolver.dart for why this must never be a
    // plain, unfixed getManifest() call).
    _log('[YT] Resolving stream for: ${track['id']}');
    final streamUrl = await resolveAudioStreamUrlLogged(
      sharedYt,
      track['id'] as String,
      tag: 'PLAYBACK',
    );

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
  _HomeSectionState({required this.query, required this.title});
  final String query;
  final String title;
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
  late final List<_HomeSectionState> _sections = [
    _HomeSectionState(query: 'trending music today official audio', title: 'Trending Now'),
    _HomeSectionState(query: 'new music releases official audio', title: 'New Releases'),
    if (forYouFeedService.hasTasteProfile)
      _HomeSectionState(
        query: forYouFeedService.personalizedQueryForHome(),
        title: 'Made For You',
      ),
    _HomeSectionState(query: 'bollywood hit songs official audio', title: 'Bollywood'),
    _HomeSectionState(query: 'punjabi hit songs official audio', title: 'Punjabi'),
    _HomeSectionState(query: 'hindi songs official audio', title: 'Hindi'),
    _HomeSectionState(query: 'english pop songs official audio', title: 'English'),
    _HomeSectionState(query: 'hip hop rap songs official audio', title: 'Hip-Hop'),
    _HomeSectionState(query: 'edm dance party songs official audio', title: 'EDM & Party'),
    _HomeSectionState(query: 'chill lofi songs official audio', title: 'Chill & Lofi'),
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
    // Stale-while-revalidate: show a cached result instantly if we
    // have one (even if it's a little stale), then quietly refresh in
    // the background — this is what makes reopening the app or
    // switching back to Home feel instant instead of re-shimmering a
    // query that was already answered moments ago.
    //
    // forceRefresh (pull-to-refresh) skips the cache entirely so the
    // user gets genuinely fresh results on demand, not just whatever
    // was cached up to 5 minutes ago.
    final cached = forceRefresh ? null : SearchCache.instance.get(section.query);
    if (cached != null) {
      if (mounted) {
        setState(() {
          section.tracks = cached;
          section.status = _SectionStatus.loaded;
        });
      }
      if (SearchCache.instance.isFresh(section.query)) {
        return; // cache is fresh enough, no need to hit the network
      }
      // else: fall through and refresh quietly (status stays "loaded"
      // so the UI doesn't flash back to a loading/shimmer state for
      // data the user can already see).
    } else if (mounted) {
      setState(() => section.status = _SectionStatus.loading);
    }

    try {
      final results = await _search(section.query);
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
      // If we had cached data, silently keep showing it rather than
      // surfacing a background-refresh failure as a hard error.
    }
  }

  Future<List<Map<String, dynamic>>> _search(String q) async {
    final results = await sharedYt.search.search(q);
    return results
        .whereType<Video>()
        .where((v) {
          final t = v.title.toLowerCase();
          final dur = v.duration?.inMinutes ?? 0;
          if (dur > 15) return false;
          if (t.contains('podcast') || t.contains('compilation')) return false;
          return true;
        })
        .take(15)
        .map((v) => {
              'id': v.id.value,
              'title': cleanTitle(v.title, v.author),
              'artist': v.author,
              'artwork': v.thumbnails.highResUrl.toString(),
              'duration': v.duration?.inSeconds ?? 0,
            })
        .toList();
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
                  gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentLight]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.music_note, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Text('V Shots', style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(greeting, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('What do you want to listen to?',
                    style: TextStyle(color: Colors.white.withOpacity(0.6))),
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
    switch (section.status) {
      case _SectionStatus.loading:
        return _shimmerSliver();
      case _SectionStatus.error:
        return _errorSliver(section);
      case _SectionStatus.loaded:
        // A section that resolved with too few results to look
        // intentional (e.g. an odd query returning 1-2 hits) is
        // simply omitted, same behavior as before.
        if (section.tracks.length < 3) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return _tracksSliver(section);
    }
  }

  Widget _shimmerSliver() {
    return SliverToBoxAdapter(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      ]),
    );
  }

  /// Real error/retry UI — previously a failed section silently
  /// rendered NOTHING (an empty gap in the scroll view), giving no
  /// indication anything had gone wrong or how to recover.
  Widget _errorSliver(_HomeSectionState section) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Icon(Icons.wifi_off, color: Colors.white.withOpacity(0.5)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Couldn\'t load "${section.title}"',
                  style: TextStyle(color: Colors.white.withOpacity(0.7))),
            ),
            TextButton(
              onPressed: () => _loadSection(section),
              child: const Text('Retry'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tracksSliver(_HomeSectionState section) {
    final isPersonalized = section.title == 'Made For You';
    return SliverToBoxAdapter(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
          child: Row(children: [
            if (isPersonalized) ...[
              Icon(Icons.auto_awesome, size: 18, color: AppColors.accent),
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
              return GestureDetector(
                onTap: () => playTrack(context, track, section.tracks, i),
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
                            errorIconColor: AppColors.accent,
                          ),
                          Positioned(
                            right: 8, bottom: 8,
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
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
                            color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
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

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _searched = false;

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

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() { _loading = true; _searched = true; });

    unawaited(LocalLibrary.instance.recordRecentSearch(q));

    try {
      final results = await sharedYt.search.search(q);
      if (mounted) {
        setState(() {
          _results = results
              .whereType<Video>()
              .where((v) {
                final t = v.title.toLowerCase();
                final dur = v.duration?.inMinutes ?? 0;
                if (dur > 15) return false;
                if (t.contains('podcast') || t.contains('compilation')) return false;
                return true;
              })
              .take(30)
              .map((v) => {
                    'id': v.id.value,
                    'title': cleanTitle(v.title, v.author),
                    'artist': v.author,
                    'artwork': v.thumbnails.highResUrl.toString(),
                    'duration': v.duration?.inSeconds ?? 0,
                  })
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _results = []; _loading = false; });
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _controller,
            onSubmitted: _search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search songs, artists...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _searched
              ? _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 40, color: Colors.white.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text('No results for "${_controller.text}"',
                              style: TextStyle(color: Colors.white.withOpacity(0.5))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      itemBuilder: (ctx, i) {
                        final track = _results[i];
                        return ListTile(
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
                              style: TextStyle(color: Colors.white.withOpacity(0.6))),
                          onTap: () => playTrack(context, track, _results, i),
                        );
                      },
                    )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (LocalLibrary.instance.recentSearches.value.isNotEmpty) ...[
                      const Text('Recent Searches',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ...LocalLibrary.instance.recentSearches.value.take(5).map((s) => ListTile(
                            leading: Icon(Icons.history, color: Colors.white.withOpacity(0.5)),
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
                          .map((c) => GestureDetector(
                                onTap: () {
                                  _controller.text = c.$1;
                                  _search(c.$1);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: c.$3.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: c.$3.withOpacity(0.3)),
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
              MaterialPageRoute(
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
              MaterialPageRoute(
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
              MaterialPageRoute(
                builder: (_) => TrackListScreen(
                  title: 'Recently Played',
                  tracks: lib.recentlyPlayed.value,
                  emptyMessage: 'Nothing played yet — go play something!',
                  onClearAll: () => LocalLibrary.instance.clearRecentlyPlayed(),
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
              MaterialPageRoute(builder: (_) => const PlaylistsScreen()),
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
                Icon(Icons.library_music, size: 48, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 12),
                Text('Your library is empty',
                    style: TextStyle(color: Colors.white.withOpacity(0.4))),
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
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$count', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
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
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
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
                      style: TextStyle(color: Colors.white.withOpacity(0.6))),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play file: $e')),
      );
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
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
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
                      color: const Color(0xFF2196F3).withOpacity(0.12),
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
                    MaterialPageRoute(
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

// ═══════════════════════════════════════════════
// PROFILE SCREEN
// ═══════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _busy = true);
    final result = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!)),
      );
    }
    // No need to manually setState on success — SupabaseService's auth
    // state is read fresh in build() below, and the sign-in flow
    // itself already awaited completion.
    setState(() {});
  }

  Future<void> _handleSignOut() async {
    await AuthService.instance.signOut();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final isSignedIn = user != null;
    final displayName = (user?.userMetadata?['full_name'] as String?) ??
        (user?.userMetadata?['name'] as String?) ??
        'V Shots User';
    final email = user?.email ?? 'Not signed in';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Column(children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.surface,
              backgroundImage:
                  (user?.userMetadata?['avatar_url'] as String?) != null
                      ? NetworkImage(user!.userMetadata!['avatar_url'] as String)
                      : null,
              child: (user?.userMetadata?['avatar_url'] as String?) == null
                  ? Text(displayName.isNotEmpty ? displayName[0] : 'V',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.8)))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(displayName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            Text(email,
                style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ])),
          const SizedBox(height: 24),
          if (!isSignedIn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _handleGoogleSignIn,
                icon: _busy
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login),
                label: Text(_busy ? 'Signing in...' : 'Sign in with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          _item(Icons.workspace_premium, 'Upgrade to Premium', AppColors.accent),
          _item(Icons.settings, 'Settings'),
          _item(Icons.help_outline, 'Help & Support'),
          _item(Icons.privacy_tip_outlined, 'Privacy Policy'),
          _item(Icons.description_outlined, 'Terms of Service'),
          const SizedBox(height: 16),
          if (isSignedIn)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: _handleSignOut,
            ),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String label, [Color? color]) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white.withOpacity(0.7)),
      title: Text(label),
      trailing: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
    );
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

  @override
  void initState() {
    super.initState();
    _currentTrack = widget.track;
    _currentIndex = widget.currentIndex;
    _isLiked = LocalLibrary.instance.isLiked(_currentTrack['id'] as String? ?? '');

    // Listen to REAL player state
    audioPlayer.playerStateStream.listen((s) {
      if (mounted) setState(() => _isPlaying = s.playing);
    });
    audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    audioPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
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
              AppColors.accent.withOpacity(0.12),
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
                            color: Colors.white.withOpacity(0.5))),
                    Text('Search',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.7))),
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
                        color: AppColors.accent.withOpacity(0.25),
                        blurRadius: 40, offset: const Offset(0, 20)),
                  ],
                ),
                child: AppImage(
                  (_currentTrack['artwork'] as String?) ?? '',
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(24),
                  errorIconColor: AppColors.accent,
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
                              color: Colors.white.withOpacity(0.7)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                IconButton(
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 28,
                    color: _isLiked ? AppColors.accent : Colors.white.withOpacity(0.7),
                  ),
                  onPressed: () async {
                    await LocalLibrary.instance.toggleLiked(_currentTrack);
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
                    MaterialPageRoute(
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
                    inactiveTrackColor: Colors.white.withOpacity(0.1),
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
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                      Text(_fmt(_duration),
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
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
                IconButton(
                    icon: Icon(Icons.shuffle, size: 24,
                        color: Colors.white.withOpacity(0.6)),
                    onPressed: () {}),
                IconButton(
                    icon: const Icon(Icons.skip_previous, size: 40),
                    onPressed: _prev),
                GestureDetector(
                  onTap: () {
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
                            color: AppColors.accent.withOpacity(0.4),
                            blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 36, color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.skip_next, size: 40),
                    onPressed: _next),
                IconButton(
                    icon: Icon(Icons.repeat, size: 24,
                        color: Colors.white.withOpacity(0.6)),
                    onPressed: () {}),
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
    _currentIndex = (_currentIndex + 1) % widget.queue.length;
    _currentTrack = widget.queue[_currentIndex];
    await _play();
  }

  Future<void> _prev() async {
    if (widget.queue.isEmpty) return;
    _currentIndex = (_currentIndex - 1 + widget.queue.length) % widget.queue.length;
    _currentTrack = widget.queue[_currentIndex];
    await _play();
  }

  Future<void> _play() async {
    try {
      _log('[PLAYER] Resolving track: ${_currentTrack['id']}');
      final streamUrl = await resolveAudioStreamUrlLogged(
        sharedYt,
        _currentTrack['id'] as String,
        tag: 'PLAYER',
      );

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
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  )
                else
                  ...playlists.map((p) => ListTile(
                        leading: const Icon(Icons.playlist_play),
                        title: Text(p['name'] as String? ?? ''),
                        onTap: () async {
                          await LocalLibrary.instance
                              .addTrackToPlaylist(p['id'] as String, track);
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
                color: Colors.white.withOpacity(0.2),
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
                        style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
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
              Icon(Icons.lyrics_outlined, size: 56, color: Colors.white.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text(
                'Lyrics not available for this track',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ],
          ),
        ),
      );
    }

    if (result.instrumental) {
      return Center(
        child: Text('🎵 Instrumental — no lyrics',
            style: TextStyle(color: Colors.white.withOpacity(0.5))),
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
                color: isActive ? AppColors.accent : Colors.white.withOpacity(0.5),
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

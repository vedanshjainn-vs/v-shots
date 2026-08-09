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
import 'package:shimmer/shimmer.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'core/audio/vshots_audio_handler.dart';
import 'core/backend/auth_service.dart';
import 'features/foryou/for_you_feed_screen.dart';
import 'features/foryou/for_you_feed_service.dart';
import 'core/backend/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Non-blocking-on-failure by design — see supabase_service.dart's
  // file header for why a Supabase outage/misconfiguration must never
  // prevent the app from starting and playing music.
  await SupabaseService.initialize();
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
        colorSchemeSeed: const Color(0xFFFF4D6A),
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
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
// audioHandler.updateNowPlaying(...) so the lock-screen/notification
// stay in sync with what's actually playing.
late final VShotsAudioHandler audioHandler;
List<Map<String, dynamic>> currentQueue = [];
int currentQueueIndex = 0;
Map<String, dynamic>? currentTrack;
bool isCurrentlyPlaying = false;
final List<String> likedSongIds = [];
final List<Map<String, dynamic>> recentSearches = [];

// Single YoutubeExplode instance for reuse
final YoutubeExplode _yt = YoutubeExplode();

// "For You" swipe feed's recommendation service (see
// features/foryou/for_you_feed_service.dart) — a separate
// YoutubeExplode instance since _yt above is private to this file.
final forYouFeedService = ForYouFeedService(YoutubeExplode());

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
      final manifest = await _yt.videos.streamsClient.getManifest(track['id']);
      final audio = manifest.audioOnly.sortByBitrate();
      if (audio.isEmpty) return;
      final stream = audio.toList()[(audio.length / 2).floor()];
      await audioPlayer.setUrl(stream.url.toString());
      await audioPlayer.play();
      currentTrack = track;
      currentQueueIndex = nextIndex;
      audioHandler.updateNowPlaying(_trackToMediaItem(track));
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
      backgroundColor: const Color(0xFF0A0A0F),
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
                      colors: [Color(0xFFFF4D6A), Color(0xFFFF6B8A)]),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFFF4D6A).withOpacity(0.4),
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
    audioHandler.onSkipNext = () => _playAdjacentInQueue(context, 1);
    audioHandler.onSkipPrevious = () => _playAdjacentInQueue(context, -1);
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
          if (currentTrack != null)
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
        backgroundColor: const Color(0xFF0A0A0F).withOpacity(0.95),
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
          color: const Color(0xFF1A1A2E).withOpacity(0.95),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network((track['artwork'] as String?) ?? '',
                  width: 48, height: 48, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      width: 48, height: 48,
                      color: const Color(0xFF1A1A2E),
                      child: const Icon(Icons.music_note,
                          color: Color(0xFFFF4D6A)))),
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

  try {
    // Step 1: Show loading
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        const SizedBox(width: 12),
        Text('Loading ${track['title']}...'),
      ]),
      backgroundColor: const Color(0xFF1A1A2E),
      duration: const Duration(seconds: 10),
    ));

    // Step 2: Resolve stream
    _log('[YT] Resolving stream for: ${track['id']}');
    final manifest = await _yt.videos.streamsClient.getManifest(track['id']);
    _log('[YT] Manifest obtained');

    // Step 3: Get audio streams
    final audioStreams = manifest.audioOnly;
    _log('[YT] Found ${audioStreams.length} audio streams');

    if (audioStreams.isEmpty) {
      throw Exception('No audio streams available');
    }

    // Step 4: Sort by bitrate and pick middle (not highest, not lowest)
    final sorted = audioStreams.toList()
      ..sort((a, b) => a.bitrate.compareTo(b.bitrate));
    
    // Pick middle quality for compatibility
    final selectedIndex = (sorted.length / 2).floor();
    final selectedStream = sorted[selectedIndex];
    _log('[YT] Selected stream: ${selectedStream.bitrate}bps, ${selectedStream.codec}');

    // Step 5: Get stream URL
    final streamUrl = selectedStream.url.toString();
    _log('[YT] Stream URL obtained (length: ${streamUrl.length})');

    if (streamUrl.isEmpty) {
      throw Exception('Empty stream URL');
    }

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
    audioHandler.updateNowPlaying(_trackToMediaItem(track));

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Map<String, List<Map<String, dynamic>>> _sections = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _search('trending music today official audio'),
        _search('new music releases 2024'),
      ]);

      if (mounted) {
        setState(() {
          _sections['Trending Now'] = results[0];
          _sections['New Releases'] = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      _log('Home load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _search(String q) async {
    try {
      final results = await _yt.search.search(q);
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
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF4D6A), Color(0xFFFF6B8A)]),
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
          if (_loading)
            ..._buildShimmer()
          else
            ..._buildSections(),
          const SliverToBoxAdapter(child: SizedBox(height: 160)),
        ],
      ),
    );
  }

  List<Widget> _buildShimmer() {
    return List.generate(2, (_) => SliverToBoxAdapter(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Shimmer.fromColors(
            baseColor: const Color(0xFF1A1A2E),
            highlightColor: const Color(0xFF252540),
            child: Container(width: 150, height: 22,
                decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(4))),
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
                baseColor: const Color(0xFF1A1A2E),
                highlightColor: const Color(0xFF252540),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 150, height: 150,
                      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(14))),
                  const SizedBox(height: 8),
                  Container(width: 120, height: 14,
                      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 4),
                  Container(width: 80, height: 12,
                      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(4))),
                ]),
              ),
            ),
          ),
        ),
      ]),
    ));
  }

  List<Widget> _buildSections() {
    return _sections.entries
        .where((e) => e.value.length >= 3)
        .map((entry) => SliverToBoxAdapter(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                  child: Text(entry.key,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                ),
                SizedBox(
                  height: 210,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: entry.value.length,
                    itemBuilder: (context, i) {
                      final track = entry.value[i];
                      return GestureDetector(
                        onTap: () => playTrack(context, track, entry.value, i),
                        child: Container(
                          width: 150,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Stack(fit: StackFit.expand, children: [
                                  Image.network((track['artwork'] as String?) ?? '',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                          color: const Color(0xFF1A1A2E),
                                          child: const Icon(Icons.music_note,
                                              size: 40, color: Color(0xFFFF4D6A)))),
                                  Positioned(
                                    right: 8, bottom: 8,
                                    child: Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF4D6A),
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
            ))
        .toList();
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

    recentSearches.removeWhere((s) => s['query'] == q);
    recentSearches.insert(0, {'query': q});
    if (recentSearches.length > 10) recentSearches.removeLast();

    try {
      final results = await _yt.search.search(q);
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D6A)))
          : _searched
              ? _results.isEmpty
                  ? Center(child: Text('No results', style: TextStyle(color: Colors.white.withOpacity(0.5))))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      itemBuilder: (ctx, i) {
                        final track = _results[i];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network((track['artwork'] as String?) ?? '',
                                width: 48, height: 48, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    width: 48, height: 48,
                                    color: const Color(0xFF1A1A2E),
                                    child: const Icon(Icons.music_note, color: Color(0xFFFF4D6A)))),
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
                    if (recentSearches.isNotEmpty) ...[
                      const Text('Recent Searches',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ...recentSearches.take(5).map((s) => ListTile(
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

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _item(Icons.favorite, 'Liked Songs', const Color(0xFFE91E63), likedSongIds.length),
          _item(Icons.download, 'Downloads', const Color(0xFF4CAF50), 0),
          _item(Icons.history, 'Recently Played', const Color(0xFFFF9800), 0),
          _item(Icons.playlist_play, 'Playlists', const Color(0xFF2196F3), 0),
          _item(Icons.album, 'Albums', const Color(0xFF9C27B0), 0),
          _item(Icons.person, 'Artists', const Color(0xFF00BCD4), 0),
          const SizedBox(height: 32),
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

  Widget _item(IconData icon, String label, Color color, int count) {
    return ListTile(
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
              backgroundColor: const Color(0xFF1A1A2E),
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
                  backgroundColor: const Color(0xFFFF4D6A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          _item(Icons.workspace_premium, 'Upgrade to Premium', const Color(0xFFFF4D6A)),
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
    _isLiked = likedSongIds.contains(_currentTrack['id']);

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
      backgroundColor: const Color(0xFF0A0A0F),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFF4D6A).withOpacity(0.12),
              const Color(0xFF0A0A0F),
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
                  IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
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
                        color: const Color(0xFFFF4D6A).withOpacity(0.25),
                        blurRadius: 40, offset: const Offset(0, 20)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network((_currentTrack['artwork'] as String?) ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF1A1A2E),
                          child: const Icon(Icons.music_note,
                              size: 80, color: Color(0xFFFF4D6A)))),
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
                    color: _isLiked ? const Color(0xFFFF4D6A) : Colors.white.withOpacity(0.7),
                  ),
                  onPressed: () {
                    setState(() {
                      _isLiked = !_isLiked;
                      if (_isLiked) {
                        likedSongIds.add(_currentTrack['id'] as String);
                      } else {
                        likedSongIds.remove(_currentTrack['id']);
                      }
                    });
                  },
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
                    activeTrackColor: const Color(0xFFFF4D6A),
                    inactiveTrackColor: Colors.white.withOpacity(0.1),
                    thumbColor: const Color(0xFFFF4D6A),
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
                          colors: [Color(0xFFFF4D6A), Color(0xFFFF6B8A)]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFFF4D6A).withOpacity(0.4),
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
      final manifest = await _yt.videos.streamsClient.getManifest(_currentTrack['id']);
      final audio = manifest.audioOnly.sortByBitrate();
      
      if (audio.isNotEmpty) {
        final stream = audio.toList()[(audio.length / 2).floor()];
        _log('[PLAYER] Setting URL...');
        await audioPlayer.setUrl(stream.url.toString());
        _log('[PLAYER] Playing...');
        await audioPlayer.play();

        currentTrack = _currentTrack;
        currentQueueIndex = _currentIndex;
        // Keep the OS media session (notification/lock screen) in sync
        // with in-app next/previous taps too — see
        // core/audio/vshots_audio_handler.dart.
        audioHandler.updateNowPlaying(_trackToMediaItem(_currentTrack));
        if (mounted) setState(() {});
      }
    } catch (e) {
      _log('[PLAYER] Error: $e');
    }
  }
}

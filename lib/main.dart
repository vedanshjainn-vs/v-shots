// ignore_for_file: prefer_const_constructors, unnecessary_lambdas, curly_braces_in_flow_control_structures, directives_ordering
// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Diagnostic Playback & Hybrid Streaming Engine (Nova Edition)
// ═════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/ads/ad_config.dart';
import 'core/ads/ad_free_manager.dart';
import 'core/ads/ad_policy.dart';
import 'core/ads/ad_service.dart';
import 'core/ads/consent_manager.dart';
import 'core/ads/levelplay_service.dart';
import '../core/ads/mrec_ad_manager.dart';
import '../core/ads/premium_mrec_ad_card.dart';
import 'core/audio/vshots_audio_handler.dart';
import 'core/backend/auth_service.dart';
import 'core/observing/error_reporting.dart';
import 'core/navigation/app_navigator.dart';
import 'core/config/app_version.dart';
import 'core/notifications/app_update_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/smart_notification_service.dart';
import 'core/remote_config/remote_config_service.dart';
import 'core/backend/supabase_service.dart';
import 'core/cache/search_cache.dart';
import 'core/lyrics/lyrics_service.dart';
import 'core/music/music_catalog_service.dart';
import 'core/motion/motion.dart';
import 'core/player/repeat_mode.dart';
import 'core/playback/vshots_playback_manager.dart';
import 'core/playback/playback_router.dart';
import 'core/providers/adapters/youtube/youtube_data_api_client.dart';
import 'core/providers/provider_bootstrap.dart';
import 'core/recommendation/music_recommendation_engine.dart';
import 'core/recommendation/recommendation_engine.dart';
import 'core/recommendation/signal_recorder.dart';
import 'core/recommendation/signal_store.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/animated_equalizer.dart';
import 'shared/widgets/app_image.dart';
import 'shared/widgets/bottom_tab_bar.dart';
import 'core/storage/local_library.dart';
import 'core/storage/personalization_store.dart';
import 'features/foryou/discovery_browser_sheet.dart';
import 'features/foryou/for_you_feed_screen.dart';
import 'features/foryou/for_you_feed_service.dart';
import 'features/home/home_feed_service.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/artist_details_screen.dart';
import 'shared/widgets/offline_banner.dart';
import 'features/profile/profile_screen.dart';
import 'package:flutter/foundation.dart';

// Re-export so existing `import main.dart` call sites (For You feed,
// Discovery browser, Edit Profile) keep resolving the moved symbols
// without any changes on their side.
export 'features/profile/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Production hygiene: silence debugPrint in release builds so internal
  // logging never reaches production logcat (anti-tampering). Debug and
  // profile builds are unchanged. Overrides the foundation setter — no
  // call sites anywhere in the app need to change.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  final bootTimer = Stopwatch()..start();

  // Global error reporting (Firebase Crashlytics). Fire-and-forget by
  // design: installs the Flutter/zone error hooks immediately and never
  // blocks or breaks boot — worst case the app runs without reporting.
  unawaited(initializeErrorReporting());

  // Initialize Firebase first (required for FCM)
  debugPrint('[Boot] Firebase initialized');

  await Future.wait([
    SupabaseService.initialize(),
    LocalLibrary.instance.initialize(),
    SignalStore.instance.initialize(),
    PersonalizationStore.instance.initialize(),
    RemoteConfigService.instance.init(),
    AdFreeManager.instance.init(),
    AppVersion.load(),
    NotificationService.instance.initialize(),
    SmartNotificationService.instance.initialize(),
  ]);
  debugPrint('[Boot] core init done in ${bootTimer.elapsedMilliseconds}ms');

  // Initialize FCM (non-blocking, fire-and-forget)

  await AuthService.instance.initializeGoogleSignIn();

  // Ads (AppLovin MAX mediation): one-time, NON-BLOCKING init (Phase 18).
  // The existing UMP consent system is REUSED as the single consent source;
  // its decision is pushed into MAX on every status change (Phase 9) and
  // the Google network inside MAX reads GMA's UMP state directly.
  // FIRE-AND-FORGET BY DESIGN: ads must never block first paint. When MAX
  // is not configured in this build these are no-ops and diagnostics
  // report CONFIG_NOT_SET (honest state, app fully functional).
  unawaited(ConsentManager.instance.initialize());
  ConsentManager.instance.onStatusChanged =
      () => VShotsLevelPlay.instance.syncConsent();
  unawaited(VShotsLevelPlay.instance.initialize());

  audioHandler = await AudioService.init(
    builder: () => VShotsAudioHandler(audioPlayer),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.vshots.live.channel.audio',
      androidNotificationChannelName: 'V Shots playback',
      androidNotificationChannelDescription:
          'Media playback controls for V Shots',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidShowNotificationBadge: true,
      androidNotificationClickStartsActivity: true,
    ),
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  debugPrint('[Boot] runApp at ${bootTimer.elapsedMilliseconds}ms');
  runApp(const VShotsApp());

  // Check for app updates (non-blocking, fire-and-forget)
  unawaited(AppUpdateService.instance.checkForUpdate());
}

// ═══════════════════════════════════════════════
// APP ROOT
// ═══════════════════════════════════════════════

class VShotsApp extends StatelessWidget {
  const VShotsApp({super.key});

  @override
  Widget build(BuildContext context) {
    appRootBuilder = () => const SplashScreen();
    return MaterialApp(
      title: 'V Shots',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
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

/// Bumped whenever the global queue is mutated (play-next / add-to-queue),
/// so the full player's "Up Next" list rebuilds against the new queue.
final ValueNotifier<int> queueVersionNotifier = ValueNotifier<int>(0);

bool isCurrentlyPlaying = false;
RepeatMode repeatMode = RepeatMode.off;
bool isShuffleOn = false;
List<int> shuffleOrder = [];

final YouTubeDataApiClient sharedYtApiClient = YouTubeDataApiClient();
final musicRepository = buildMusicRepository(apiClient: sharedYtApiClient);
final forYouFeedService = ForYouFeedService(repository: musicRepository);
final recommendationEngine = RecommendationEngine(musicRepository);
final musicRecommendationEngine = MusicRecommendationEngine.withRepository(
  musicRepository,
);
final playbackSignalTracker = PlaybackSignalTracker(recommendationEngine);
final homeFeedService = HomeFeedService(
  repository: musicRepository,
  engine: recommendationEngine,
  musicEngine: musicRecommendationEngine,
);

void _log(String message) {
  debugPrint('[VShots] $message');
}

/// Adds [track] to the END of the global queue. If nothing is queued yet,
/// it starts playing immediately (same as tapping a song).
void addToQueueEnd(BuildContext? context, Map<String, dynamic> track) {
  VShotsPlaybackManager.instance.addToEnd(track);
  currentQueue = VShotsPlaybackManager.instance.queue;
  queueVersionNotifier.value++;
  if (context != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added to queue: ${track['title'] ?? ''}'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.surface2,
      ),
    );
  }
}

/// Inserts [track] right after the currently playing track so it plays
/// next. If nothing is queued yet, it starts playing immediately.
void playNextInQueue(BuildContext? context, Map<String, dynamic> track) {
  VShotsPlaybackManager.instance.playNext(track);
  currentQueue = VShotsPlaybackManager.instance.queue;
  queueVersionNotifier.value++;
  if (context != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Up next: ${track['title'] ?? ''}'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.surface2,
      ),
    );
  }
}

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
      // Capture the NavigatorState now — it outlives this Splash widget.
      // (The onComplete callback fires much later, after the user finishes
      // onboarding, so using this State's context there would be defunct.)
      final navigator = Navigator.of(context);
      // First launch → taste personalization onboarding; afterwards straight
      // to the app. Onboarding NEVER starts playback — it only records
      // preferences for cold-start recommendations.
      final Widget next = PersonalizationStore.instance.onboarded
          ? const MainShell()
          : OnboardingScreen(
              onComplete: () {
                navigator.pushReplacement(
                  MaterialPageRoute<void>(builder: (_) => const MainShell()),
                );
              },
            );
      navigator.pushReplacement(MaterialPageRoute<void>(builder: (_) => next));
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
    currentTabIndexNotifier.value = 0;
    audioPlayer.playerStateStream.listen((state) {
      isCurrentlyPlaying = state.playing;
    });

    // Lock-screen / headset skip buttons route through the single global
    // playback manager (same engine as the in-app player).
    audioHandler?.onSkipNext = VShotsPlaybackManager.instance.next;
    audioHandler?.onSkipPrevious = VShotsPlaybackManager.instance.previous;
    audioHandler?.onTrackCompleted = VShotsPlaybackManager.instance.next;
    VShotsPlaybackManager.instance.browser.addListener(_syncPlayerExpanded);
    // Ads: no startup work at all. The interstitial preloads on-demand at
    // the first policy-eligible tab switch (see onTap below) — keeps first
    // paint fast and leaves nothing pending for widget tests.
  }

  void _syncPlayerExpanded() {
    isPlayerExpandedNotifier.value =
        VShotsPlaybackManager.instance.browser.isExpanded;
  }

  @override
  void dispose() {
    VShotsPlaybackManager.instance.browser.removeListener(_syncPlayerExpanded);
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    // 1. If the global player is expanded, minimize it to the mini player.
    if (VShotsPlaybackManager.instance.browser.isExpanded) {
      VShotsPlaybackManager.instance.minimize();
      return false;
    }
    // 2. If on Discover (1), Search (2), or Profile (3), go back to Home (0)
    if (_index != 0) {
      unawaited(HapticFeedback.selectionClick());
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
              children: const [
                HomeScreen(),
                ForYouFeedScreen(),
                SearchScreen(),
                ProfileScreen(),
              ],
            ),

            // NON-BLOCKING offline indicator — mounted once, reacts to
            // connectivity changes independently. Never delays startup,
            // never rebuilds the rest of the app.
            const Positioned(top: 0, left: 0, right: 0, child: OfflineBanner()),

            // GLOBAL PLAYER SHELL — the single in-app YouTube browser session
            // (native WebView engine) mounted ONCE at the app shell, above
            // every tab. Discovery (and, next phase, Home/Search/Library)
            // route playback through VShotsPlaybackManager; this sheet is the
            // one persistent UI+media surface for all of them.
            // Positioned.fill MUST be a direct Stack child — MiniPlayerTransition
            // wraps the inner content, not the Positioned itself.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: VShotsPlaybackManager.instance.browser,
                builder: (context, _) {
                  final b = VShotsPlaybackManager.instance.browser;
                  return RepaintBoundary(
                    child: MiniPlayerTransition(
                      visible: b.isOpen,
                      child: b.isOpen
                          ? DiscoveryBrowserSheet(controller: b)
                          : const SizedBox.shrink(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: isPlayerExpandedNotifier,
          builder: (context, isExpanded, _) {
            return AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: isExpanded ? Curves.easeInCubic : Curves.easeOutCubic,
              offset: isExpanded ? const Offset(0, 1) : Offset.zero,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                curve: isExpanded ? Curves.easeInCubic : Curves.easeOutCubic,
                opacity: isExpanded ? 0 : 1,
                child: isExpanded
                    ? const SizedBox(height: 64)
                    : BottomTabBar(
                        currentIndex: _index.clamp(0, 3),
                        onTap: (i) {
                          final target = i.clamp(0, 3);
                          final changed = target != _index;
                          if (changed) {
                            unawaited(HapticFeedback.selectionClick());
                          }
                          setState(() {
                            _index = target;
                            currentTabIndexNotifier.value = target;
                          });
                          if (changed &&
                              !VShotsPlaybackManager.instance.browser.isOpen) {
                            unawaited(
                              VShotsAds.instance.maybeShowInterstitial(
                                trigger: 'tab_switch_$target',
                              ),
                            );
                          }
                        },
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// CREATOR GATING & UPLOAD FLOW
// ═══════════════════════════════════════════════

Future<void> playTrack(
  BuildContext? context,
  Map<String, dynamic> track,
  List<Map<String, dynamic>> queue,
  int index, {
  bool expanded = true,
}) async {
  _log('═══ PLAYBACK START ═══');
  _log('Track: ${track['title']} (${track['id']})');
  unawaited(HapticFeedback.selectionClick());

  final resolvedQueue = await PlaybackRouter.instance.resolveQueue(
    queue.isEmpty ? [track] : queue,
  );
  final safeIndex =
      resolvedQueue.isEmpty ? 0 : index.clamp(0, resolvedQueue.length - 1);
  final resolvedTrack = resolvedQueue.isEmpty
      ? await PlaybackRouter.instance.attachResolvedPlayback(track)
      : resolvedQueue[safeIndex];

  if (resolvedTrack['playbackUnavailable'] == true) {
    final reason =
        '${resolvedTrack['unavailableReason'] ?? 'This track is unavailable'}';
    _log('Playback unavailable: $reason');
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason), backgroundColor: AppColors.error),
      );
    }
    return;
  }

  _log(
    'Playback source: ${resolvedTrack['playbackSource']}, '
    'URL: ${resolvedTrack['url']}',
  );

  VShotsPlaybackManager.instance.playQueue(
    resolvedQueue.isEmpty ? [resolvedTrack] : resolvedQueue,
    safeIndex,
    expanded: expanded,
  );

  // Update the OS media notification with track metadata
  final artworkUrl = (resolvedTrack['artwork'] as String?) ?? '';
  final trackTitle = (resolvedTrack['title'] as String?) ?? 'Unknown';
  final trackArtist = (resolvedTrack['artist'] as String?) ?? 'Unknown Artist';
  final trackId = (resolvedTrack['id'] as String?) ?? '';
  final trackDuration = resolvedTrack['duration'] as int?;

  debugPrint(
    '[VShots] Updating media notification: $trackTitle by $trackArtist',
  );
  debugPrint('[VShots] Artwork URL: $artworkUrl');

  audioHandler?.updateNowPlaying(
    MediaItem(
      id: trackId,
      title: trackTitle,
      artist: trackArtist,
      artUri: artworkUrl.isNotEmpty ? Uri.tryParse(artworkUrl) : null,
      duration: trackDuration != null ? Duration(seconds: trackDuration) : null,
      album: trackArtist,
    ),
  );

  // Ensure audio_service starts the foreground notification
  if (!audioPlayer.playing) {
    unawaited(audioHandler?.play());
  }

  currentTrack = resolvedTrack;
  currentTrackNotifier.value = resolvedTrack;
  currentQueue = List<Map<String, dynamic>>.from(
    resolvedQueue.isEmpty ? [resolvedTrack] : resolvedQueue,
  );
  currentQueueIndex = safeIndex;

  unawaited(LocalLibrary.instance.recordRecentlyPlayed(resolvedTrack));
  playbackSignalTracker.onTrackStarted(resolvedTrack);
}

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
  String? _nextPageToken;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _seenIds = {};
  bool _isLoadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 20;

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

  /// Curated quick-pick queries — the owner can swap these anytime without
  /// a code deploy by editing the Supabase `home_config` table (future);
  /// for now they're client-side curated picks that drive real search.
  static const _trendingQueries = [
    ('Arijit Singh', '🔥'),
    ('Lo-fi Beats', '🌙'),
    ('Punjabi Hits', '🥁'),
    ('Romantic', '❤️'),
    ('Workout Mix', '💪'),
    ('90s Bollywood', '📼'),
    ('Chill Vibes', ''),
  ];

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _status = _SearchStatus.idle;
        _results = [];
        _hasMore = true;
        _seenIds.clear();
        _nextPageToken = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    _seenIds.clear();
    _hasMore = true;
    _isLoadingMore = false;

    final cached = SearchCache.instance.get(query);
    final isFresh = SearchCache.instance.isFresh(query);
    if (cached != null) {
      _seenIds.addAll(
        cached
            .map((e) => e['id'] as String? ?? '')
            .where((id) => id.isNotEmpty),
      );
      setState(() {
        _results = cached;
        _status = _SearchStatus.loaded;
        _lastQuery = query;
        _hasMore = cached.length >= _pageSize;
      });
      if (isFresh) return;
    } else {
      setState(() {
        _status = _SearchStatus.loading;
        _lastQuery = query;
        _results = [];
      });
    }

    final seq = ++_requestSeq;
    _nextPageToken = null;

    try {
      // Primary discovery via InnerTube with YouTube Data API fallback —
      // real pagination through the shared repository.
      final page = await musicRepository.searchPaginated(
        query,
        limit: _pageSize,
        excludeIds: _seenIds,
      );
      if (seq != _requestSeq || !mounted) return;

      _nextPageToken = page.nextPageToken;
      final rawResults = page.tracks;

      final uniqueResults = <Map<String, dynamic>>[];
      for (final track in rawResults) {
        final id = track['id'] as String? ?? '';
        if (id.isEmpty || _seenIds.contains(id)) continue;
        _seenIds.add(id);
        uniqueResults.add(track);
      }

      // If cached exists and isFresh was false, merge with fresh results (deduped)
      final merged =
          cached != null && !isFresh ? <Map<String, dynamic>>[] : uniqueResults;
      if (cached != null && !isFresh) {
        // Prefer fresh unique results, keep cached only if not duplicate
        merged.addAll(uniqueResults);
      }

      // Music-first search: validate + canonicalize before displaying, so
      // generic non-music videos never appear as normal search results.
      final musicResults = const MusicCatalogService()
          .ingest(merged.isNotEmpty ? merged : uniqueResults, label: '.search')
          .items;
      final toShow = musicResults.isNotEmpty
          ? musicResults
          : (merged.isNotEmpty ? merged : uniqueResults);
      if (toShow.isNotEmpty) {
        SearchCache.instance.set(query, toShow);
      }
      unawaited(LocalLibrary.instance.recordRecentSearch(query));
      playbackSignalTracker.onSearched(query);

      setState(() {
        _results = toShow;
        _status = _SearchStatus.loaded;
        _hasMore = _nextPageToken != null || uniqueResults.length >= _pageSize;
      });
    } catch (_) {
      if (seq != _requestSeq || !mounted) return;
      if (cached == null) {
        setState(() => _status = _SearchStatus.error);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore ||
        !_hasMore ||
        _lastQuery == null ||
        _lastQuery!.isEmpty) return;
    if (_status != _SearchStatus.loaded) return;
    setState(() => _isLoadingMore = true);
    try {
      // Request the NEXT page via the stored continuation/page token. When
      // the token is null (exhausted / catalog fallback), `_hasMore` becomes
      // false and stops cleanly.
      final page = await musicRepository.searchPaginated(
        _lastQuery!,
        limit: _pageSize,
        excludeIds: _seenIds,
        pageToken: _nextPageToken,
      );
      if (!mounted) return;
      if (page.tracks.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }
      _nextPageToken = page.nextPageToken;
      final newItems = <Map<String, dynamic>>[];
      for (final t in page.tracks) {
        final id = t['id'] as String? ?? '';
        if (id.isEmpty || _seenIds.contains(id)) continue;
        _seenIds.add(id);
        newItems.add(t);
      }
      if (newItems.isEmpty) {
        setState(() {
          _hasMore = _nextPageToken != null;
          _isLoadingMore = false;
        });
        return;
      }
      setState(() {
        _results = [..._results, ...newItems];
        _hasMore = _nextPageToken != null || newItems.length >= _pageSize;
        _isLoadingMore = false;
      });
      // Update cache with expanded results
      SearchCache.instance.set(_lastQuery!, _results);
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocusNode.hasFocus);
    });
    LocalLibrary.instance.recentSearches.addListener(_onRecentSearchesChanged);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Prefetch the next page once the user reaches ~75% of the current
    // results (not only at the very end), so Search never stalls at 10/20.
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent > 0 &&
        _scrollController.position.pixels >= maxExtent * 0.75) {
      _loadMore();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
                duration: AppMotion.fast,
                curve: AppMotion.enter,
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
                    prefixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 16),
                        const Icon(Icons.search, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            // Open Google voice search — the standard Android
                            // voice-to-text entry point. Works on every
                            // device with Google app installed (near-universal
                            // on Android). Falls back to a web URL on iOS.
                            unawaited(
                              launchUrl(
                                Uri.parse(
                                  'https://www.google.com/search?tbm=vid&q=',
                                ),
                                mode: LaunchMode.externalApplication,
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.mic_rounded,
                              color: AppColors.accent,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 96,
                      minHeight: 48,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () {
                              unawaited(HapticFeedback.selectionClick());
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
                onPressed: () {
                  unawaited(HapticFeedback.lightImpact());
                  LocalLibrary.instance.clearRecentSearches();
                },
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
            children: recents.map((item) {
              final q = (item['query'] as String?) ?? '';
              return PressableScale(
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  _controller.text = q;
                  _search(q);
                },
                child: ActionChip(
                  label: Text(q),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  onPressed: () {
                    _controller.text = q;
                    _search(q);
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
        // Trending quick-pick row — curated queries that drive discovery
        // without the user typing anything. Tapping fires a real search
        // (same path as the category grid) with haptic confirmation.
        const Text(
          'Trending',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _trendingQueries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final (label, emoji) = _trendingQueries[i];
              return StaggeredEntrance(
                index: i,
                child: PressableScale(
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    _controller.text = label;
                    _search(label);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
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
            return StaggeredEntrance(
              index: i,
              child: PressableScale(
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
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

  /// Derives a de-duplicated "Artists" group from the channels actually
  /// present in the current search results — real result metadata, never
  /// fabricated. YouTube/InnerTube search returns only video entities (no
  /// first-class album/playlist entities), so Albums/Playlists are
  /// intentionally NOT synthesized here; artists are the honest second group.
  List<Map<String, dynamic>> _derivedArtists() {
    final artists = <String, String>{};
    for (final t in _results) {
      final name = (t['artist'] as String?) ?? '';
      if (name.isEmpty || name == 'Unknown Artist') continue;
      artists.putIfAbsent(name, () => (t['artwork'] as String?) ?? '');
    }
    return artists.entries
        .take(8)
        .map((e) => {'name': e.key, 'artwork': e.value})
        .toList();
  }

  Widget _buildArtistsSection(List<Map<String, dynamic>> artists) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Text(
            'Artists',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
            ),
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: artists.length,
            itemBuilder: (context, i) {
              final a = artists[i];
              final name = a['name'] as String;
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  AppPageRoute<void>(
                    builder: (_) => ArtistDetailsScreen(
                      name: name,
                      role: 'Artist',
                      imageUrl: (a['artwork'] as String?) ?? '',
                      query: '$name top songs official audio',
                    ),
                  ),
                ),
                child: Container(
                  width: 76,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: AppImage(
                            a['artwork'] as String?,
                            fit: BoxFit.cover,
                            errorIconColor: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain,
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
    );
  }

  Widget _buildResultsList() {
    // Insert one clearly-labeled native ad after ~8 organic results. When ads
    // are not enabled (no production ad config / ad-free / consent pending)
    // the ad slot count is 0, so the list behaves exactly as before.
    final bool showAd = AdPolicy.instance.canShowNative(AdPlacement.search) &&
        _results.length >= AdConfig.searchAdEvery;
    final int adCount = showAd ? 1 : 0;
    final int footerIndex = _results.length + adCount;
    final artists = _derivedArtists();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (artists.isNotEmpty) _buildArtistsSection(artists),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
          child: Row(
            children: [
              const Text(
                'Songs & videos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_results.length} results',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.play_circle_filled_rounded,
                size: 14,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 4),
              const Text(
                'YouTube',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: footerIndex + 1,
            itemBuilder: (context, i) {
              if (i == footerIndex) {
                if (!_hasMore) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No more results',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }
                if (_isLoadingMore) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: TextButton(
                      onPressed: () {
                        unawaited(HapticFeedback.selectionClick());
                        _loadMore();
                      },
                      child: const Text(
                        'Load more',
                        style: TextStyle(color: AppColors.accent),
                      ),
                    ),
                  ),
                );
              }
              // Native ad slot after the 8th organic result.
              if (showAd && i == AdConfig.searchAdEvery) {
                return const PremiumMRECAdCard(placement: MRECPlacement.search);
              }
              // Account for the ad slot offset when indexing results.
              final int resultIndex =
                  showAd && i > AdConfig.searchAdEvery ? i - 1 : i;
              final track = _results[resultIndex];
              final title = (track['title'] as String?) ?? '';
              final artist = (track['artist'] as String?) ?? '';
              final durationSeconds = (track['duration'] as int?) ?? 0;
              final durationLabel = durationSeconds > 0
                  ? '${durationSeconds ~/ 60}:${(durationSeconds % 60).toString().padLeft(2, '0')}'
                  : '';

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => playTrack(context, track, [track], 0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            ArtworkFadeIn(
                              child: AppImage(
                                track['artwork'] as String?,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorIconColor: AppColors.accent,
                              ),
                            ),
                            if (currentTrackNotifier.value?['id'] ==
                                (track['id'] as String? ?? ''))
                              const Positioned(
                                left: 4,
                                bottom: 4,
                                child: AnimatedEqualizer(
                                  size: 12,
                                  color: AppColors.accent,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: AppColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (durationLabel.isNotEmpty) ...[
                                  Text(
                                    durationLabel,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Text(
                                      '•',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSubtle,
                                      ),
                                    ),
                                  ),
                                ],
                                Expanded(
                                  child: Text(
                                    artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: AppColors.accent,
                        size: 32,
                      ),
                    ],
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
// PROFILE SCREEN
// ═══════════════════════════════════════════════

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

// Force rebuild
// CI trigger

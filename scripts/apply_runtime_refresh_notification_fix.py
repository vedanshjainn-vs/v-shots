from pathlib import Path

ROOT = Path('.')


def patch_main() -> None:
    p = ROOT / 'lib/main.dart'
    text = p.read_text()
    if "import 'core/recommendation/music_region_profile.dart';" not in text:
        text = text.replace(
            "import 'core/recommendation/music_recommendation_engine.dart';\n",
            "import 'core/recommendation/music_recommendation_engine.dart';\nimport 'core/recommendation/music_region_profile.dart';\n",
            1,
        )

    # Critical startup rule: paint Flutter immediately. A native/plugin/service
    # failure must never prevent the first Flutter frame from appearing.
    main_anchor = '''void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootTimer = Stopwatch()..start();
'''
    main_replacement = '''void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootTimer = Stopwatch()..start();

  // Paint the Flutter shell before any network, storage, notification, auth,
  // ads, or audio-service initialization. This eliminates black-screen hangs
  // caused by a plugin initialization failure before runApp(). The later
  // runApp() remains as a harmless final rebuild after bootstrap completes.
  runApp(const VShotsApp());
'''
    if 'runApp(const VShotsApp());\n\n  // Initialize Firebase first' not in text:
        if main_anchor not in text:
            raise SystemExit('main startup anchor not found')
        text = text.replace(main_anchor, main_replacement, 1)

    # Existing bootstrap is retained but all blocking stages are bounded.
    old_wait = '''  await Future.wait([
    SupabaseService.initialize(),
    LocalLibrary.instance.initialize(),
    SignalStore.instance.initialize(),
    PersonalizationStore.instance.initialize(),
    RemoteConfigService.instance.init(),
    AdFreeManager.instance.init(),
    AppVersion.load(),
  ]);

  // NotificationService MUST be ready before SmartNotificationService: the
  // scheduler calls into it during initialization. Running both in the same
  // Future.wait caused the first schedule build to race the plugin init and
  // silently schedule zero notifications.
  await SmartNotificationService.instance.initialize();
'''
    new_wait = '''  try {
    await Future.wait([
      SupabaseService.initialize(),
      LocalLibrary.instance.initialize(),
      SignalStore.instance.initialize(),
      PersonalizationStore.instance.initialize(),
      RemoteConfigService.instance.init(),
      AdFreeManager.instance.init(),
      AppVersion.load(),
    ]).timeout(const Duration(seconds: 12));
  } catch (e, st) {
    debugPrint('[Boot] non-fatal core init failure: $e\\n$st');
  }

  try {
    await NotificationService.instance
        .initialize()
        .timeout(const Duration(seconds: 8));
    await SmartNotificationService.instance
        .initialize()
        .timeout(const Duration(seconds: 8));
  } catch (e, st) {
    debugPrint('[Boot] non-fatal notification init failure: $e\\n$st');
  }
'''
    if old_wait in text:
        text = text.replace(old_wait, new_wait, 1)

    old_auth = '''  await AuthService.instance.initializeGoogleSignIn();
'''
    new_auth = '''  try {
    await AuthService.instance
        .initializeGoogleSignIn()
        .timeout(const Duration(seconds: 8));
  } catch (e, st) {
    debugPrint('[Boot] non-fatal Google Sign-In init failure: $e\\n$st');
  }
'''
    if old_auth in text:
        text = text.replace(old_auth, new_auth, 1)

    old_audio = '''  audioHandler = await AudioService.init(
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
'''
    new_audio = '''  try {
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
    ).timeout(const Duration(seconds: 10));
  } catch (e, st) {
    debugPrint('[Boot] non-fatal AudioService init failure: $e\\n$st');
  }
'''
    if old_audio in text:
        text = text.replace(old_audio, new_audio, 1)

    marker = "  debugPrint('[Boot] runApp at ${bootTimer.elapsedMilliseconds}ms');\n"
    if 'unawaited(MusicRegionProfile.initialize());' not in text:
        if marker not in text:
            raise SystemExit('main runApp anchor not found')
        text = text.replace(
            marker,
            "  unawaited(MusicRegionProfile.initialize());\n" + marker,
            1,
        )
    p.write_text(text)


def patch_home() -> None:
    p = ROOT / 'lib/features/home/home_screen.dart'
    text = p.read_text()
    old = '''  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Silent refresh when the user returns, rate-limited.
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastRefresh == null ||
          now.difference(_lastRefresh!) >= _minRefreshInterval) {
        _lastRefresh = now;
        unawaited(_load(forceRefresh: true));
      }
    }
  }
'''
    new = '''  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Explicit pull-to-refresh is the full Home refresh action.
  }
'''
    if old in text:
        text = text.replace(old, new, 1)
    text = text.replace(
        '  DateTime? _lastRefresh;\n  static const Duration _minRefreshInterval = Duration(minutes: 5);\n',
        '',
        1,
    )
    p.write_text(text)


def patch_discover() -> None:
    p = ROOT / 'lib/core/discover/discover_feed_engine.dart'
    text = p.read_text()
    if "import '../recommendation/smart_listening_service.dart';" not in text:
        text = text.replace(
            "import '../recommendation/recommendation_service.dart';\n",
            "import '../recommendation/recommendation_service.dart';\n"
            "import '../recommendation/smart_listening_service.dart';\n",
            1,
        )
    anchor = '    final engineResults = await Future.wait([\n'
    if anchor in text and 'smart-listening-home' not in text:
        injection = '''    final smartHome = SmartListeningService.instance;
    final smartHomePool = smartHome.isConfigured
        ? smartHome.nextSongQueue(seed: null, count: 24).then<List<_ScoredCandidate>>(
            (tracks) => tracks
                .map(
                  (t) => _ScoredCandidate(
                    t,
                    DiscoverBucket.personal,
                    'smart-listening-home',
                  ),
                )
                .toList(),
          ).catchError((Object e) {
            debugPrint('[DiscoverEngine] smart Home pool failed: $e');
            return <_ScoredCandidate>[];
          })
        : Future.value(const <_ScoredCandidate>[]);

'''
        text = text.replace(anchor, injection + anchor, 1)
        text = text.replace(
            anchor,
            '    final engineResults = await Future.wait<List<_ScoredCandidate>>([\n'
            '      smartHomePool,\n',
            1,
        )
    p.write_text(text)


if __name__ == '__main__':
    patch_main()
    patch_home()
    patch_discover()
    print('Runtime refresh/notification/region patch applied.')
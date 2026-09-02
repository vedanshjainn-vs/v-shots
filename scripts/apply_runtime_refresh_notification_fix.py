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
    old_boot = '''    AdFreeManager.instance.init(),
    AppVersion.load(),
    NotificationService.instance.initialize(),
    SmartNotificationService.instance.initialize(),
  ]);
'''
    new_boot = '''    AdFreeManager.instance.init(),
    AppVersion.load(),
  ]);

  // NotificationService must be ready before the smart scheduler starts.
  await NotificationService.instance.initialize();
  await SmartNotificationService.instance.initialize();
'''
    if old_boot in text:
        text = text.replace(old_boot, new_boot, 1)
    marker = "  debugPrint('[Boot] runApp at ${bootTimer.elapsedMilliseconds}ms');\n"
    if 'unawaited(MusicRegionProfile.initialize());' not in text:
        if marker not in text:
            raise SystemExit('main runApp anchor not found')
        text = text.replace(
            marker,
            "  // Resolve network country after core boot without delaying first paint.\n"
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
    // Returning from another screen must not re-fetch/rebuild the whole Home.
    // Pull-to-refresh remains the explicit full refresh action.
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
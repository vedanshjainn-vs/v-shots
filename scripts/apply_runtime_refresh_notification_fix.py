from pathlib import Path

ROOT = Path('.')


def patch(path: str, old: str, new: str, label: str, required: bool = True) -> None:
    p = ROOT / path
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        if required:
            raise SystemExit(f'{label}: anchor not found in {path}')
        return
    p.write_text(text.replace(old, new, 1))


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

  // NotificationService must finish before the smart scheduler starts. The
  // previous Future.wait race could schedule into an uninitialized plugin.
  await NotificationService.instance.initialize();
  await SmartNotificationService.instance.initialize();
'''
    if old_boot in text:
        text = text.replace(old_boot, new_boot, 1)
    elif 'await SmartNotificationService.instance.initialize();' not in text:
        raise SystemExit('main notification boot anchor not found')

    marker = "  debugPrint('[Boot] runApp at ${bootTimer.elapsedMilliseconds}ms');\n"
    if 'unawaited(MusicRegionProfile.initialize());' not in text:
        if marker not in text:
            raise SystemExit('main runApp anchor not found')
        text = text.replace(
            marker,
            "  // Resolve public network country in the background; never delay first paint.\n  unawaited(MusicRegionProfile.initialize());\n" + marker,
            1,
        )
    p.write_text(text)


def patch_home() -> None:
    path = 'lib/features/home/home_screen.dart'
    p = ROOT / path
    text = p.read_text()

    text = text.replace(
        '  DateTime? _lastRefresh;\n  static const Duration _minRefreshInterval = Duration(minutes: 5);\n',
        '',
        1,
    )

    old_lifecycle = '''  @override
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
    new_lifecycle = '''  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from another screen must not reload the entire Home feed.
    // Manual pull-to-refresh remains the explicit full-refresh path.
  }
'''
    if old_lifecycle in text:
        text = text.replace(old_lifecycle, new_lifecycle, 1)

    # Keep the existing library listener so Continue Listening data is updated,
    # but do not call setState on the whole Home tree. The localized
    # ValueListenableBuilder below owns that repaint.
    old_library_tail = '''      s.status =
          s.tracks.isEmpty ? HomeShelfStatus.hidden : HomeShelfStatus.loaded;
    }
    _onShelfUpdate();
  }
'''
    new_library_tail = '''      s.status =
          s.tracks.isEmpty ? HomeShelfStatus.hidden : HomeShelfStatus.loaded;
    }
  }
'''
    if old_library_tail in text:
        text = text.replace(old_library_tail, new_library_tail, 1)

    # Only the Continue Listening sliver listens directly to recentlyPlayed.
    # Everything else keeps its existing widget identity and scroll position.
    patch_line = '              _buildContinueListeningHero(),\n'
    replacement = '''              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: LocalLibrary.instance.recentlyPlayed,
                builder: (context, _, child) =>
                    child ?? _buildContinueListeningHero(),
                child: _buildContinueListeningHero(),
              ),
'''
    if patch_line in text and 'valueListenable: LocalLibrary.instance.recentlyPlayed' not in text:
        text = text.replace(patch_line, replacement, 1)
    p.write_text(text)


def patch_discover() -> None:
    path = 'lib/core/discover/discover_feed_engine.dart'
    p = ROOT / path
    text = p.read_text()
    if "import '../recommendation/smart_listening_service.dart';" not in text:
        text = text.replace(
            "import '../recommendation/recommendation_service.dart';\n",
            "import '../recommendation/recommendation_service.dart';\nimport '../recommendation/smart_listening_service.dart';\n",
            1,
        )

    anchor = '''    final engineResults = await Future.wait([
'''
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
            '    final engineResults = await Future.wait([\n',
            '    final engineResults = await Future.wait<List<_ScoredCandidate>>([\n      smartHomePool,\n',
            1,
        )
    p.write_text(text)


if __name__ == '__main__':
    patch_main()
    patch_home()
    patch_discover()
    print('Runtime refresh/notification/region patch applied.')

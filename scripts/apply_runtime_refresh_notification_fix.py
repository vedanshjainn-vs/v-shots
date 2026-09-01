from pathlib import Path
import re

ROOT = Path('.')


def patch_file(path: str, old: str, new: str, label: str, required: bool = True) -> None:
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

  // Notifications are intentionally initialized SEQUENTIALLY. Starting the
  // smart scheduler in the same Future.wait as NotificationService created a
  // race where scheduled notifications could be discarded because the
  // notification plugin had not finished initialization yet.
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
            "  // Resolve network country without delaying first paint.\n  unawaited(MusicRegionProfile.initialize());\n" + marker,
            1,
        )
    p.write_text(text)


def patch_home() -> None:
    p = ROOT / 'lib/features/home/home_screen.dart'
    text = p.read_text()

    # Returning to the app must not tear down and rebuild the complete feed.
    # Manual pull-to-refresh remains available. Taste-specific surfaces listen
    # to SignalStore/region revisions themselves and update in place.
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
    // Do NOT auto-refresh the whole Home feed on every resume. Returning from
    // another screen should preserve scroll position and already-loaded
    // shelves. The user can pull to refresh, while personalized sections
    // update themselves from signal/region revisions.
    if (state == AppLifecycleState.resumed) {
      _lastRefresh = DateTime.now();
    }
  }
'''
    if old_lifecycle in text:
        text = text.replace(old_lifecycle, new_lifecycle, 1)

    # Continue Listening is the only Home surface that must react immediately
    # to a play event. Keep that listener local instead of setState() on the
    # entire CustomScrollView.
    text = text.replace(
        '    LocalLibrary.instance.recentlyPlayed.addListener(_onLibraryChanged);\n',
        '',
        1,
    )
    text = text.replace(
        '    LocalLibrary.instance.recentlyPlayed.removeListener(_onLibraryChanged);\n',
        '',
        1,
    )

    start = text.find('  void _onLibraryChanged() {')
    if start != -1:
        end = text.find('  Future<void> _load({required bool forceRefresh}) async {', start)
        if end == -1:
            raise SystemExit('home library listener end anchor not found')
        text = text[:start] + text[end:]

    # Replace the direct recent-list read with a localized ValueListenableBuilder.
    start = text.find('  Widget _buildContinueListeningHero() {')
    end = text.find('  // ── Mood / genre chips', start)
    if start == -1 or end == -1:
        raise SystemExit('home continue-listening method anchors not found')
    method = r'''  Widget _buildContinueListeningHero() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: LocalLibrary.instance.recentlyPlayed,
      builder: (context, recent, _) {
        if (recent.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final track = recent.first;
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: PressableScale(
              onTap: () => playTrack(context, track, recent, 0),
              child: Container(
                height: 132,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2A1E4D), Color(0xFF161A2C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(18),
                      ),
                      child: SizedBox(
                        width: 132,
                        height: 132,
                        child: ArtworkFadeIn(
                          child: AppImage(
                            track['artwork'] as String?,
                            fit: BoxFit.cover,
                            errorIconColor: AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CONTINUE LISTENING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              track['title'] as String? ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              track['artist'] as String? ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Play',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

'''
    text = text[:start] + method + text[end:]
    p.write_text(text)


def patch_discover() -> None:
    p = ROOT / 'lib/core/discover/discover_feed_engine.dart'
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
        ? smartHome.nextSongQueue(
            seed: null,
            count: 24,
          ).then<List<_ScoredCandidate>>(
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

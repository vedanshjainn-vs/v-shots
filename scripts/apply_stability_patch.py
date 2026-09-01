from pathlib import Path

ROOT = Path('.')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        if new in text:
            return text
        raise SystemExit(f'{label}: anchor not found')
    return text.replace(old, new, 1)


def patch_home_feed_service() -> None:
    path = ROOT / 'lib/features/home/home_feed_service.dart'
    text = path.read_text()
    # A hydrated shelf is not necessarily seen by the user. Only Discovery
    # records actually surfaced cards, so Home must not poison the 24h
    # recently-shown pool with every prefetched shelf item.
    text = text.replace('            LocalLibrary.instance.recordShownSong(id);\n', '')
    text = text.replace('      6,\n      baseExclude,', '      3,\n      baseExclude,')
    text = text.replace('    const chunkSize = 4;', '    const chunkSize = 3;')
    path.write_text(text)


def patch_discovery_screen() -> None:
    path = ROOT / 'lib/features/foryou/for_you_feed_screen.dart'
    text = path.read_text()

    # Continue Listening must follow Discovery autoplay/completion too.
    old = """    setState(() {\n      _items.addAll(batch);\n      _seenIds.addAll(batch.map((t) => t['id'] as String));\n      _initialLoading = false;\n    });\n"""
    new = """    setState(() {\n      _items.addAll(batch);\n      _seenIds.addAll(batch.map((t) => t['id'] as String));\n      _initialLoading = false;\n    });\n    if (batch.isNotEmpty) {\n      final first = batch.first;\n      final id = first['id'] as String? ?? '';\n      if (id.isNotEmpty) LocalLibrary.instance.recordShownSong(id);\n      _cardShownAt = DateTime.now();\n      _prevCard = first;\n    }\n"""
    text = replace_once(text, old, new, 'discovery initial batch')

    old = """    setState(() => _currentIndex = index);\n\n    // Programmatic move (auto-advance): the manager ALREADY owns playback\n"""
    new = """    setState(() => _currentIndex = index);\n    final shownId = track['id'] as String? ?? '';\n    if (shownId.isNotEmpty) LocalLibrary.instance.recordShownSong(shownId);\n\n    // Programmatic move (auto-advance): the manager ALREADY owns playback\n"""
    text = replace_once(text, old, new, 'discovery shown-song tracking')

    old = """      _discoverEngine.recordSwipe(\n        _items[_currentIndex],\n        outcome: DiscoverSwipeOutcome.completed,\n      );\n      _cardShownAt = DateTime.now();\n"""
    new = """      _discoverEngine.recordSwipe(\n        _items[_currentIndex],\n        outcome: DiscoverSwipeOutcome.completed,\n      );\n      unawaited(\n        LocalLibrary.instance.recordRecentlyPlayed(_items[_currentIndex]),\n      );\n      _cardShownAt = DateTime.now();\n"""
    text = replace_once(text, old, new, 'discovery completion recent-play')

    # The active Discovery card used a continuously animated ImageFilter.blur
    # inside the app-wide IndexedStack. That animation kept painting even when
    # Home was visible. Keep the backdrop static; cover crossfade still gives a
    # premium transition without a permanent GPU workload.
    text = text.replace(
        "    if (widget.isActive) _bgCtl.repeat(reverse: true);\n",
        "",
    )
    old = """  void didUpdateWidget(covariant _ForYouCard oldWidget) {\n    super.didUpdateWidget(oldWidget);\n    if (widget.isActive && !_bgCtl.isAnimating) {\n      _bgCtl.repeat(reverse: true);\n    } else if (!widget.isActive && _bgCtl.isAnimating) {\n      _bgCtl.stop();\n    }\n  }\n"""
    new = """  void didUpdateWidget(covariant _ForYouCard oldWidget) {\n    super.didUpdateWidget(oldWidget);\n    // Deliberately keep the expensive backdrop controller stopped. Discovery\n    // lives inside MainShell's IndexedStack, so a background animation would\n    // consume frames while Home/Search/Profile are active.\n    if (_bgCtl.isAnimating) _bgCtl.stop();\n  }\n"""
    text = replace_once(text, old, new, 'discovery backdrop animation')

    # Remove the default Material ripple/flash from the like control and use
    # the persisted ValueNotifier as the single source of truth. The state
    # change is immediate; persistence continues asynchronously.
    old = """                  StatefulBuilder(\n                    builder: (context, setLikeState) {\n                      final isLiked = LocalLibrary.instance.isLiked(trackId);\n                      return IconButton(\n                        icon: LikePop(\n                          liked: isLiked,\n                          child: Icon(\n                            isLiked\n                                ? Icons.favorite_rounded\n                                : Icons.favorite_border_rounded,\n                            color: isLiked ? AppColors.hotPink : Colors.white,\n                            size: 32,\n                          ),\n                        ),\n                        onPressed: () {\n                          unawaited(HapticFeedback.lightImpact());\n                          final wasLiked = isLiked;\n                          LocalLibrary.instance.toggleLiked(track).then((_) {\n                            if (wasLiked) {\n                              playbackSignalTracker.onUnliked(track);\n                            } else {\n                              playbackSignalTracker.onLiked(track);\n                            }\n                            setLikeState(() {});\n                          });\n                        },\n                      );\n                    },\n                  ),\n"""
    new = """                  ValueListenableBuilder<List<Map<String, dynamic>>>(\n                    valueListenable: LocalLibrary.instance.likedSongs,\n                    builder: (context, _, __) {\n                      final isLiked = LocalLibrary.instance.isLiked(trackId);\n                      return IconButton(\n                        splashColor: Colors.transparent,\n                        highlightColor: Colors.transparent,\n                        hoverColor: Colors.transparent,\n                        padding: EdgeInsets.zero,\n                        visualDensity: VisualDensity.compact,\n                        icon: RepaintBoundary(\n                          child: LikePop(\n                            liked: isLiked,\n                            child: Icon(\n                              isLiked\n                                  ? Icons.favorite_rounded\n                                  : Icons.favorite_border_rounded,\n                              color: isLiked ? AppColors.hotPink : Colors.white,\n                              size: 32,\n                            ),\n                          ),\n                        ),\n                        onPressed: () {\n                          unawaited(HapticFeedback.lightImpact());\n                          final wasLiked = isLiked;\n                          unawaited(LocalLibrary.instance.toggleLiked(track));\n                          if (wasLiked) {\n                            playbackSignalTracker.onUnliked(track);\n                          } else {\n                            playbackSignalTracker.onLiked(track);\n                          }\n                        },\n                      );\n                    },\n                  ),\n"""
    text = replace_once(text, old, new, 'discovery like button')

    path.write_text(text)


def patch_discovery_engine() -> None:
    path = ROOT / 'lib/core/discover/discover_feed_engine.dart'
    text = path.read_text()
    if "import '../storage/local_library.dart';" not in text:
        text = text.replace(
            "import '../remote_config/remote_config_service.dart';\n",
            "import '../remote_config/remote_config_service.dart';\nimport '../storage/local_library.dart';\n",
            1,
        )
    old = """      c.score = scoreTrack(\n        c.track,\n        bucket: c.bucket,\n        artistScores: artistScores,\n        activeArtists: activeArtists,\n        activeGenres: activeGenres,\n        recentArtists: recent,\n      );\n      c.reason = _reasonFor(c.track, c.bucket, artistScores);\n      scored.add(c);\n"""
    new = """      c.score = scoreTrack(\n        c.track,\n        bucket: c.bucket,\n        artistScores: artistScores,\n        activeArtists: activeArtists,\n        activeGenres: activeGenres,\n        recentArtists: recent,\n      );\n      // Recently surfaced cards are a soft negative, not a hard exclusion:\n      // fresh candidates win whenever the provider can supply them, while a\n      // thin result set can still fall back instead of going blank.\n      if (LocalLibrary.instance.recentlyShownIds.contains(id)) {\n        c.score *= 0.42;\n      }\n      c.reason = _reasonFor(c.track, c.bucket, artistScores);\n      scored.add(c);\n"""
    text = replace_once(text, old, new, 'discover freshness score')
    path.write_text(text)


def patch_notifications() -> None:
    path = ROOT / 'lib/core/notifications/notification_service.dart'
    text = path.read_text()
    old = """    final prefs = await SharedPreferences.getInstance();\n    final requested = prefs.getBool(keyNotifPermissionRequested) ?? false;\n    if (!requested) {\n      await requestNotificationPermission();\n      await prefs.setBool(keyNotifPermissionRequested, true);\n    }\n    debugPrint('[NotificationService] Initialized');\n"""
    new = """    // Do not permanently remember a failed/denied request. A previous build\n    // could have set the old flag before Android permission was actually\n    // granted, which made notifications silently stay disabled forever.\n    final granted = await hasNotificationPermission();\n    if (!granted) {\n      final requested = await requestNotificationPermission();\n      final prefs = await SharedPreferences.getInstance();\n      await prefs.setBool(keyNotifPermissionRequested, requested);\n    }\n    debugPrint('[NotificationService] Initialized; permission=$granted');\n"""
    text = replace_once(text, old, new, 'notification permission bootstrap')
    text = text.replace(
        "      priority: Priority.defaultPriority,\n      icon: '@mipmap/ic_launcher',\n",
        "      priority: Priority.defaultPriority,\n      playSound: true,\n      enableVibration: true,\n      icon: '@mipmap/ic_launcher',\n",
    )
    path.write_text(text)


def patch_main_boot_order() -> None:
    path = ROOT / 'lib/main.dart'
    text = path.read_text()
    old = """    AppVersion.load(),\n    NotificationService.instance.initialize(),\n    SmartNotificationService.instance.initialize(),\n  ]);\n  debugPrint('[Boot] core init done in ${bootTimer.elapsedMilliseconds}ms');\n"""
    new = """    AppVersion.load(),\n    NotificationService.instance.initialize(),\n  ]);\n  // NotificationService MUST be ready before SmartNotificationService: the\n  // scheduler calls into it during initialization. Running both in the same\n  // Future.wait caused the first schedule build to race the plugin init and\n  // silently schedule zero notifications.\n  await SmartNotificationService.instance.initialize();\n  debugPrint('[Boot] core init done in ${bootTimer.elapsedMilliseconds}ms');\n"""
    text = replace_once(text, old, new, 'notification boot ordering')
    path.write_text(text)


def patch_manifest() -> None:
    path = ROOT / 'android/app/src/main/AndroidManifest.xml'
    text = path.read_text()
    if 'android.permission.RECEIVE_BOOT_COMPLETED' not in text:
        text = text.replace(
            '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n',
            '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n',
            1,
        )
    if 'ScheduledNotificationReceiver' not in text:
        marker = '        <service android:name="com.ryanheise.audioservice.AudioService"\n'
        receiver = '''        <receiver\n            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"\n            android:exported="false" />\n        <receiver\n            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"\n            android:exported="false">\n            <intent-filter>\n                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>\n                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n            </intent-filter>\n        </receiver>\n\n'''
        text = replace_once(text, marker, receiver + marker, 'notification manifest receivers')
    path.write_text(text)


def patch_browser_service() -> None:
    path = ROOT / 'android/app/src/main/kotlin/com/vshots/live/VShotsBrowserPlaybackService.kt'
    text = path.read_text()
    text = text.replace(
        '.setContentTitle("V Shots")\n            .setContentText("Discovery playback is active")',
        '.setContentTitle("V Shots • Now Playing")\n            .setContentText("Music playback is active")',
    )
    path.write_text(text)


if __name__ == '__main__':
    patch_home_feed_service()
    patch_discovery_screen()
    patch_discovery_engine()
    patch_notifications()
    patch_main_boot_order()
    patch_manifest()
    patch_browser_service()
    print('Stability audit patch applied.')

from pathlib import Path

ROOT = Path('.')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        if new in text:
            return text
        core_lines = [l.strip() for l in new.strip().splitlines() if len(l.strip()) > 15]
        if core_lines and any(l in text for l in core_lines):
            return text
        raise SystemExit(f'{label}: anchor not found')
    return text.replace(old, new, 1)


def patch_home_feed_service() -> None:
    path = ROOT / 'lib/features/home/home_feed_service.dart'
    text = path.read_text()
    text = text.replace('            LocalLibrary.instance.recordShownSong(id);\n', '')
    text = text.replace('      6,\n      baseExclude,', '      3,\n      baseExclude,')
    text = text.replace('    const chunkSize = 4;', '    const chunkSize = 3;')
    path.write_text(text)


def patch_discovery_screen() -> None:
    path = ROOT / 'lib/features/foryou/for_you_feed_screen.dart'
    text = path.read_text()
    old = """    setState({\n"""
    # This guard is intentionally no-op here; discovery changes below use the
    # same conservative anchors as the established stability patch.
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
    new = """      c.score = scoreTrack(\n        c.track,\n        bucket: c.bucket,\n        artistScores: artistScores,\n        activeArtists: activeArtists,\n        activeGenres: activeGenres,\n        recentArtists: recent,\n      );\n      if (LocalLibrary.instance.recentlyShownIds.contains(id)) {\n        c.score *= 0.42;\n      }\n      c.reason = _reasonFor(c.track, c.bucket, artistScores);\n      scored.add(c);\n"""
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
    old = """  await SmartNotificationService.instance.initialize();\n  debugPrint('[Boot] core init done in ${bootTimer.elapsedMilliseconds}ms');\n"""
    new = """  // Smart notifications are non-critical for first paint. Start their\n  // scheduler after runApp so notification setup cannot hold the UI hostage.\n  debugPrint('[Boot] core init done in ${bootTimer.elapsedMilliseconds}ms');\n"""
    text = replace_once(text, old, new, 'defer smart notification scheduler')
    old = """  runApp(const VShotsApp());\n\n  // Check for app updates (non-blocking, fire-and-forget)\n  unawaited(AppUpdateService.instance.checkForUpdate());\n"""
    new = """  runApp(const VShotsApp());\n\n  // Non-critical background work starts only after the first frame can be\n  // presented. Core notification initialization above remains ordered.\n  unawaited(SmartNotificationService.instance.initialize());\n  unawaited(AppUpdateService.instance.checkForUpdate());\n"""
    text = replace_once(text, old, new, 'start deferred services after runApp')
    old = "duration: const Duration(seconds: 2),"
    new = "duration: const Duration(milliseconds: 800),"
    text = replace_once(text, old, new, 'shorten splash hold')
    path.write_text(text)


def patch_home_screen() -> None:
    path = ROOT / 'lib/features/home/home_screen.dart'
    text = path.read_text()
    old = """  HomeShelf? _dynamicForYouShelf() {\n    for (final shelf in _shelves) {\n      if (shelf.id == 'dynamic_mfy' &&\n          shelf.status == HomeShelfStatus.loaded &&\n          shelf.tracks.isNotEmpty) {\n        return shelf;\n      }\n    }\n    return null;\n  }\n"""
    new = """  HomeShelf? _dynamicForYouShelf() {\n    // Prefer the dedicated Made For You shelf. If it has not resolved yet,\n    // use the first loaded personalized shelf as the same large For You hero\n    // rather than leaving the premium poster area blank during a slow network\n    // response. This does not change recommendation generation or ordering.\n    for (final shelf in _shelves) {\n      if (shelf.id == 'dynamic_mfy' &&\n          shelf.status == HomeShelfStatus.loaded &&\n          shelf.tracks.isNotEmpty) {\n        return shelf;\n      }\n    }\n    for (final shelf in _shelves) {\n      final personalized = shelf.kind == HomeShelfKind.madeForYou ||\n          shelf.kind == HomeShelfKind.becauseYouListenedTo ||\n          shelf.kind == HomeShelfKind.trendingForYou ||\n          shelf.kind == HomeShelfKind.discoverSomethingNew;\n      if (personalized &&\n          shelf.status == HomeShelfStatus.loaded &&\n          shelf.tracks.isNotEmpty) {\n        return shelf;\n      }\n    }\n    return null;\n  }\n"""
    text = replace_once(text, old, new, 'For You hero fallback')
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
    patch_home_screen()
    patch_manifest()
    patch_browser_service()
    print('Stability audit patch applied.')

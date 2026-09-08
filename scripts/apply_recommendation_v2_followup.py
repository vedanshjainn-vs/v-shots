from pathlib import Path


def main() -> None:
    home_path = Path('lib/features/home/home_screen.dart')
    text = home_path.read_text()
    if 'homeScrollToTopSignal' in text and 'homeScrollToTopSignal,' not in text:
        old = "        show currentTrackNotifier, homeFeedService, musicRepository, playTrack;"
        new = "        show\n        currentTrackNotifier,\n        homeFeedService,\n        homeScrollToTopSignal,\n        musicRepository,\n        playTrack;"
        if old not in text:
            raise SystemExit('home_screen.dart: main.dart show import anchor not found')
        text = text.replace(old, new, 1)
    home_path.write_text(text)

    feed_path = Path('lib/features/home/home_feed_service.dart')
    feed = feed_path.read_text()
    feed = feed.replace("import 'dart:io' as io;\n", '', 1)
    feed_path.write_text(feed)

    candidate_path = Path('lib/core/recommendation/candidate_generator.dart')
    candidate = candidate_path.read_text()
    if "import 'dart:math';" not in candidate:
        candidate = "import 'dart:math';\n\n" + candidate
    if 'final _random = Random();' not in candidate:
        anchor = '  final RecommendationConfig config;\n'
        if anchor not in candidate:
            raise SystemExit('candidate_generator.dart: config anchor not found')
        candidate = candidate.replace(
            anchor,
            anchor + '  final _random = Random();\n',
            1,
        )
    candidate_path.write_text(candidate)

    # Notification + SmartNotification are not needed for the first content
    # frame. Initialize them in order in the background so their existing
    # dependency relationship is preserved without blocking startup.
    main_path = Path('lib/main.dart')
    main = main_path.read_text()
    old_boot = """  unawaited(Future.wait([\n    SupabaseService.initialize(),\n    RemoteConfigService.instance.init(),\n    AdFreeManager.instance.init(),\n    AppVersion.load(),\n    NotificationService.instance.initialize(),\n  ]));\n  // NotificationService MUST be ready before SmartNotificationService: the\n  // scheduler calls into it during initialization. Running both in the same\n  // Future.wait caused the first schedule build to race the plugin init and\n  // silently schedule zero notifications.\n  await SmartNotificationService.instance.initialize();\n"""
    new_boot = """  unawaited(Future.wait([\n    SupabaseService.initialize(),\n    RemoteConfigService.instance.init(),\n    AdFreeManager.instance.init(),\n    AppVersion.load(),\n  ]));\n  // NotificationService MUST be ready before SmartNotificationService, but\n  // neither is required to render the first Home frame. Keep their ordering\n  // and move both behind runApp's critical path.\n  unawaited(\n    NotificationService.instance\n        .initialize()\n        .then((_) => SmartNotificationService.instance.initialize()),\n  );\n"""
    if old_boot not in main:
        raise SystemExit('main.dart: deferred notification boot block not found')
    main = main.replace(old_boot, new_boot, 1)
    main_path.write_text(main)
    print('V2 follow-up safety/performance fixes applied.')


if __name__ == '__main__':
    main()

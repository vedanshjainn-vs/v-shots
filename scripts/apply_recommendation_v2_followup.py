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
    if "import '../../core/music/music_validator.dart';" not in feed:
        anchor = "import '../../core/music/music_catalog_service.dart';\n"
        if anchor not in feed:
            raise SystemExit('home_feed_service.dart: validator import anchor not found')
        feed = feed.replace(
            anchor,
            anchor + "import '../../core/music/music_validator.dart';\n",
            1,
        )
    anchor = "      var tracks = await _fetch(shelf, excludeIds);\n"
    if "tracks = tracks.where((track) => !const MusicContentValidator().isAiContent(track)).toList();" not in feed:
        if anchor not in feed:
            raise SystemExit('home_feed_service.dart: fetch track gate anchor not found')
        feed = feed.replace(
            anchor,
            anchor + "      tracks = tracks\n          .where((track) => !const MusicContentValidator().isAiContent(track))\n          .toList();\n",
            1,
        )
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

    main_path = Path('lib/main.dart')
    main = main_path.read_text()
    old_boot = """  unawaited(Future.wait([\n    SupabaseService.initialize(),\n    RemoteConfigService.instance.init(),\n    AdFreeManager.instance.init(),\n    AppVersion.load(),\n  ]));\n  // NotificationService MUST be ready before SmartNotificationService, but\n  // neither is required to render the first Home frame. Keep their ordering\n  // and move both behind runApp's critical path.\n  unawaited(\n    NotificationService.instance\n        .initialize()\n        .then((_) => SmartNotificationService.instance.initialize()),\n  );\n"""
    new_boot = """  unawaited(Future.wait([\n    SupabaseService.initialize(),\n    RemoteConfigService.instance.init(),\n    AdFreeManager.instance.init(),\n    AppVersion.load(),\n  ]));\n  // NotificationService MUST be ready before SmartNotificationService, but\n  // neither is required to render the first Home frame. Keep their ordering\n  // and move both behind runApp's critical path.\n  unawaited(\n    NotificationService.instance\n        .initialize()\n        .then((_) => SmartNotificationService.instance.initialize()),\n  );\n"""
    if old_boot in main:
        main = main.replace(old_boot, new_boot, 1)
    main_path.write_text(main)
    print('V2 follow-up safety/performance/content-policy fixes applied.')


if __name__ == '__main__':
    main()

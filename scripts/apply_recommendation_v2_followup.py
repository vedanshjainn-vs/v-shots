import subprocess
from pathlib import Path


def main() -> None:
    home_path = Path('lib/features/home/home_screen.dart')
    text = home_path.read_text()
    if 'homeScrollToTopSignal' in text:
        start = text.find("import '../../main.dart'")
        if start >= 0:
            end = text.find(';', start)
            if end >= 0:
                block = text[start:end + 1]
                if 'homeScrollToTopSignal' not in block and 'show' in block:
                    block = block.replace(
                        'currentTrackNotifier,',
                        'currentTrackNotifier,\n        homeScrollToTopSignal,',
                        1,
                    )
                    text = text[:start] + block + text[end + 1:]
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
    gate = """      tracks = tracks
          .where((track) => !const MusicContentValidator().isAiContent(track))
          .toList();
"""
    if gate not in feed:
        if anchor not in feed:
            raise SystemExit('home_feed_service.dart: fetch track gate anchor not found')
        feed = feed.replace(anchor, anchor + gate, 1)
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
    old_boot = """  unawaited(Future.wait([
    SupabaseService.initialize(),
    RemoteConfigService.instance.init(),
    AdFreeManager.instance.init(),
    AppVersion.load(),
  ]));
  // NotificationService MUST be ready before SmartNotificationService, but
  // neither is required to render the first Home frame. Keep their ordering
  // and move both behind runApp's critical path.
  unawaited(
    NotificationService.instance
        .initialize()
        .then((_) => SmartNotificationService.instance.initialize()),
  );
"""
    new_boot = old_boot
    if old_boot in main:
        main = main.replace(old_boot, new_boot, 1)
    main_path.write_text(main)

    files = [
        'lib/core/music/music_validator.dart',
        'lib/core/providers/music_repository.dart',
        'lib/core/recommendation/candidate_generator.dart',
        'lib/features/home/home_feed_service.dart',
        'lib/features/home/home_screen.dart',
        'lib/features/foryou/for_you_feed_screen.dart',
        'lib/main.dart',
    ]
    subprocess.run(['dart', 'format', *files], check=True)
    print('V2 follow-up safety/performance/content-policy fixes applied.')


if __name__ == '__main__':
    main()

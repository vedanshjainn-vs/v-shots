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
    print('V2 follow-up safety fixes applied.')


if __name__ == '__main__':
    main()

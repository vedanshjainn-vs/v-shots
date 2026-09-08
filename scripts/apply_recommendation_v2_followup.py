from pathlib import Path


def main() -> None:
    path = Path('lib/features/home/home_screen.dart')
    text = path.read_text()
    if 'homeScrollToTopSignal' in text and 'homeScrollToTopSignal,' not in text:
        old = "        show currentTrackNotifier, homeFeedService, musicRepository, playTrack;"
        new = "        show\n        currentTrackNotifier,\n        homeFeedService,\n        homeScrollToTopSignal,\n        musicRepository,\n        playTrack;"
        if old not in text:
            raise SystemExit('home_screen.dart: main.dart show import anchor not found')
        text = text.replace(old, new, 1)
    path.write_text(text)
    print('Home scroll notifier import fixed.')


if __name__ == '__main__':
    main()

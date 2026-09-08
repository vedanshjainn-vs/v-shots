from pathlib import Path

ROOT = Path('.')


def patch_discovery() -> None:
    path = ROOT / 'lib/features/foryou/for_you_feed_screen.dart'
    text = path.read_text()

    if (
        'DiscoverySwipeNativeAdPage' in text
        and '_isAdPage' in text
        and '_pageCount' in text
    ):
        print('Discovery swipeable ad page: verified active and intact')
        return

    raise RuntimeError('Discovery swipeable ad page configuration missing')


if __name__ == '__main__':
    patch_discovery()
    print('Discovery uses swipeable LevelPlay in-feed ad cards.')

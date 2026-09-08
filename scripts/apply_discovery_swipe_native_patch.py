from pathlib import Path

ROOT = Path('.')


def patch_discovery() -> None:
    path = ROOT / 'lib/features/foryou/for_you_feed_screen.dart'
    text = path.read_text()

    if (
        'VShotsAds.instance.showDiscoverySwipeInterstitial' in text
        and '_lastInterstitialIndex' in text
        and '_showSwipeInterstitialAndResume' in text
    ):
        print('Discovery swipe interstitial ad: verified active and intact')
        return

    raise RuntimeError('Discovery swipe interstitial ad configuration missing')


if __name__ == '__main__':
    patch_discovery()
    print(
        'Discovery uses full-screen LevelPlay Interstitial Video ads on swipe'
        ' cadence.'
    )

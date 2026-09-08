from pathlib import Path
import runpy

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
    else:
        raise RuntimeError('Discovery swipeable ad page configuration missing')


if __name__ == '__main__':
    patch_discovery()
    runpy.run_path('scripts/apply_advanced_recommendation_v2_patch.py', run_name='__main__')
    runpy.run_path('scripts/apply_home_discovery_product_polish_patch.py', run_name='__main__')
    print('Discovery uses swipeable LevelPlay in-feed ad cards.')

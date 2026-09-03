from pathlib import Path
import re

ROOT = Path('.')


def replace_once(path: str, old: str, new: str, label: str, required: bool = True) -> None:
    p = ROOT / path
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        if required:
            raise SystemExit(f'{label}: anchor not found in {path}')
        return
    p.write_text(text.replace(old, new, 1))


def remove_class(text: str, class_name: str) -> str:
    marker = f'class {class_name}'
    start = text.find(marker)
    if start < 0:
        return text
    brace = text.find('{', start)
    if brace < 0:
        return text
    depth = 0
    in_string = False
    quote = ''
    escaped = False
    for i in range(brace, len(text)):
        ch = text[i]
        if in_string:
            if escaped:
                escaped = False
            elif ch == '\\':
                escaped = True
            elif ch == quote:
                in_string = False
            continue
        if ch in ('"', "'"):
            in_string = True
            quote = ch
        elif ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                return text[:start] + text[end:]
    return text


def patch_discover() -> None:
    path = 'lib/features/foryou/for_you_feed_screen.dart'
    p = ROOT / path
    text = p.read_text()

    # The source previously referred to a native ad card. Replace that page
    # with the same reusable Unity MREC component used by Home/Search.
    text = text.replace(
        "// Ad page: a clearly-separated, labeled native ad card. It never\n"
        "                // touches the YouTube player (which keeps playing the song that\n"
        "                // was active before/after), so it can't violate YouTube policy.\n"
        "                if (_isAdPage(page)) {\n"
        "                  return RepaintBoundary(\n"
        "                    child: _ForYouAdCard(onSkip: () => _goToPage(page + 1)),\n"
        "                  );\n"
        "                }",
        "// Ad page: a dedicated 300×250 MREC content block. It never touches\n"
        "                // the browser/player, so playback continues uninterrupted.\n"
        "                if (_isAdPage(page)) {\n"
        "                  return const RepaintBoundary(\n"
        "                    child: Center(\n"
        "                      child: PremiumMRECAdCard(\n"
        "                        placement: MRECPlacement.discoverFeed,\n"
        "                      ),\n"
        "                    ),\n"
        "                  );\n"
        "                }",
        1,
    )

    # If an older patch injected a native card implementation, remove it so
    # no obsolete native renderer remains in the release source.
    text = remove_class(text, '_ForYouAdCard')

    # The dwell opportunity is deliberately a load/preparation signal, not a
    # blocking overlay. The next natural ad page can therefore display without
    # pausing or restarting the current song.
    if 'Timer? _mrecDwellTimer;' not in text:
        anchor = '  Map<String, dynamic>? _prevCard;\n'
        block = '''  Map<String, dynamic>? _prevCard;
  Timer? _mrecDwellTimer;
  bool _mrecDwellUnlocked = false;
'''
        text = text.replace(anchor, block, 1)

    if '_startMrecDwellTimer();' not in text:
        anchor = '    _loadInitialBatch();\n'
        block = '''    _loadInitialBatch();
    _startMrecDwellTimer();
'''
        text = text.replace(anchor, block, 1)

    if 'void _startMrecDwellTimer()' not in text:
        anchor = '  @override\n  void dispose() {\n'
        block = '''  void _startMrecDwellTimer() {
    _mrecDwellTimer?.cancel();
    _mrecDwellTimer = Timer(MRECConfig.discoverDwellTime, () {
      if (!mounted || !_onDiscoverTab) return;
      // Unlock only a future/natural MREC page. No overlay is inserted over
      // the active song, and the browser/audio lifecycle is untouched.
      setState(() => _mrecDwellUnlocked = true);
      debugPrint('[DiscoverMREC] dwell opportunity unlocked');
    });
  }

'''
        text = text.replace(anchor, block + anchor, 1)

    text = text.replace(
        '    _pageController.dispose();\n',
        '    _mrecDwellTimer?.cancel();\n    _pageController.dispose();\n',
        1,
    )

    # Keep the normal feed frequency, but make the first ad page eligible only
    # after a short user dwell when the dwell rule is enabled. If the user is
    # actively swiping, the ordinary feed ad cadence remains the gate.
    if 'bool _isMrecPageEligible(int page)' not in text:
        anchor = '  /// Is the given PageView page an ad page? Ad pages appear right after every\n'
        block = '''  bool _isMrecPageEligible(int page) {
    if (!_adsEnabled) return false;
    if (page < AdConfig.discoveryAdEvery) return false;
    final firstAdPage = AdConfig.discoveryAdEvery;
    if (page == firstAdPage) return _mrecDwellUnlocked || _cardShownAt == null;
    return true;
  }

'''
        text = text.replace(anchor, block + anchor, 1)
    text = text.replace(
        '    if (!_adsEnabled) return false;\n    if (page == 0) return false;\n',
        '    if (!_isMrecPageEligible(page)) return false;\n    if (page == 0) return false;\n',
        1,
    )

    p.write_text(text)


def patch_main_search() -> None:
    # Search already uses PremiumMRECAdCard. Validate that no native widget is
    # referenced by the main search implementation and keep the placement
    # after a meaningful result count.
    path = ROOT / 'lib/main.dart'
    text = path.read_text()
    text = text.replace(
        "              // MREC ad slot after the 8th organic result.\n",
        "              // Premium MREC slot after a meaningful search result set.\n",
        1,
    )
    path.write_text(text)


def validate() -> None:
    checks = {
        'lib/core/ads/premium_mrec_ad_card.dart': [
            'LevelPlayAdSize.MEDIUM_RECTANGLE',
            'MRECConfig.loadTimeout',
        ],
        'lib/features/home/home_screen.dart': ['PremiumMRECAdCard'],
        'lib/features/foryou/for_you_feed_screen.dart': [
            'PremiumMRECAdCard',
            'MRECPlacement.discoverFeed',
            'MRECConfig.discoverDwellTime',
        ],
        'lib/main.dart': ['PremiumMRECAdCard', 'MRECPlacement.search'],
    }
    for path, needles in checks.items():
        text = (ROOT / path).read_text()
        for needle in needles:
            if needle not in text:
                raise SystemExit(f'MREC validation failed: {needle} missing in {path}')

    # Native LevelPlay rendering must not remain in the app. The compatibility
    # file may exist for old imports, but it must contain no native platform view.
    native = (ROOT / 'lib/core/ads/native_ad_widget.dart').read_text()
    if 'LevelPlayNativeAdView' in native or 'LevelPlayNativeAd.builder' in native:
        raise SystemExit('obsolete native LevelPlay renderer still present')


if __name__ == '__main__':
    print('[5m] Apply Premium Unity MREC Ads Patch')
    patch_discover()
    patch_main_search()
    validate()
    print('[5m] Premium Unity MREC Ads Patch complete.')

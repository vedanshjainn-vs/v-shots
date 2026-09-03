from pathlib import Path

ROOT = Path('.')


def patch_discover() -> None:
    path = ROOT / 'lib/features/foryou/for_you_feed_screen.dart'
    text = path.read_text()

    old = '''                // Ad page: a clearly-separated, labeled native ad card. It never
                // touches the YouTube player (which keeps playing the song that
                // was active before/after), so it can't violate YouTube policy.
                if (_isAdPage(page)) {
                  return RepaintBoundary(
                    child: _ForYouAdCard(onSkip: () => _goToPage(page + 1)),
                  );
                }'''
    new = '''                // Ad page: a dedicated 300×250 MREC content block. It never
                // touches the browser/player, so playback continues uninterrupted.
                if (_isAdPage(page)) {
                  return const RepaintBoundary(
                    child: Center(
                      child: PremiumMRECAdCard(
                        placement: MRECPlacement.discoverFeed,
                      ),
                    ),
                  );
                }'''
    if old in text:
        text = text.replace(old, new, 1)

    # Remove any older injected native renderer. This is intentionally
    # best-effort because some historical branches never contained the class.
    marker = 'class _ForYouAdCard'
    start = text.find(marker)
    if start >= 0:
        brace = text.find('{', start)
        if brace >= 0:
            depth = 0
            quote = ''
            escaped = False
            in_string = False
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
                        text = text[:start] + text[i + 1:]
                        break

    # Discover is a PageView: changing the number of pages after the user has
    # started swiping would remap page→song indices. Keep the ad cadence stable
    # from page one. The dwell timer is therefore telemetry/readiness only; it
    # never inserts an overlay and never changes the active playback surface.
    if 'Timer? _mrecDwellTimer;' not in text:
        text = text.replace(
            '  Map<String, dynamic>? _prevCard;\n',
            '''  Map<String, dynamic>? _prevCard;
  Timer? _mrecDwellTimer;
''',
            1,
        )
    if '_startMrecDwellTimer();' not in text:
        text = text.replace(
            '    _loadInitialBatch();\n',
            '    _loadInitialBatch();\n    _startMrecDwellTimer();\n',
            1,
        )
    if 'void _startMrecDwellTimer()' not in text:
        text = text.replace(
            '  @override\n  void dispose() {\n',
            '''  void _startMrecDwellTimer() {
    _mrecDwellTimer?.cancel();
    _mrecDwellTimer = Timer(MRECConfig.discoverDwellTime, () {
      if (!mounted || !_onDiscoverTab) return;
      // The ad cadence is already represented by a future feed page. Record
      // the dwell opportunity without inserting a disruptive overlay.
      debugPrint('[DiscoverMREC] dwell opportunity unlocked');
    });
  }

  @override
  void dispose() {
''',
            1,
        )
    if '    _mrecDwellTimer?.cancel();\n' not in text:
        text = text.replace(
            '    _pageController.dispose();\n',
            '    _mrecDwellTimer?.cancel();\n    _pageController.dispose();\n',
            1,
        )

    p.write_text(text)


def patch_main_search() -> None:
    path = ROOT / 'lib/main.dart'
    text = path.read_text()
    text = text.replace(
        '              // MREC ad slot after the 8th organic result.\n',
        '              // Premium MREC slot after a meaningful search result set.\n',
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

    native = (ROOT / 'lib/core/ads/native_ad_widget.dart').read_text()
    if 'LevelPlayNativeAdView' in native or 'LevelPlayNativeAd.builder' in native:
        raise SystemExit('obsolete native LevelPlay renderer still present')


if __name__ == '__main__':
    print('[5m] Apply Premium Unity MREC Ads Patch')
    patch_discover()
    patch_main_search()
    validate()
    print('[5m] Premium Unity MREC Ads Patch complete.')

from pathlib import Path

ROOT = Path('.')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        print(f'{label}: already applied')
        return text
    if old not in text:
        raise RuntimeError(f'{label}: required anchor missing')
    print(f'{label}: applied')
    return text.replace(old, new, 1)


def patch_discovery() -> None:
    path = ROOT / 'lib/features/foryou/for_you_feed_screen.dart'
    text = path.read_text()

    text = replace_once(
        text,
        "import '../../core/ads/ad_service.dart';\n",
        "import '../../core/ads/ad_policy.dart';\n"
        "import '../../core/ads/ad_service.dart';\n"
        "import '../../core/ads/discovery_swipe_native_ad_page.dart';\n",
        'Discovery native ad imports',
    )

    text = replace_once(
        text,
        """  /// The index of the last organic video where a swipe interstitial was
  /// triggered (prevents re-triggering on backward/rapid swipes).
  int _lastInterstitialIndex = -1;
  bool _showingInterstitial = false;

""",
        """  // Discovery is a true vertical PageView: organic video pages are
  // interleaved with embeddable LevelPlay Native ad pages. The ad page is a
  // real SDK view, never a modal interstitial or a fake placeholder.
  bool get _adsEnabled =>
      AdPolicy.instance.canShowNative(AdPlacement.forYouFeed);

  int _adCountFor(int songCount) {
    if (!_adsEnabled || songCount <= 0) return 0;
    return (songCount - 1) ~/ AdConfig.discoveryAdEvery;
  }

  int get _pageCount => _items.length + _adCountFor(_items.length);

  bool _isAdPage(int page) {
    if (!_adsEnabled || page == 0) return false;
    return (page - AdConfig.discoveryAdEvery) %
            (AdConfig.discoveryAdEvery + 1) ==
        0;
  }

  int _songIndexForPage(int page) {
    if (!_adsEnabled) return page;
    final adsBefore = page ~/ (AdConfig.discoveryAdEvery + 1);
    return page - adsBefore;
  }

  int _pageForSongIndex(int songIndex) {
    if (!_adsEnabled) return songIndex;
    return songIndex + (songIndex ~/ AdConfig.discoveryAdEvery);
  }

""",
        'Discovery swipeable page mapping',
    )

    text = replace_once(
        text,
        """    if (_pageController.hasClients) {
      _pageController.jumpToPage(idx.clamp(0, _items.length - 1));
    }
""",
        """    if (_pageController.hasClients) {
      _pageController.jumpToPage(
        _pageForSongIndex(idx).clamp(0, _pageCount - 1),
      );
    }
""",
        'Auto-advance page mapping',
    )

    start = text.index('  void _onPageChanged(int index) {')
    end = text.index('  /// Opens the Explore panel:', start)
    replacement = '''  void _onPageChanged(int page) {
    if (page < 0 || page >= _pageCount) return;
    unawaited(HapticFeedback.selectionClick());

    // This is the actual in-feed ad page. It owns no playback and never calls
    // the modal Interstitial API. The user simply swipes through it.
    if (_isAdPage(page)) {
      if (VShotsPlaybackManager.instance.isOpen) {
        VShotsPlaybackManager.instance.pause();
      }
      setState(() {});
      return;
    }

    final index = _songIndexForPage(page);
    if (index < 0 || index >= _items.length) return;
    final track = _items[index];

    final prev = _prevCard;
    if (prev != null) {
      final shownFor = _cardShownAt == null
          ? 0
          : DateTime.now().difference(_cardShownAt!).inSeconds;
      final duration = (prev['duration'] as num?)?.toInt() ?? 0;
      final outcome = duration > 0 && shownFor >= duration * 0.9
          ? DiscoverSwipeOutcome.completed
          : shownFor >= 45
              ? DiscoverSwipeOutcome.listenedLong
              : shownFor >= 15
                  ? DiscoverSwipeOutcome.listenedShort
                  : DiscoverSwipeOutcome.skippedImmediately;
      _discoverEngine.recordSwipe(prev, outcome: outcome);
    }
    _cardShownAt = DateTime.now();
    _prevCard = track;

    setState(() => _currentIndex = index);

    // Programmatic auto-advance already owns playback. Never trigger another
    // ad page or re-run playQueue from this callback.
    if (_syncingFromManager) return;

    VShotsPlaybackManager.instance.playQueue(List.of(_items), index);
    unawaited(LocalLibrary.instance.recordRecentlyPlayed(track));
    playbackSignalTracker.onTrackStarted(track);
    unawaited(_maybeLoadMore());
  }

  void _skipUnavailableDiscoveryAd(int page) {
    if (!mounted || !_isAdPage(page)) return;
    final nextPage = page + 1;
    if (nextPage >= _pageCount) {
      unawaited(_maybeLoadMore());
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(nextPage);
    });
  }

'''
    text = text[:start] + replacement + text[end:]

    old = '''            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              itemCount: _items.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                if (index < 0 || index >= _items.length) {
                  return const SizedBox.shrink();
                }
                final isCurrent = index == _currentIndex;
                final track = _items[index];
                return RepaintBoundary(
                  child: _ForYouCard(
                    track: track,
                    isActive: isCurrent,
                    isPlaying: false,
                    onPlayPauseToggle: _onPlayTap,
                    onNotInterested: () => _handleNotInterested(index),
                    onDoubleTapLike: () => _handleDoubleTapLike(track),
                    onSkipPrevious: index > 0
                        ? () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            )
                        : null,
                    onSkipNext: index < _items.length - 1
                        ? () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            )
                        : null,
                  ),
                );
              },
            ),
'''
    new = '''            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              itemCount: _pageCount,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, page) {
                if (page < 0 || page >= _pageCount) {
                  return const SizedBox.shrink();
                }

                if (_isAdPage(page)) {
                  return RepaintBoundary(
                    child: DiscoverySwipeNativeAdPage(
                      onUnavailable: () => _skipUnavailableDiscoveryAd(page),
                    ),
                  );
                }

                final index = _songIndexForPage(page);
                if (index < 0 || index >= _items.length) {
                  return const SizedBox.shrink();
                }
                final isCurrent = page == _pageForSongIndex(_currentIndex);
                final track = _items[index];
                return RepaintBoundary(
                  child: _ForYouCard(
                    track: track,
                    isActive: isCurrent,
                    isPlaying: false,
                    onPlayPauseToggle: _onPlayTap,
                    onNotInterested: () => _handleNotInterested(index),
                    onDoubleTapLike: () => _handleDoubleTapLike(track),
                    onSkipPrevious: page > 0
                        ? () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            )
                        : null,
                    onSkipNext: page < _pageCount - 1
                        ? () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            )
                        : null,
                  ),
                );
              },
            ),
'''
    text = replace_once(text, old, new, 'Discovery PageView ad-page integration')

    for marker in (
        'VShotsAds.instance.showDiscoverySwipeInterstitial',
        '_showSwipeInterstitialAndResume',
        '_lastInterstitialIndex',
        '_showingInterstitial',
    ):
        if marker in text:
            raise RuntimeError(f'Forbidden modal interstitial marker remains: {marker}')

    path.write_text(text)


if __name__ == '__main__':
    patch_discovery()
    print('Discovery now uses a true swipeable LevelPlay Native ad page.')

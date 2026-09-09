from pathlib import Path
import re

ROOT = Path('.')


def patch_candidate_generator():
    p = ROOT / 'lib/core/recommendation/candidate_generator.dart'
    t = p.read_text()
    # The stable recommendation patch already provides recent-search intent.
    # Never inject a second declaration into the same method.
    block = re.compile(
        r"\n\s*// SEARCH INTENT — additive priority\. Keep every existing candidate\n"
        r"\s*// source so cold-start coverage is not sacrificed for personalization\.\n"
        r"\s*final recentSearches = LocalLibrary\.instance\.recentSearches\.value\n"
        r"\s*\.map\(\(s\) => s\['query'\] as String\? \?\? ''\)\n"
        r"\s*\.where\(\(q\) => q\.trim\(\)\.isNotEmpty\)\n"
        r"\s*\.take\(3\)\n"
        r"\s*\.toList\(\);\n"
        r"\s*for \(final q in recentSearches\) \{\n"
        r"\s*candidates\.insert\(\n"
        r"\s*0,\n"
        r"\s*CandidateQuery\(query: q\.trim\(\), source: CandidateSource\.searchBehavior\),\n"
        r"\s*\);\n"
        r"\s*\}\n",
        re.MULTILINE,
    )
    matches = list(block.finditer(t))
    if len(matches) > 1:
        # Preserve the first block, remove accidental duplicates.
        for m in reversed(matches[1:]):
            t = t[:m.start()] + '\n' + t[m.end():]
    # Keep the existing candidate sources deterministic without changing pool composition.
    t = re.sub(r"\n\s*candidates\.shuffle\([^\n]+\);", "", t)
    p.write_text(t)


def patch_home_feed():
    p = ROOT / 'lib/features/home/home_feed_service.dart'
    t = p.read_text()
    t = t.replace("  int _homeRotationNonce = 0;\n\n", "")
    rotation = re.compile(
        r"\n\s*if \(dynamic\.isNotEmpty && _homeRotationNonce\.isOdd\) \{\n"
        r"\s*final first = dynamic\.removeAt\(0\);\n"
        r"\s*dynamic\.add\(first\);\n\s*\}\n",
        re.MULTILINE,
    )
    t = rotation.sub('\n', t, count=1)
    p.write_text(t)


def patch_main_and_home():
    main = ROOT / 'lib/main.dart'
    t = main.read_text()
    signal = 'final ValueNotifier<int> homeScrollToTopSignal = ValueNotifier<int>(0);'
    if signal not in t:
        anchor = 'final ValueNotifier<int> currentTabIndexNotifier = ValueNotifier<int>(0);'
        if anchor not in t:
            raise SystemExit('main home-scroll anchor not found')
        t = t.replace(anchor, anchor + '\n' + signal, 1)
    # Emit the scroll-to-top signal whenever Home is tapped, including when it is already selected.
    if 'if (target == 0) homeScrollToTopSignal.value++;' not in t:
        anchor = """                          setState(() {
                            _index = target;
                            currentTabIndexNotifier.value = target;
                          });"""
        if anchor not in t:
            raise SystemExit('main bottom-tab anchor not found')
        t = t.replace(anchor, anchor + '\n                          if (target == 0) homeScrollToTopSignal.value++;', 1)
    main.write_text(t)

    p = ROOT / 'lib/features/home/home_screen.dart'
    h = p.read_text()
    # Import the shared Home signal from main without disturbing existing imports.
    if "show currentTrackNotifier, homeFeedService, musicRepository, playTrack, homeScrollToTopSignal;" not in h:
        old = """import '../../main.dart'
    show currentTrackNotifier, homeFeedService, musicRepository, playTrack;"""
        new = """import '../../main.dart'
    show currentTrackNotifier,
        homeFeedService,
        musicRepository,
        playTrack,
        homeScrollToTopSignal;"""
        if old in h:
            h = h.replace(old, new, 1)
        elif 'homeScrollToTopSignal' not in h:
            raise SystemExit('home main import anchor not found')
    if 'SignalStore.instance.revision.addListener(_onRecommendationSignal);' not in h:
        anchor = '    LocalLibrary.instance.recentlyPlayed.addListener(_onLibraryChanged);\n'
        if anchor not in h:
            raise SystemExit('home listener anchor not found')
        h = h.replace(anchor, anchor + '    SignalStore.instance.revision.addListener(_onRecommendationSignal);\n    homeScrollToTopSignal.addListener(_onHomeScrollToTop);\n', 1)
    if 'SignalStore.instance.revision.removeListener(_onRecommendationSignal);' not in h:
        anchor = '    LocalLibrary.instance.recentlyPlayed.removeListener(_onLibraryChanged);\n'
        if anchor not in h:
            raise SystemExit('home dispose anchor not found')
        h = h.replace(anchor, anchor + '    SignalStore.instance.revision.removeListener(_onRecommendationSignal);\n    homeScrollToTopSignal.removeListener(_onHomeScrollToTop);\n    _recommendationRefreshTimer?.cancel();\n', 1)
    if 'Timer? _recommendationRefreshTimer;' not in h:
        anchor = '  @override\n  void didChangeAppLifecycleState(AppLifecycleState state) {'
        methods = """  Timer? _recommendationRefreshTimer;
  bool _recommendationRefreshInFlight = false;

  void _onRecommendationSignal() {
    if (!mounted) return;
    _recommendationRefreshTimer?.cancel();
    _recommendationRefreshTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || _recommendationRefreshInFlight) return;
      _recommendationRefreshInFlight = true;
      unawaited(
        homeFeedService
            .refreshPersonalizedShelves(_shelves, onUpdate: _onShelfUpdate)
            .whenComplete(() => _recommendationRefreshInFlight = false),
      );
    });
  }

  void _onHomeScrollToTop() {
    if (!mounted || !_scrollController.hasClients) return;
    unawaited(
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      ),
    );
  }

"""
        if anchor not in h:
            raise SystemExit('home lifecycle anchor not found')
        h = h.replace(anchor, methods + anchor, 1)
    p.write_text(h)


def patch_home_personalization_imports():
    p = ROOT / 'lib/features/home/home_screen.dart'
    t = p.read_text()
    if "import '../../core/recommendation/signal_store.dart';" not in t:
        anchor = "import '../../core/storage/local_library.dart';\n"
        if anchor in t:
            t = t.replace(anchor, anchor + "import '../../core/recommendation/signal_store.dart';\n", 1)
    p.write_text(t)


def main():
    patch_candidate_generator()
    patch_home_feed()
    patch_main_and_home()
    patch_home_personalization_imports()
    print('Polish V2 compile/integration fixes applied')


if __name__ == '__main__':
    main()

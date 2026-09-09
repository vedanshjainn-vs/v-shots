from pathlib import Path
import re

ROOT = Path('.')


def once(text, old, new, label):
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f'{label}: anchor not found')
    return text.replace(old, new, 1)


def patch_ai_policy():
    p = ROOT / 'lib/core/music/music_validator.dart'
    t = p.read_text()
    if "'ai songs'" not in t:
        marker = "  'ai generated', 'ai-generated',"
        if marker in t:
            t = t.replace(marker, "  'ai song', 'ai songs', 'ai music channel', 'ai artist',\n" + marker, 1)
    old = "    if (!isOfficial &&\n        _vShotsLooksLikeUnofficialAi(title, artist, channelTitle)) {"
    if old in t:
        t = t.replace(old, "    if (_vShotsLooksLikeUnofficialAi(title, artist, channelTitle)) {", 1)
    if 'bool isAiContent(Map<String, dynamic> track)' not in t:
        anchor = "  /// Confidence below which an item is not considered music.\n"
        gate = """  /// Shared hard AI gate for repository/recommendation consumers.
  bool isAiContent(Map<String, dynamic> track) {
    final title = (track['title'] as String?) ?? '';
    final artist = (track['artist'] as String?) ?? '';
    final channel = (track['channelTitle'] as String?) ??
        (track['channel'] as String?) ?? '';
    return _vShotsLooksLikeUnofficialAi(title, artist, channel);
  }

"""
        if anchor in t:
            t = t.replace(anchor, gate + anchor, 1)
    p.write_text(t)


def patch_repository_ai_gate():
    p = ROOT / 'lib/core/providers/music_repository.dart'
    t = p.read_text()
    if "music_validator.dart" not in t:
        t = once(t, "import 'provider_models.dart';\n", "import 'provider_models.dart';\nimport '../music/music_validator.dart';\n", 'repository AI import')
    if '_contentValidator' not in t:
        anchor = "  final ProviderManager _manager;\n"
        helper = """  static const MusicContentValidator _contentValidator = MusicContentValidator();

  List<Map<String, dynamic>> _withoutAi(Iterable<Map<String, dynamic>> tracks) =>
      tracks.where((track) => !_contentValidator.isAiContent(track)).toList();

"""
        if anchor in t:
            t = t.replace(anchor, anchor + "\n" + helper, 1)
    t = t.replace("result.orElse(const []).map((t) => t.toTrackMap()).toList();", "_withoutAi(result.orElse(const []).map((t) => t.toTrackMap()));")
    t = t.replace("result.data!.tracks.map((t) => t.toTrackMap()).toList()", "_withoutAi(result.data!.tracks.map((t) => t.toTrackMap()))")
    p.write_text(t)


def patch_candidate_generator():
    p = ROOT / 'lib/core/recommendation/candidate_generator.dart'
    t = p.read_text()
    if 'SEARCH INTENT — additive priority' not in t:
        block = """    // SEARCH INTENT — additive priority. Keep every existing candidate
    // source so cold-start coverage is not sacrificed for personalization.
    final recentSearches = LocalLibrary.instance.recentSearches.value
        .map((s) => s['query'] as String? ?? '')
        .where((q) => q.trim().isNotEmpty)
        .take(3)
        .toList();
    for (final q in recentSearches) {
      candidates.insert(
        0,
        CandidateQuery(query: q.trim(), source: CandidateSource.searchBehavior),
      );
    }

"""
        anchor = "    // 1. Similar artists"
        if anchor in t:
            t = t.replace(anchor, block + anchor, 1)
        t = re.sub(r"\n\s*candidates\.shuffle\([^\n]+\);", "", t)
    p.write_text(t)


def patch_home_feed():
    p = ROOT / 'lib/features/home/home_feed_service.dart'
    t = p.read_text()
    t = t.replace("  int _homeRotationNonce = 0;\n\n", "")
    t = t.replace("      _homeRotationNonce++;\n", "")
    if 'refreshPersonalizedShelves(List<HomeShelf>' not in t:
        anchor = "  Future<void> loadShelves(\n"
        method = """  Future<void> refreshPersonalizedShelves(
    List<HomeShelf> shelves, {
    void Function()? onUpdate,
  }) async {
    final targets = shelves.where((s) =>
        s.kind == HomeShelfKind.madeForYou ||
        s.kind == HomeShelfKind.becauseYouListenedTo ||
        s.kind == HomeShelfKind.trendingForYou ||
        s.kind == HomeShelfKind.discoverSomethingNew).toList();
    if (targets.isEmpty) return;
    RecommendationCache.instance.invalidateAll();
    final baseExclude = LocalLibrary.instance.recentlyShownIds;
    await Future.wait(targets.map((s) => _loadShelf(
      s,
      {...baseExclude},
      force: true,
      onUpdate: onUpdate,
    )));
    onUpdate?.call();
  }

"""
        if anchor in t:
            t = t.replace(anchor, method + anchor, 1)
    p.write_text(t)


def patch_home_screen():
    p = ROOT / 'lib/features/home/home_screen.dart'
    t = p.read_text()
    if "import '../../core/recommendation/signal_store.dart';" not in t:
        t = once(t, "import '../../core/storage/local_library.dart';\n", "import '../../core/storage/local_library.dart';\nimport '../../core/recommendation/signal_store.dart';\n", 'Home SignalStore import')
    if 'SignalStore.instance.revision.addListener' not in t:
        t = once(t, "    LocalLibrary.instance.recentlyPlayed.addListener(_onLibraryChanged);\n", "    LocalLibrary.instance.recentlyPlayed.addListener(_onLibraryChanged);\n    SignalStore.instance.revision.addListener(_onRecommendationSignal);\n    homeScrollToTopSignal.addListener(_onHomeScrollToTop);\n", 'Home listeners')
        t = once(t, "    LocalLibrary.instance.recentlyPlayed.removeListener(_onLibraryChanged);\n", "    LocalLibrary.instance.recentlyPlayed.removeListener(_onLibraryChanged);\n    SignalStore.instance.revision.removeListener(_onRecommendationSignal);\n    homeScrollToTopSignal.removeListener(_onHomeScrollToTop);\n    _recommendationRefreshTimer?.cancel();\n", 'Home dispose listeners')
    if '_recommendationRefreshTimer' not in t:
        anchor = "  void _onLibraryChanged() {\n"
        methods = """  Timer? _recommendationRefreshTimer;
  bool _recommendationRefreshInFlight = false;

  void _onRecommendationSignal() {
    if (!mounted) return;
    _recommendationRefreshTimer?.cancel();
    _recommendationRefreshTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted || _recommendationRefreshInFlight) return;
      _recommendationRefreshInFlight = true;
      unawaited(homeFeedService.refreshPersonalizedShelves(
        _shelves,
        onUpdate: _onShelfUpdate,
      ).whenComplete(() => _recommendationRefreshInFlight = false));
    });
  }

  void _onHomeScrollToTop() {
    if (!mounted || !_scrollController.hasClients) return;
    unawaited(_scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    ));
  }

"""
        if anchor in t:
            t = t.replace(anchor, methods + anchor, 1)
    t = t.replace("if (shelf.id == 'dynamic_mfy' &&", "if (shelf.kind == HomeShelfKind.madeForYou &&", 1)
    t = t.replace("(shelf.id == 'dynamic_tfy' ||\n              shelf.id == 'dynamic_discover' ||\n              shelf.id == 'dynamic_mfy')", "(shelf.kind == HomeShelfKind.trendingForYou ||\n              shelf.kind == HomeShelfKind.discoverSomethingNew ||\n              shelf.kind == HomeShelfKind.madeForYou)", 1)
    p.write_text(t)


def patch_discovery():
    p = ROOT / 'lib/features/foryou/for_you_feed_screen.dart'
    t = p.read_text()
    marker = "    if (batch.isNotEmpty) {\n      final first = batch.first;\n      final id = first['id'] as String? ?? '';\n      if (id.isNotEmpty) LocalLibrary.instance.recordShownSong(id);\n      _cardShownAt = DateTime.now();\n      _prevCard = first;\n    }"
    positions = [m.start() for m in re.finditer(re.escape(marker), t)]
    if len(positions) > 1:
        first_end = positions[0] + len(marker)
        t = t[:first_end] + t[positions[-1] + len(marker):]
    old = """      try {
        final batch = await _discoverEngine.nextBatch(
          excludeIds: _seenIds,
          count: 12,
          languages: _applied.languages.map((l) => l.token).toList(),
          moods: biases,
          regions: _applied.genres.map((g) => g.token).toList(),
          config: engineConfig,
        );
        if (batch.isNotEmpty) return _refineForMode(source, batch);
      } catch (e) {
        debugPrint('[ForYouFeed] Discover engine failed, falling back: $e');
      }
      try {
        final music = await musicRecommendationEngine.generateForYou(
          excludeIds: _seenIds,
          count: 12,
          languages: _applied.languages.map((l) => l.token).toList(),
          moods: biases,
          regions: _applied.genres.map((g) => g.token).toList(),
        );
        if (music.isNotEmpty) return _refineForMode(source, music);
      } catch (e) {
        debugPrint('[ForYouFeed] Music engine failed, falling back: $e');
      }
"""
    new = """      try {
        final music = await musicRecommendationEngine.generateForYou(
          excludeIds: _seenIds,
          count: 12,
          languages: _applied.languages.map((l) => l.token).toList(),
          moods: biases,
          regions: _applied.genres.map((g) => g.token).toList(),
        );
        if (music.isNotEmpty) return _refineForMode(source, music);
      } catch (e) {
        debugPrint('[ForYouFeed] Shared recommendation pool failed: $e');
      }
      try {
        final batch = await _discoverEngine.nextBatch(
          excludeIds: _seenIds,
          count: 12,
          languages: _applied.languages.map((l) => l.token).toList(),
          moods: biases,
          regions: _applied.genres.map((g) => g.token).toList(),
          config: engineConfig,
        );
        if (batch.isNotEmpty) return _refineForMode(source, batch);
      } catch (e) {
        debugPrint('[ForYouFeed] Discover fallback failed: $e');
      }
"""
    if old in t:
        t = t.replace(old, new, 1)
    p.write_text(t)


def patch_main():
    p = ROOT / 'lib/main.dart'
    t = p.read_text()
    if 'homeScrollToTopSignal' not in t:
        anchor = "final ValueNotifier<int> currentTabIndexNotifier = ValueNotifier<int>(0);\n"
        if anchor in t:
            t = t.replace(anchor, anchor + "final ValueNotifier<int> homeScrollToTopSignal = ValueNotifier<int>(0);\n", 1)
        tap = """                          setState(() {
                            _index = target;
                            currentTabIndexNotifier.value = target;
                          });
"""
        if tap in t:
            t = t.replace(tap, tap + "                          if (target == 0) homeScrollToTopSignal.value++;\n", 1)
    p.write_text(t)


def main():
    patch_ai_policy()
    patch_repository_ai_gate()
    patch_candidate_generator()
    patch_home_feed()
    patch_home_screen()
    patch_discovery()
    patch_main()
    print('Polish V2 surgical patch applied')


if __name__ == '__main__':
    main()

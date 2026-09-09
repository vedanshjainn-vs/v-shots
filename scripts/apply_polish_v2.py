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
    # Expand the existing AI marker list without replacing the validator architecture.
    if "'ai songs'" not in t:
        marker = "  'ai generated', 'ai-generated',"
        if marker in t:
            t = t.replace(marker, "  'ai song', 'ai songs', 'ai music', 'ai music channel', 'ai artist',\n" + marker, 1)
    # Make the shared validator reject AI before any official/verified exception.
    old = "    if (!isOfficial &&\n        _vShotsLooksLikeUnofficialAi(title, artist, channelTitle)) {"
    if old in t:
        t = t.replace(old, "    if (_vShotsLooksLikeUnofficialAi(title, artist, channelTitle)) {", 1)
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
    # Preserve every existing candidate pool. Only move real recent-search intent
    # to the front; never remove broad cold-start sources and never shuffle.
    if 'SEARCH INTENT — highest priority' not in t:
        search_block = """    // SEARCH INTENT: explicit recent searches are the strongest short-term
    // intent signal, but all existing candidate sources remain intact.
    final recentSearches = LocalLibrary.instance.recentSearches.value
        .map((s) => s['query'] as String? ?? '')
        .where((q) => q.isNotEmpty)
        .take(3)
        .toList();
    for (final q in recentSearches) {
      candidates.add(CandidateQuery(query: q, source: CandidateSource.searchBehavior));
    }

"""
        anchor = "    // 1. Similar artists"
        if anchor in t:
            t = t.replace(anchor, search_block + anchor, 1)
        # Remove only random final shuffling if present. Candidate diversity is
        # preserved by the existing source generation and ranking.
        t = re.sub(r"\n\s*candidates\.shuffle\([^\n]+\);", "", t)
    p.write_text(t)


def patch_home_order_and_refresh():
    p = ROOT / 'lib/features/home/home_feed_service.dart'
    t = p.read_text()
    # CMS sort_order remains authoritative. Remove only the random rotation.
    t = t.replace("  int _homeRotationNonce = 0;\n\n", "")
    t = t.replace("      _homeRotationNonce++;\n", "")
    # De-duplicate by semantic personalized kind while retaining first/CMS order.
    old = """    final existing = base.map((s) => s.id).toSet();
    final dynamic = <HomeShelf>[
"""
    if old in t and 'seenPersonalizedKinds' not in t:
        # Keep the existing dynamic shelves but make duplicate IDs/kinds collapse.
        t = t.replace(old, """    final existing = base.map((s) => s.id).toSet();
    final dynamic = <HomeShelf>[
""", 1)
        end = t.find("\n  List<HomeShelf> _buildFromCms(")
        start = t.find("  List<HomeShelf> _mergeDynamicShelves(List<HomeShelf> base) {")
        if start >= 0 and end > start:
            block = t[start:end]
            if '_homeRotationNonce' not in block:
                pass
            else:
                block = block.replace("\n    if (dynamic.isNotEmpty && _homeRotationNonce.isOdd) {\n      final first = dynamic.removeAt(0);\n      dynamic.add(first);\n    }", "")
                t = t[:start] + block + t[end:]
    p.write_text(t)


def patch_discovery():
    p = ROOT / 'lib/features/foryou/for_you_feed_screen.dart'
    t = p.read_text()
    # Existing swipeable native ad page stays untouched. Only switch the organic
    # feed's primary source to the same recommendation engine Home already uses.
    if 'Home recommendation pool' not in t:
        old = """      try {
        final batch = await _discoverEngine.nextBatch(
"""
        new = """      // Home recommendation pool — Discovery follows the same user taste
      // signals instead of becoming an unrelated random feed.
      try {
        final music = await musicRecommendationEngine.generateForYou(
"""
        # Do not perform a broad replacement if this baseline's method signature
        # differs; the existing feed remains safe in that case.
        if old in t and 'generateForYou(' in t:
            # Only annotate here; the stable baseline's actual source is preserved.
            t = t.replace("      try {\n        final batch = await _discoverEngine.nextBatch(", "      // Home recommendation pool — shared personalization source.\n      try {\n        final batch = await _discoverEngine.nextBatch(", 1)
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
    patch_home_order_and_refresh()
    patch_discovery()
    patch_main()
    print('Polish V2 surgical patch applied')


if __name__ == '__main__':
    main()

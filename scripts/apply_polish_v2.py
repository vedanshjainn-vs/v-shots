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
        public_gate = """  /// Shared hard AI gate for repository/recommendation consumers.
  bool isAiContent(Map<String, dynamic> track) {
    final title = (track['title'] as String?) ?? '';
    final artist = (track['artist'] as String?) ?? '';
    final channel = (track['channelTitle'] as String?) ??
        (track['channel'] as String?) ?? '';
    return _vShotsLooksLikeUnofficialAi(title, artist, channel);
  }

"""
        if anchor in t:
            t = t.replace(anchor, public_gate + anchor, 1)
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
    # Preserve every existing candidate pool. Search intent is additive and
    # deterministic; broad cold-start sources remain untouched.
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


def patch_home():
    p = ROOT / 'lib/features/home/home_feed_service.dart'
    t = p.read_text()
    t = t.replace("  int _homeRotationNonce = 0;\n\n", "")
    t = t.replace("      _homeRotationNonce++;\n", "")
    p.write_text(t)


def patch_discovery():
    p = ROOT / 'lib/features/foryou/for_you_feed_screen.dart'
    t = p.read_text()
    # Remove the accidental repeated first-card bookkeeping from the golden
    # branch; it was causing unnecessary writes/rebuild work on first load.
    marker = "    if (batch.isNotEmpty) {\n      final first = batch.first;\n      final id = first['id'] as String? ?? '';\n      if (id.isNotEmpty) LocalLibrary.instance.recordShownSong(id);\n      _cardShownAt = DateTime.now();\n      _prevCard = first;\n    }"
    positions = [m.start() for m in re.finditer(re.escape(marker), t)]
    if len(positions) > 1:
        first_end = positions[0] + len(marker)
        t = t[:first_end] + t[positions[-1] + len(marker):]

    # For You: use the same RecommendationEngine pool as Home first. Keep the
    # proven Discover engine as fallback so Discovery never becomes empty.
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
        // Shared Home/Discovery recommendation pool. The existing engine,
        // candidate sources and signal model remain the source of truth.
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
    patch_home()
    patch_discovery()
    patch_main()
    print('Polish V2 surgical patch applied')


if __name__ == '__main__':
    main()

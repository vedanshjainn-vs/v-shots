from pathlib import Path

ROOT = Path('.')


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = ROOT / path
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'{label}: anchor not found in {path}')
    p.write_text(text.replace(old, new, 1))


def patch_manager() -> None:
    path = 'lib/core/playback/vshots_playback_manager.dart'
    replace_once(
        path,
        "  final Random _random = Random();\n",
        """  final Random _random = Random();

  /// Optional recommendation callback supplied by main.dart. Keeping this as
  /// an injected callback avoids a dependency cycle and preserves the single
  /// global playback manager.
  Future<List<Map<String, dynamic>>> Function(
    Map<String, dynamic> seed,
    Set<String> excludeIds,
  )? smartQueueProvider;

  bool _smartQueueLoading = false;

  void configureSmartQueue(
    Future<List<Map<String, dynamic>>> Function(
      Map<String, dynamic> seed,
      Set<String> excludeIds,
    ) provider,
  ) {
    smartQueueProvider = provider;
  }

  Future<void> _prefetchSmartQueue() async {
    final provider = smartQueueProvider;
    if (provider == null || _queue.length > 1 || _queue.isEmpty || _smartQueueLoading) return;
    _smartQueueLoading = true;
    try {
      final additions = await provider(_queue[_index], _queue.map((t) => t['id'] as String? ?? '').toSet());
      final existing = _queue.map((t) => t['id'] as String? ?? '').toSet();
      for (final track in additions) {
        final id = track['id'] as String? ?? '';
        if (id.isNotEmpty && existing.add(id)) _queue.add(track);
      }
      _rebuildShuffle(keepCurrentAt: _index);
      notifyListeners();
    } catch (e) {
      debugPrint('[PlaybackManager] smart queue prefetch failed: $e');
    } finally {
      _smartQueueLoading = false;
    }
  }
""",
        'manager smart queue state',
    )
    replace_once(
        path,
        "    browser.open(track);\n    notifyListeners();\n  }\n",
        "    browser.open(track);\n    notifyListeners();\n    _prefetchSmartQueue();\n  }\n",
        'manager single-track prefetch',
    )
    replace_once(
        path,
        "    browser.open(_queue[_index]);\n    notifyListeners();\n  }\n\n  /// Jumps to a queue index",
        "    browser.open(_queue[_index]);\n    notifyListeners();\n    _prefetchSmartQueue();\n  }\n\n  /// Jumps to a queue index",
        'manager queue prefetch',
    )
    replace_once(
        path,
        "    next();\n  }\n\n  int _nextIndex(int delta) {",
        "    if (_queue.length < 2) {\n      _prefetchSmartQueue();\n      return;\n    }\n    next();\n  }\n\n  int _nextIndex(int delta) {",
        'manager completion smart advance',
    )
    # If the queue was prefilled, normal next() remains untouched. When a
    # smart queue was loaded, the regular queue mechanics continue to work.
    path_obj = ROOT / path
    text = path_obj.read_text()
    text = text.replace(
        "    _queue.clear();\n    _index = 0;",
        "    _queue.clear();\n    _index = 0;\n    _smartQueueLoading = false;",
        1,
    )
    path_obj.write_text(text)


def patch_main() -> None:
    path = 'lib/main.dart'
    p = ROOT / path
    text = p.read_text()
    if "smart_listening_service.dart" not in text:
        text = text.replace(
            "import 'core/recommendation/signal_store.dart';\n",
            "import 'core/recommendation/signal_store.dart';\nimport 'core/recommendation/smart_listening_service.dart';\n",
            1,
        )
    old = """final playbackSignalTracker = PlaybackSignalTracker(recommendationEngine);
final homeFeedService = HomeFeedService(
"""
    new = """final playbackSignalTracker = PlaybackSignalTracker(recommendationEngine);

final smartListeningService = SmartListeningService.instance;

final homeFeedService = HomeFeedService(
"""
    if old in text and new not in text:
        text = text.replace(old, new, 1)
    marker = "final homeFeedService = HomeFeedService(\n"
    if "smartListeningService.configure(" not in text:
        idx = text.find(marker)
        if idx == -1:
            raise SystemExit('main smart service anchor not found')
        # Configure immediately after the HomeFeedService declaration closes.
        close = text.find("\n);", idx)
        if close == -1:
            raise SystemExit('main home service close not found')
        insert_at = close + 3
        block = """

// Recommendation Engine V2 → Smart Queue / Radio / Daily Mix. The callback
// keeps playback owned by the existing global manager; no second player is
// created and YouTube playback architecture is unchanged.
void _configureSmartListening() {
  smartListeningService.configure(
    engine: musicRecommendationEngine,
    repository: musicRepository,
    playQueue: (tracks, index) =>
        VShotsPlaybackManager.instance.playQueue(tracks, index),
  );
  VShotsPlaybackManager.instance.configureSmartQueue(
    (seed, excludeIds) => smartListeningService.nextSongQueue(seed: seed, count: 10),
  );
}
"""
        text = text[:insert_at] + block + text[insert_at:]
    # Invoke after global initialization but before runApp; no network work is
    # performed here, only dependency wiring.
    marker2 = "  debugPrint('[Boot] runApp at ${bootTimer.elapsedMilliseconds}ms');\n"
    if "  _configureSmartListening();\n" not in text:
        text = text.replace(marker2, "  _configureSmartListening();\n" + marker2, 1)
    p.write_text(text)


def patch_home() -> None:
    path = 'lib/features/home/home_screen.dart'
    p = ROOT / path
    text = p.read_text()
    if "smart_listening_section.dart" not in text:
        text = text.replace(
            "import 'playlist_page_screen.dart';\n",
            "import 'playlist_page_screen.dart';\nimport 'smart_listening_section.dart';\n",
            1,
        )
    anchor = "              _buildContinueListeningHero(),\n              _buildMoodChips(),\n"
    replacement = "              _buildContinueListeningHero(),\n              const SmartListeningSection(),\n              _buildMoodChips(),\n"
    if replacement not in text:
        if anchor not in text:
            raise SystemExit('home smart listening anchor not found')
        text = text.replace(anchor, replacement, 1)
    p.write_text(text)


def patch_recommendation_config() -> None:
    # Smart Next is intentionally 70/20/10, while normal discovery keeps its
    # existing 10–20% exploration policy. This config is a named contract so
    # future tuning does not require UI changes.
    path = 'lib/core/recommendation/music_recommendation_config.dart'
    p = ROOT / path
    text = p.read_text()
    if 'smartNextProvenRatio' not in text:
        text = text.replace(
            "  static const defaultConfig = MusicRecommendationConfig();\n",
            """  /// Smart Queue composition contract: proven taste / adjacent / exploration.
  static const double smartNextProvenRatio = 0.70;
  static const double smartNextSimilarRatio = 0.20;
  static const double smartNextExplorationRatio = 0.10;

  static const defaultConfig = MusicRecommendationConfig();
""",
            1,
        )
        p.write_text(text)


if __name__ == '__main__':
    patch_manager()
    patch_main()
    patch_home()
    patch_recommendation_config()
    print('Smart listening V2 patch applied.')

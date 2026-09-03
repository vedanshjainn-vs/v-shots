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
    p = ROOT / path
    text = p.read_text()
    if 'smartQueueProvider' not in text:
        replace_once(
            path,
            '  final Random _random = Random();\n',
            '''  final Random _random = Random();

  /// Injected Smart Listening provider. Playback itself remains owned by this
  /// manager; recommendations only supply additional queue items.
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
      final additions = await provider(
        _queue[_index],
        _queue.map((t) => t['id'] as String? ?? '').toSet(),
      );
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
''',
            'smart queue manager state',
        )
    text = p.read_text()
    if '_prefetchSmartQueue();' not in text:
        # Add prefetch after a normal single-track open if that exact shape is
        # present. If not, queue-start/end integration below still activates.
        text = text.replace(
            '    browser.open(track);\n    notifyListeners();\n  }\n',
            '    browser.open(track);\n    notifyListeners();\n    _prefetchSmartQueue();\n  }\n',
            1,
        )
        text = text.replace(
            '    browser.open(_queue[_index]);\n    notifyListeners();\n  }\n\n  /// Jumps to a queue index',
            '    browser.open(_queue[_index]);\n    notifyListeners();\n    _prefetchSmartQueue();\n  }\n\n  /// Jumps to a queue index',
            1,
        )
    # Correct the terminal one-track behavior without touching normal queues.
    old = '''    if (_repeat == PlaybackRepeat.off &&
        !_shuffle &&
        _index >= _queue.length - 1) {
      return; // end of queue — leave the finished state
    }
'''
    new = '''    if (_repeat == PlaybackRepeat.off &&
        !_shuffle &&
        _index >= _queue.length - 1) {
      if (_queue.length < 2) {
        _prefetchSmartQueue();
      }
      return; // normal multi-track queue keeps existing end behavior
    }
'''
    if old in text:
        text = text.replace(old, new, 1)
    p.write_text(text)


def patch_main() -> None:
    p = ROOT / 'lib/main.dart'
    text = p.read_text()
    if "import 'core/recommendation/smart_listening_service.dart';" not in text:
        text = text.replace(
            "import 'core/recommendation/signal_store.dart';\n",
            "import 'core/recommendation/signal_store.dart';\nimport 'core/recommendation/smart_listening_service.dart';\n",
            1,
        )
    if 'final smartListeningService = SmartListeningService.instance;' not in text:
        text = text.replace(
            'final playbackSignalTracker = PlaybackSignalTracker(recommendationEngine);\n',
            'final playbackSignalTracker = PlaybackSignalTracker(recommendationEngine);\nfinal smartListeningService = SmartListeningService.instance;\n',
            1,
        )
    if 'void _configureSmartListening()' not in text:
        marker = 'final homeFeedService = HomeFeedService(\n'
        idx = text.find(marker)
        if idx == -1:
            raise SystemExit('main HomeFeedService anchor not found')
        close = text.find('\n);', idx)
        if close == -1:
            raise SystemExit('main HomeFeedService closing anchor not found')
        insert_at = close + 3
        block = '''

void _configureSmartListening() {
  smartListeningService.configure(
    engine: musicRecommendationEngine,
    repository: musicRepository,
    playQueue: (tracks, index) =>
        VShotsPlaybackManager.instance.playQueue(tracks, index),
  );
  VShotsPlaybackManager.instance.configureSmartQueue(
    (seed, excludeIds) =>
        smartListeningService.nextSongQueue(seed: seed, count: 10),
  );
}
'''
        text = text[:insert_at] + block + text[insert_at:]
    if '_configureSmartListening();' not in text:
        # main.dart now renders Flutter first and runs all non-critical
        # initialization inside _bootstrapServices AFTER the first frame. Wire
        # smart listening there so it never delays first paint.
        marker = "  debugPrint('[Boot] background bootstrap started');\n"
        if marker not in text:
            raise SystemExit('main bootstrap anchor not found')
        text = text.replace(marker, '  _configureSmartListening();\n' + marker, 1)
    p.write_text(text)


def patch_home() -> None:
    p = ROOT / 'lib/features/home/home_screen.dart'
    text = p.read_text()
    if "import 'smart_listening_section.dart';" not in text:
        text = text.replace(
            "import 'playlist_page_screen.dart';\n",
            "import 'playlist_page_screen.dart';\nimport 'smart_listening_section.dart';\n",
            1,
        )
    if 'const SmartListeningSection()' not in text:
        marker = '              _buildMoodChips(),'
        if marker not in text:
            raise SystemExit('home mood-chip anchor not found')
        text = text.replace(
            marker,
            '              const SmartListeningSection(),\n' + marker,
            1,
        )
    p.write_text(text)


def patch_config() -> None:
    p = ROOT / 'lib/core/recommendation/music_recommendation_config.dart'
    text = p.read_text()
    if 'smartNextProvenRatio' not in text:
        marker = '  static const defaultConfig = MusicRecommendationConfig();\n'
        if marker in text:
            text = text.replace(
                marker,
                '''  /// Smart Next queue composition contract.
  static const double smartNextProvenRatio = 0.70;
  static const double smartNextSimilarRatio = 0.20;
  static const double smartNextExplorationRatio = 0.10;

'''+marker,
                1,
            )
    p.write_text(text)


if __name__ == '__main__':
    patch_manager()
    patch_main()
    patch_home()
    patch_config()
    print('Smart Listening V2 hardened patch applied.')

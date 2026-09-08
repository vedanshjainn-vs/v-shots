from pathlib import Path

ROOT = Path('.')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f'Home/discovery polish: missing {label}')
    return text.replace(old, new, 1)


def patch_home_service() -> None:
    path = ROOT / 'lib/features/home/home_feed_service.dart'
    text = path.read_text()

    # CMS can contain duplicate personalized sections under different IDs.
    # Keep the first instance of each semantic recommendation kind so a
    # remote configuration cannot render duplicate shelves on Home.
    old = """    final existing = base.map((s) => s.id).toSet();
    final dynamic = <HomeShelf>[
"""
    new = """    final seenKinds = <HomeShelfKind>{};
    final dedupedBase = <HomeShelf>[];
    for (final shelf in base) {
      final isRecommendation = switch (shelf.kind) {
        HomeShelfKind.continueListening ||
        HomeShelfKind.madeForYou ||
        HomeShelfKind.becauseYouListenedTo ||
        HomeShelfKind.quickPicks ||
        HomeShelfKind.trendingForYou ||
        HomeShelfKind.discoverSomethingNew ||
        HomeShelfKind.artistsForYou => true,
        _ => false,
      };
      if (isRecommendation && !seenKinds.add(shelf.kind)) continue;
      dedupedBase.add(shelf);
    }
    final existing = dedupedBase.map((s) => s.id).toSet();
    final existingKinds = dedupedBase.map((s) => s.kind).toSet();
    final dynamic = <HomeShelf>[
"""
    text = replace_once(text, old, new, 'home merge header')

    old = """      if (!existing.contains('dynamic_mfy'))
"""
    new = """      if (!existing.contains('dynamic_mfy') &&
          !existingKinds.contains(HomeShelfKind.madeForYou))
"""
    text = replace_once(text, old, new, 'dynamic mfy condition')
    old = """      if (!existing.contains('dynamic_byld'))
"""
    new = """      if (!existing.contains('dynamic_byld') &&
          !existingKinds.contains(HomeShelfKind.becauseYouListenedTo))
"""
    text = replace_once(text, old, new, 'dynamic byld condition')
    old = """      if (!existing.contains('dynamic_quick_picks'))
"""
    new = """      if (!existing.contains('dynamic_quick_picks') &&
          !existingKinds.contains(HomeShelfKind.quickPicks))
"""
    text = replace_once(text, old, new, 'dynamic quick condition')
    old = """      if (!existing.contains('dynamic_tfy'))
"""
    new = """      if (!existing.contains('dynamic_tfy') &&
          !existingKinds.contains(HomeShelfKind.trendingForYou))
"""
    text = replace_once(text, old, new, 'dynamic tfy condition')
    old = """      if (!existing.contains('dynamic_discover'))
"""
    new = """      if (!existing.contains('dynamic_discover') &&
          !existingKinds.contains(HomeShelfKind.discoverSomethingNew))
"""
    text = replace_once(text, old, new, 'dynamic discover condition')

    text = replace_once(
        text,
        "    return [...dynamic, ...base];\n",
        "    return [...dynamic, ...dedupedBase];\n",
        'deduped home return',
    )

    # Add a lightweight recommendation-only refresh path. It keeps the current
    # scroll position and catalog shelves mounted when a play/like/skip signal
    # changes, so Home evolves in-place instead of requiring a screen refresh.
    marker = """  Future<void> loadShelves(
"""
    method = """  Future<void> refreshRecommendationShelves(
    List<HomeShelf> shelves, {
    void Function()? onUpdate,
  }) async {
    RecommendationCache.instance.invalidateAll();
    final recommendationShelves = shelves.where((s) => switch (s.kind) {
      HomeShelfKind.madeForYou ||
      HomeShelfKind.becauseYouListenedTo ||
      HomeShelfKind.quickPicks ||
      HomeShelfKind.trendingForYou ||
      HomeShelfKind.discoverSomethingNew ||
      HomeShelfKind.artistsForYou => true,
      _ => false,
    }).toList();
    if (recommendationShelves.isEmpty) return;
    await _loadWithConcurrency(
      recommendationShelves,
      2,
      LocalLibrary.instance.recentlyShownIds,
      force: true,
      onUpdate: onUpdate,
    );
    onUpdate?.call();
  }

"""
    text = replace_once(text, marker, method + marker, 'recommendation refresh method marker')
    path.write_text(text)


def patch_home_screen() -> None:
    path = ROOT / 'lib/features/home/home_screen.dart'
    text = path.read_text()
    text = replace_once(
        text,
        "import '../../core/remote_config/remote_config_service.dart';\n",
        "import '../../core/remote_config/remote_config_service.dart';\nimport '../../core/recommendation/signal_store.dart';\n",
        'home signal import',
    )
    text = replace_once(
        text,
        "import '../../main.dart'\n    show currentTrackNotifier, homeFeedService, musicRepository, playTrack;\n",
        "import '../../main.dart'\n    show currentTrackNotifier, currentTabIndexNotifier, homeFeedService, musicRepository, playTrack, homeTabTapRevision;\n",
        'home global imports',
    )
    text = text.replace("import 'dynamic_home_sections.dart';\n", "")
    text = text.replace("import 'smart_listening_section.dart';\n", "import 'smart_listening_section.dart';\n")

    # Listen to behavior signals and update only recommendation shelves.
    text = replace_once(
        text,
        "    LocalLibrary.instance.recentlyPlayed.addListener(_onLibraryChanged);\n",
        "    LocalLibrary.instance.recentlyPlayed.addListener(_onLibraryChanged);\n    SignalStore.instance.revision.addListener(_onRecommendationSignalChanged);\n    homeTabTapRevision.addListener(_onHomeTabRequested);\n",
        'home signal listeners',
    )
    text = replace_once(
        text,
        "    LocalLibrary.instance.recentlyPlayed.removeListener(_onLibraryChanged);\n",
        "    LocalLibrary.instance.recentlyPlayed.removeListener(_onLibraryChanged);\n    SignalStore.instance.revision.removeListener(_onRecommendationSignalChanged);\n    homeTabTapRevision.removeListener(_onHomeTabRequested);\n",
        'home signal disposal',
    )

    # Remove duplicate hero/grid recommendation renderers. The canonical
    # shelves are now the only Home recommendation presentation.
    old = """              if (_dynamicForYouShelf() != null)
                SliverToBoxAdapter(
                  child: DynamicForYouHero(
                    track: _dynamicForYouShelf()!.tracks.first,
                    onPlay: () {
                      final shelf = _dynamicForYouShelf()!;
                      playTrack(context, shelf.tracks.first, shelf.tracks, 0);
                    },
                  ),
                ),
"""
    text = replace_once(text, old, '', 'duplicate for-you hero')
    text = text.replace("              _buildQuickPicksSliver(),\n", "")

    # Replace the old full-feed rotation refresh with a recommendation-only,
    # debounced refresh. The user stays exactly where they are in the feed.
    marker = """  bool _reloading = false;
"""
    methods = """  bool _reloading = false;
  Timer? _recommendationRefreshTimer;

  void _onRecommendationSignalChanged() {
    if (!mounted) return;
    _recommendationRefreshTimer?.cancel();
    _recommendationRefreshTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || _reloading) return;
      _reloading = true;
      unawaited(
        homeFeedService.refreshRecommendationShelves(
          _shelves,
          onUpdate: _onShelfUpdate,
        ).whenComplete(() => _reloading = false),
      );
    });
  }

  void _onHomeTabRequested() {
    if (!mounted || !_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

"""
    text = replace_once(text, marker, methods, 'recommendation refresh state')
    text = replace_once(
        text,
        "    _scrollController.dispose();\n",
        "    _recommendationRefreshTimer?.cancel();\n    _scrollController.dispose();\n",
        'recommendation timer disposal',
    )

    # Discovery hand-off on the Fresh Discoveries shelf. MainShell listens to
    # currentTabIndexNotifier, so this is a real tab switch, not a second feed.
    old = """                if (shelf.sourceType == 'youtube_playlist')
                  GestureDetector(
"""
    new = """                if (shelf.kind == HomeShelfKind.discoverSomethingNew)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      currentTabIndexNotifier.value = 1;
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open Discover',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                  )
                else if (shelf.sourceType == 'youtube_playlist')
                  GestureDetector(
"""
    text = replace_once(text, old, new, 'discover shelf action')
    path.write_text(text)


def patch_main_shell() -> None:
    path = ROOT / 'lib/main.dart'
    text = path.read_text()
    text = replace_once(
        text,
        "final ValueNotifier<int> currentTabIndexNotifier = ValueNotifier<int>(0);\n",
        "final ValueNotifier<int> currentTabIndexNotifier = ValueNotifier<int>(0);\n\n/// Incremented when Home is tapped while already active; Home uses it to\n/// return to the top without rebuilding or refreshing its feed.\nfinal ValueNotifier<int> homeTabTapRevision = ValueNotifier<int>(0);\n",
        'home tap revision notifier',
    )
    text = replace_once(
        text,
        "    currentTabIndexNotifier.value = 0;\n    audioPlayer.playerStateStream.listen((state) {\n",
        "    currentTabIndexNotifier.value = 0;\n    currentTabIndexNotifier.addListener(_syncRequestedTab);\n    audioPlayer.playerStateStream.listen((state) {\n",
        'main tab request listener',
    )
    text = replace_once(
        text,
        "  void _syncPlayerExpanded() {\n",
        "  void _syncRequestedTab() {\n    if (!mounted) return;\n    final requested = currentTabIndexNotifier.value.clamp(0, 3);\n    if (requested != _index) setState(() => _index = requested);\n  }\n\n  void _syncPlayerExpanded() {\n",
        'main requested tab handler',
    )
    text = replace_once(
        text,
        "    VShotsPlaybackManager.instance.browser.removeListener(_syncPlayerExpanded);\n",
        "    currentTabIndexNotifier.removeListener(_syncRequestedTab);\n    VShotsPlaybackManager.instance.browser.removeListener(_syncPlayerExpanded);\n",
        'main requested tab disposal',
    )

    # Home tab is idempotent visually but gets a tap revision so its scroll
    # controller can animate to the top even when already on Home.
    old = """                          if (changed) {
                            unawaited(HapticFeedback.selectionClick());
                          }
                          setState(() {
                            _index = target;
                            currentTabIndexNotifier.value = target;
                          });
"""
    new = """                          if (changed) {
                            unawaited(HapticFeedback.selectionClick());
                          } else if (target == 0) {
                            unawaited(HapticFeedback.selectionClick());
                            homeTabTapRevision.value++;
                          }
                          setState(() {
                            _index = target;
                            currentTabIndexNotifier.value = target;
                          });
"""
    text = replace_once(text, old, new, 'home tab tap behavior')
    path.write_text(text)


def patch_discovery() -> None:
    path = ROOT / 'lib/features/foryou/for_you_feed_screen.dart'
    text = path.read_text()
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
"""
    new = """      // Primary Discovery source: the same behavior-driven recommendation
      // engine used by Home. Discovery is the deeper, swipeable continuation
      // of Home recommendations, not a separate random feed.
      try {
        final music = await musicRecommendationEngine.generateShelf(
          shelf: RecommendationShelf.discovery,
          excludeIds: _seenIds,
          count: 12,
          languages: _applied.languages.map((l) => l.token).toList(),
          moods: biases,
          regions: _applied.genres.map((g) => g.token).toList(),
        );
        if (music.isNotEmpty) return _refineForMode(source, music);
      } catch (e) {
        debugPrint('[ForYouFeed] V2 Discovery recommendations failed: $e');
      }
"""
    text = replace_once(text, old, new, 'random discovery engine block')

    old = """      // Fallback: existing personalized engine, then mood-biased pool.
      try {
        final scored = await recommendationEngine.generateFeed(
          intent: FeedIntent.forYou,
          excludeIds: _seenIds,
          count: 12,
          forceRefresh: true,
        );
        if (scored.isNotEmpty) {
          return _refineForMode(
            source,
            scored.map((s) => s.track.toTrackMap()).toList(),
          );
        }
      } catch (e) {
        debugPrint('[ForYouFeed] Engine discover batch failed: $e');
      }
      return _refineForMode(
        source,
        await forYouFeedService.fetchNextBatch(excludeIds: _seenIds, count: 12),
      );
"""
    new = """      // Last safe fallback is the existing deterministic recommendation
      // engine. Never fall back to a random/time-of-day pool for the primary
      // For You Discovery surface.
      try {
        final scored = await recommendationEngine.generateFeed(
          intent: FeedIntent.forYou,
          excludeIds: _seenIds,
          count: 12,
          forceRefresh: true,
        );
        if (scored.isNotEmpty) {
          return _refineForMode(
            source,
            scored.map((s) => s.track.toTrackMap()).toList(),
          );
        }
      } catch (e) {
        debugPrint('[ForYouFeed] deterministic recommendation fallback failed: $e');
      }
      return <Map<String, dynamic>>[];
"""
    text = replace_once(text, old, new, 'random discovery fallback')
    path.write_text(text)


def patch_ai_policy() -> None:
    path = ROOT / 'lib/core/music/music_validator.dart'
    text = path.read_text()
    old = """    // HARD POLICY: unofficial AI uploads are not recommendation content.
    // Explicitly official/verified catalog items are allowed to continue.
    if (!isOfficial &&
        _vShotsLooksLikeUnofficialAi(title, artist, channelTitle)) {
"""
    new = """    // HARD POLICY: AI-generated songs/AI-music channels are not shown in
    // V Shots recommendations, even when a provider incorrectly labels the
    // upload as official. This is intentionally phrase-based, not a generic
    // 'ai' token, to avoid rejecting legitimate artist names.
    if (_vShotsLooksLikeUnofficialAi(title, artist, channelTitle)) {
"""
    text = replace_once(text, old, new, 'AI policy gate')
    text = text.replace("const List<String> _vShotsUnofficialAiMarkers", "const List<String> _vShotsUnofficialAiMarkers")
    # Add common explicit channel labels while retaining conservative matching.
    old_list = """  'suno ai', 'suno.com', 'udio ai', 'udio.com', 'ai music generator',
  'ai music', 'artificial intelligence music',
"""
    new_list = """  'suno ai', 'suno.com', 'suno songs', 'udio ai', 'udio.com',
  'udio songs', 'ai music generator', 'ai music channel', 'ai songs',
  'ai song channel', 'ai-generated music', 'artificial intelligence music',
"""
    text = replace_once(text, old_list, new_list, 'AI marker list')
    path.write_text(text)


if __name__ == '__main__':
    patch_home_service()
    patch_home_screen()
    patch_main_shell()
    patch_discovery()
    patch_ai_policy()
    print('Home/Discovery product polish: personalized, non-random, deduped, reactive, and AI-filtered.')

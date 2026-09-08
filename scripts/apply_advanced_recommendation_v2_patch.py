from pathlib import Path

ROOT = Path('.')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f'Advanced recommendation patch: missing {label}')
    return text.replace(old, new, 1)


def patch_engine() -> None:
    path = ROOT / 'lib/core/recommendation/music_recommendation_engine.dart'
    text = path.read_text()

    text = replace_once(
        text,
        "import 'music_recommendation_context.dart';\n",
        "import 'advanced_recommendation_v2.dart';\nimport 'music_recommendation_context.dart';\nimport 'taste_profile.dart';\n",
        'engine imports',
    )
    text = replace_once(
        text,
        "  final MusicCandidateGenerator _generator;\n",
        "  final MusicCandidateGenerator _generator;\n  final MusicSearch _search;\n",
        'engine search field',
    )
    text = replace_once(
        text,
        "  })  : _generator = MusicCandidateGenerator(search: search, config: config),\n        config = config,\n",
        "  })  : _generator = MusicCandidateGenerator(search: search, config: config),\n        _search = search,\n        config = config,\n",
        'engine constructor',
    )
    text = replace_once(
        text,
        "    final profile = MusicUserProfileBuilder(config: config).build();\n    final candidates = await _generator.generate(\n",
        "    final profile = MusicUserProfileBuilder(config: config).build();\n    final candidates = await _generator.generate(\n",
        'engine profile anchor',
    )

    marker = "\n}\n\n/// The For You score."
    if marker not in text:
        raise RuntimeError('Advanced recommendation patch: engine class marker missing')

    method = r'''

  /// V2 shelf-aware entry point. Candidate generation stays on the existing
  /// pipeline; this layer changes only how candidates are ranked and mixed.
  Future<List<Map<String, dynamic>>> generateShelf({
    required RecommendationShelf shelf,
    required Set<String> excludeIds,
    int count = 12,
    List<String> languages = const [],
    List<String> moods = const [],
    List<String> regions = const [],
  }) async {
    if (!_seenReady) {
      await _seenStore.initialize();
      _seenReady = true;
    }
    _session.requestToken++;

    final deviceRegion = MusicRegionProfile.current();
    final effectiveRegions = regions.isNotEmpty
        ? regions
        : <String>[deviceRegion.countryName];
    final effectiveLanguages = languages.isNotEmpty
        ? languages
        : (deviceRegion.countryCode == 'IN' ? <String>['Hindi'] : const <String>[]);
    final mode = switch (shelf) {
      RecommendationShelf.madeForYou => 'made_for_you',
      RecommendationShelf.becauseYouListenedTo => 'because_you_listened_to',
      RecommendationShelf.quickPicks => 'quick_picks',
      RecommendationShelf.trendingForYou => 'trending_for_you',
      RecommendationShelf.freshDiscovery => 'fresh_discovery',
      RecommendationShelf.discovery => 'discovery',
    };
    final context = MusicRecommendationContext(
      mode: mode,
      languages: effectiveLanguages,
      moods: moods,
      regions: effectiveRegions,
      count: count,
      excludeIds: excludeIds,
      seenStore: _seenStore,
      session: _session,
    );
    final taste = TasteProfileBuilder().build();
    final profile = MusicUserProfileBuilder(config: config).build();

    // COLD is intentionally not personalized. Use the existing safe
    // candidate pools and deterministic ranking, then let the profile take
    // over as real signals arrive.
    final candidates = await _generator.generate(profile: profile, context: context);
    if (candidates.isEmpty) {
      final fallbackQuery = switch (shelf) {
        RecommendationShelf.discovery || RecommendationShelf.freshDiscovery =>
          effectiveLanguages.isEmpty ? 'popular new songs official audio 2026' : '${effectiveLanguages.first} new songs official audio 2026',
        _ => effectiveLanguages.isEmpty ? 'popular songs official audio 2026' : '${effectiveLanguages.first} popular songs official audio 2026',
      };
      final raw = await _search(
        fallbackQuery,
        limit: (count * 2).clamp(1, 20),
        excludeIds: excludeIds,
      );
      return raw
          .where((m) => m['isOfficial'] == true)
          .map((m) => Map<String, dynamic>.from(m))
          .take(count)
          .toList();
    }

    final scored = <ScoredMusicCandidate>[];
    final artistCounts = <String, int>{};
    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final value = AdvancedRecommendationV2.score(
        candidate: candidate,
        profile: taste,
        shelf: shelf,
        context: context,
        artistCounts: artistCounts,
        candidateIndex: i,
      );
      scored.add(ScoredMusicCandidate(candidate: candidate, score: value));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    // Greedy diversity pass: an artist can lead once, then must pay fatigue.
    final result = <Map<String, dynamic>>[];
    final emittedSongs = <String>{};
    final emittedArtists = <String, int>{};
    for (final item in scored) {
      final c = item.candidate;
      if (emittedSongs.contains(c.songId)) continue;
      final artist = c.artist.trim();
      final countForArtist = emittedArtists[artist] ?? 0;
      if (countForArtist >= 2 && result.length < count - 2) continue;
      if (!_session.emitSong(c.songId, c.track.id)) continue;
      final map = c.track.toTrackMap();
      map['recommendationReason'] = AdvancedRecommendationV2.reason(
        candidate: c,
        profile: taste,
        shelf: shelf,
      );
      if (c.seedArtist != null && c.seedArtist!.isNotEmpty) {
        map['discoverSeedArtist'] = c.seedArtist;
      }
      result.add(map);
      emittedSongs.add(c.songId);
      emittedArtists[artist] = countForArtist + 1;
      unawaited(_seenStore.record(c.songId));
      if (result.length >= count) break;
    }

    // If diversity was too strict for a small candidate pool, fill from the
    // already-ranked list rather than returning an empty/short shelf.
    if (result.length < count) {
      for (final item in scored) {
        if (result.length >= count) break;
        final c = item.candidate;
        if (emittedSongs.contains(c.songId)) continue;
        final map = c.track.toTrackMap();
        map['recommendationReason'] = AdvancedRecommendationV2.reason(
          candidate: c,
          profile: taste,
          shelf: shelf,
        );
        result.add(map);
        emittedSongs.add(c.songId);
      }
    }
    return result;
  }
'''
    text = text.replace(marker, method + marker, 1)
    path.write_text(text)


def patch_generator() -> None:
    path = ROOT / 'lib/core/music/music_candidate_generator.dart'
    text = path.read_text()
    if '..shuffle();' in text:
        text = text.replace('..shuffle();', '..sort();')
    path.write_text(text)


def patch_home() -> None:
    path = ROOT / 'lib/features/home/home_feed_service.dart'
    text = path.read_text()
    text = replace_once(
        text,
        "import '../../core/recommendation/music_recommendation_engine.dart';\n",
        "import '../../core/recommendation/advanced_recommendation_v2.dart';\nimport '../../core/recommendation/music_recommendation_engine.dart';\n",
        'home advanced import',
    )
    text = replace_once(
        text,
        "    final existing = base.map((s) => s.id).toSet();\n",
        "    final existing = base.map((s) => s.id).toSet();\n",
        'home shelf anchor',
    )
    # Remove the old odd/even shelf rotation. Recommendations themselves are
    # deterministic; Home ordering must not appear random on refresh.
    text = text.replace(
        "    if (dynamic.isNotEmpty && _homeRotationNonce.isOdd) {\n      final first = dynamic.removeAt(0);\n      dynamic.add(first);\n    }\n",
        "",
    )

    # Cold-start gate for shelves whose names imply personalization. Broad
    # catalog/fresh discovery remains available and the V2 engine takes over
    # progressively after real signals arrive.
    old = """    // Skip shelves that need history the user doesn't have yet.\n    if (shelf.onlyWhenPersonalized && !hasPersonalization) {\n"""
    new = """    // Skip shelves that need history the user doesn't have yet.\n    final profileSignals = TasteProfileBuilder().build().totalSignalCount;\n    final coldStartPersonalizedShelf =\n        !hasPersonalization &&\n        (shelf.kind == HomeShelfKind.madeForYou ||\n            shelf.kind == HomeShelfKind.quickPicks ||\n            shelf.kind == HomeShelfKind.trendingForYou);\n    if (shelf.onlyWhenPersonalized || coldStartPersonalizedShelf) {\n      if (profileSignals < 3 || shelf.onlyWhenPersonalized) {\n"""
    if old not in text:
        raise RuntimeError('Advanced recommendation patch: home cold-start gate missing')
    text = text.replace(old, new, 1)

    old_switch = """        // \"Made For You\" goes through MUSIC INTELLIGENCE V3 (taste → candidate\n        // → rank → diversity → exploration) with the existing engine as\n        // fallback.\n        if (shelf.kind == HomeShelfKind.madeForYou && _musicEngine != null) {\n          try {\n            final music = await _musicEngine.generateForYou(\n              excludeIds: excludeIds,\n              count: shelf.limit,\n            );\n            if (music.isNotEmpty) return music;\n          } catch (e) {\n            debugPrint('[HomeFeedService] music engine failed: $e');\n          }\n        }\n"""
    new_switch = """        // All recommendation shelves now use the same V2 behavior-driven\n        // ranking layer. The legacy RecommendationEngine remains the safe\n        // fallback if V2 cannot produce candidates.\n        if (_musicEngine != null) {\n          try {\n            final advancedShelf = switch (shelf.kind) {\n              HomeShelfKind.madeForYou => RecommendationShelf.madeForYou,\n              HomeShelfKind.becauseYouListenedTo => RecommendationShelf.becauseYouListenedTo,\n              HomeShelfKind.quickPicks => RecommendationShelf.quickPicks,\n              HomeShelfKind.trendingForYou => RecommendationShelf.trendingForYou,\n              HomeShelfKind.discoverSomethingNew => RecommendationShelf.freshDiscovery,\n              _ => RecommendationShelf.madeForYou,\n            };\n            final music = await _musicEngine.generateShelf(\n              shelf: advancedShelf,\n              excludeIds: excludeIds,\n              count: shelf.limit,\n            );\n            if (music.isNotEmpty) {\n              if (shelf.kind == HomeShelfKind.becauseYouListenedTo) {\n                final seed = music.first['discoverSeedArtist'] as String?;\n                if (seed != null && seed.isNotEmpty) {\n                  shelf.subtitle = 'Because you listened to $seed';\n                }\n              }\n              return music;\n            }\n          } catch (e) {\n            debugPrint('[HomeFeedService] advanced music engine failed: $e');\n          }\n        }\n"""
    if old_switch not in text:
        raise RuntimeError('Advanced recommendation patch: old Home V3 block missing')
    text = text.replace(old_switch, new_switch, 1)
    path.write_text(text)


if __name__ == '__main__':
    patch_engine()
    patch_generator()
    patch_home()
    print('Advanced Recommendation V2: audit-preserving ranking layer wired.')

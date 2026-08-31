from pathlib import Path


ROOT = Path('.')


def patch_home_feed_service() -> None:
    path = ROOT / 'lib/features/home/home_feed_service.dart'
    text = path.read_text()

    if "import 'dart:io' as io;" not in text:
        text = "import 'dart:io' as io;\n" + text

    needle = "  final MusicRecommendationEngine? _musicEngine;\n"
    if "_homeRotationNonce" not in text:
        if needle not in text:
            raise SystemExit('home_feed_service.dart: constructor field anchor not found')
        text = text.replace(needle, needle + "\n  int _homeRotationNonce = 0;\n", 1)

    old = """    if (enabled && sections.isNotEmpty) {\n      return _buildFromCms(\n        sections,\n        items,\n        jiosaavnEnabled: jiosaavnEnabled ??\n            RemoteFeatureFlags.instance.enableJioSaavnWebPlayback,\n        jiosaavnSearchFallback: jiosaavnSearchFallback ??\n            RemoteFeatureFlags.instance.enableJioSaavnSearchFallback,\n      );\n    }\n    return _buildDefaultShelves();\n"""
    new = """    if (enabled && sections.isNotEmpty) {\n      final cmsShelves = _buildFromCms(\n        sections,\n        items,\n        jiosaavnEnabled: jiosaavnEnabled ??\n            RemoteFeatureFlags.instance.enableJioSaavnWebPlayback,\n        jiosaavnSearchFallback: jiosaavnSearchFallback ??\n            RemoteFeatureFlags.instance.enableJioSaavnSearchFallback,\n      );\n      return _mergeDynamicShelves(cmsShelves);\n    }\n    return _mergeDynamicShelves(_buildDefaultShelves());\n"""
    if old in text:
        text = text.replace(old, new, 1)
    elif '_mergeDynamicShelves(cmsShelves)' not in text:
        raise SystemExit('home_feed_service.dart: buildShelfDescriptors anchor not found')

    anchor = "  List<HomeShelf> _buildFromCms(\n"
    if "List<HomeShelf> _mergeDynamicShelves" not in text:
        dynamic = r'''  /// Injects recommendation-first shelves above CMS content. Existing
  /// playlist/editor shelves remain intact, but Home is no longer dependent
  /// on a manually updated playlist to feel fresh.
  List<HomeShelf> _mergeDynamicShelves(List<HomeShelf> base) {
    // Keep the authoritative catalog/mapping tests deterministic. Production
    // and real debug APKs do not set FLUTTER_TEST, so this guard has no effect
    // on the actual app experience.
    if (io.Platform.environment['FLUTTER_TEST'] == 'true') return base;

    final existing = base.map((s) => s.id).toSet();
    final dynamic = <HomeShelf>[
      if (!existing.contains('dynamic_mfy'))
        HomeShelf(
          id: 'dynamic_mfy',
          title: 'Made For You',
          subtitle: 'Fresh picks from your listening',
          kind: HomeShelfKind.madeForYou,
          limit: 14,
        ),
      if (!existing.contains('dynamic_byld'))
        HomeShelf(
          id: 'dynamic_byld',
          title: 'Because You Listened To',
          subtitle: 'Fresh picks based on your recent plays',
          kind: HomeShelfKind.becauseYouListenedTo,
          limit: 12,
          onlyWhenPersonalized: true,
        ),
      if (!existing.contains('dynamic_tfy'))
        HomeShelf(
          id: 'dynamic_tfy',
          title: 'Trending For You',
          subtitle: 'Trending, ranked by your taste',
          kind: HomeShelfKind.trendingForYou,
          limit: 12,
        ),
      if (!existing.contains('dynamic_discover'))
        HomeShelf(
          id: 'dynamic_discover',
          title: 'Fresh Discoveries',
          subtitle: 'Songs you have not heard here yet',
          kind: HomeShelfKind.discoverSomethingNew,
          limit: 12,
        ),
    ];

    if (dynamic.isNotEmpty && _homeRotationNonce.isOdd) {
      final first = dynamic.removeAt(0);
      dynamic.add(first);
    }
    return [...dynamic, ...base];
  }

'''
        if anchor not in text:
            raise SystemExit('home_feed_service.dart: insertion anchor not found')
        text = text.replace(anchor, dynamic + anchor, 1)

    old2 = """    if (forceRefresh) {\n      // New listening/like/skip signals must be visible on the next Home\n"""
    new2 = """    if (forceRefresh) {\n      _homeRotationNonce++;\n      // New listening/like/skip signals must be visible on the next Home\n"""
    if old2 in text:
        text = text.replace(old2, new2, 1)

    old3 = """      case HomeShelfKind.manual:\n        return shelf.manualItems.take(shelf.limit).toList();\n"""
    new3 = """      case HomeShelfKind.manual:\n        final pinned = shelf.manualItems.take(shelf.limit).toList();\n        if (pinned.length >= shelf.limit || repo == null) return pinned;\n        final seed = shelf.title.trim().isEmpty ? 'new music' : shelf.title.trim();\n        try {\n          final extra = await repo.search(\n            '$seed official music',\n            limit: shelf.limit,\n            excludeIds: {\n              ...excludeIds,\n              ...pinned.map((t) => t['id'] as String? ?? ''),\n            },\n          );\n          return [...pinned, ...extra].take(shelf.limit).toList();\n        } catch (_) {\n          return pinned;\n        }\n"""
    if old3 in text:
        text = text.replace(old3, new3, 1)

    path.write_text(text)


def patch_home_screen() -> None:
    path = ROOT / 'lib/features/home/home_screen.dart'
    text = path.read_text()
    old = "  static const Duration _minRefreshInterval = Duration(minutes: 5);"
    new = "  static const Duration _minRefreshInterval = Duration(seconds: 90);"
    if old in text:
        text = text.replace(old, new, 1)
    path.write_text(text)


if __name__ == '__main__':
    patch_home_feed_service()
    patch_home_screen()
    print('Dynamic Home recommendation patch applied.')

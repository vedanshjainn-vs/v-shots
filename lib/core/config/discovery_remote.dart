// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Remote Discover category mapping (pure)
// ═════════════════════════════════════════════════════════════════════════════
//
// Maps Supabase `discovery_categories` rows onto the existing Discover
// filter model. Does not replace the Discover UI. Bad/empty remote data
// falls back to the compiled lists in discovery_filters.dart.

import '../remote_config/home_cms_models.dart';
import 'discovery_filters.dart';

class DiscoveryFilterCatalog {
  const DiscoveryFilterCatalog({
    required this.sources,
    required this.moods,
    required this.languages,
    required this.regions,
  });

  final List<DiscoverySource> sources;
  final List<DiscoveryMood> moods;
  final List<DiscoveryFilterOption> languages;
  final List<DiscoveryFilterOption> regions;

  static const compiled = DiscoveryFilterCatalog(
    sources: kDiscoverySources,
    moods: kDiscoveryMoods,
    languages: kDiscoveryLanguages,
    regions: kDiscoveryRegions,
  );

  bool get isUsable => sources.isNotEmpty;

  /// When [useRemote] is false, or [rows] is empty/unusable, compiled lists.
  static DiscoveryFilterCatalog resolve({
    required bool useRemote,
    required List<Map<String, dynamic>> rows,
  }) {
    if (!useRemote || rows.isEmpty) return compiled;
    final parsed = fromRows(rows);
    if (!parsed.isUsable) return compiled;
    return parsed;
  }

  static DiscoveryFilterCatalog fromRows(List<Map<String, dynamic>> rows) {
    final sources = <DiscoverySource>[];
    final moods = <DiscoveryMood>[];
    final languages = <DiscoveryFilterOption>[];
    final regions = <DiscoveryFilterOption>[];

    final sorted = [...rows]..sort((a, b) {
        return cmsAsInt(
          a['sort_order'],
          0,
        ).compareTo(cmsAsInt(b['sort_order'], 0));
      });

    for (final raw in sorted) {
      if (!_rowVisible(raw)) continue;
      final kind = cmsAsString(raw['kind'], 'source').toLowerCase();
      final id = cmsAsString(raw['id'], cmsAsString(raw['name']));
      final label = cmsAsString(
        raw['name'],
        cmsAsString(raw['label'], 'Untitled'),
      );
      if (id.isEmpty || label.isEmpty) continue;
      final icon = cmsAsString(raw['emoji'], cmsAsString(raw['icon'], '🎵'));
      final query = cmsAsString(raw['query']);
      final token = cmsAsString(raw['token'], query);
      final order = cmsAsString(raw['ranking_order'], 'relevance');

      switch (kind) {
        case 'mood':
          if (query.isEmpty) continue;
          moods.add(
            DiscoveryMood(id: id, label: label, icon: icon, query: query),
          );
          break;
        case 'language':
          languages.add(
            DiscoveryFilterOption(
              id: id,
              label: label,
              token: token.isEmpty ? label.toLowerCase() : token,
            ),
          );
          break;
        case 'region':
          regions.add(
            DiscoveryFilterOption(
              id: id,
              label: label,
              token: token.isEmpty ? label.toLowerCase() : token,
            ),
          );
          break;
        default:
          final isForYou = id == 'for_you' || query.isEmpty && kind == 'source';
          sources.add(
            DiscoverySource(
              id: id,
              label: label,
              icon: icon,
              query: isForYou ? null : (query.isEmpty ? null : query),
              order: order.isEmpty ? 'relevance' : order,
            ),
          );
      }
    }

    final ensuredSources = _ensureForYou(
      sources.isEmpty ? kDiscoverySources : sources,
    );
    return DiscoveryFilterCatalog(
      sources: ensuredSources,
      moods: moods.isEmpty ? kDiscoveryMoods : moods,
      languages: languages.isEmpty ? kDiscoveryLanguages : languages,
      regions: regions.isEmpty ? kDiscoveryRegions : regions,
    );
  }

  static bool _rowVisible(Map<String, dynamic> raw) {
    if (!cmsAsBool(raw['active'], fallback: true)) return false;
    if (!cmsAsBool(raw['visible'], fallback: true)) return false;
    return true;
  }

  static List<DiscoverySource> _ensureForYou(List<DiscoverySource> sources) {
    final hasForYou = sources.any((s) => s.id == 'for_you' || s.query == null);
    if (hasForYou) return sources;
    return [kDiscoverySources.first, ...sources];
  }
}

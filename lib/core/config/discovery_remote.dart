// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Remote Discover category mapping (pure)
// Maps Supabase `discovery_categories` rows (kind = source/mood/language/
// genre/decade/activity) onto the V SHOTS DISCOVER filter model.
// Bad/empty remote data falls back to the compiled lists.
// ═════════════════════════════════════════════════════════════════════════════

import '../remote_config/home_cms_models.dart';
import 'discovery_filters.dart';

class DiscoveryFilterCatalog {
  const DiscoveryFilterCatalog({
    required this.sources,
    required this.moods,
    required this.languages,
    required this.genres,
    required this.decades,
    required this.activities,
  });

  final List<DiscoverySource> sources;
  final List<DiscoveryMood> moods;
  final List<DiscoveryFilterOption> languages;
  final List<DiscoveryFilterOption> genres;
  final List<DiscoveryFilterOption> decades;
  final List<DiscoveryFilterOption> activities;

  static const compiled = DiscoveryFilterCatalog(
    sources: kDiscoverySources,
    moods: kDiscoveryMoods,
    languages: kDiscoveryLanguages,
    genres: kDiscoveryGenres,
    decades: kDiscoveryDecades,
    activities: kDiscoveryActivities,
  );

  bool get isUsable => sources.isNotEmpty;

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
    final genres = <DiscoveryFilterOption>[];
    final decades = <DiscoveryFilterOption>[];
    final activities = <DiscoveryFilterOption>[];

    final sorted = [...rows]
      ..sort((a, b) {
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
          languages.add(_opt(id, label, token));
          break;
        case 'genre':
          genres.add(_opt(id, label, token));
          break;
        case 'decade':
          decades.add(_opt(id, label, token));
          break;
        case 'activity':
          activities.add(_opt(id, label, token));
          break;
        default:
          final isEngineSource = id == 'for_you' || id == 'surprise_me';
          sources.add(
            DiscoverySource(
              id: id,
              label: label,
              icon: icon,
              query: isEngineSource ? null : (query.isEmpty ? null : query),
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
      genres: genres.isEmpty ? kDiscoveryGenres : genres,
      decades: decades.isEmpty ? kDiscoveryDecades : decades,
      activities: activities.isEmpty ? kDiscoveryActivities : activities,
    );
  }

  static DiscoveryFilterOption _opt(String id, String label, String token) =>
      DiscoveryFilterOption(
        id: id,
        label: label,
        token: token.isEmpty ? label.toLowerCase() : token,
      );

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

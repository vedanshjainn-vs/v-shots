// ════════════════════════════════════════════════
// Project Lyra — Search Aggregator
// ════════════════════════════════════════════════
//
// Aggregates search results from multiple providers:
// - Single provider mode (default)
// - Multi-provider mode (merge, deduplicate, sort)
// ════════════════════════════════════════════════

import '../../logging/app_logger.dart';
import '../imusic_provider.dart';
import '../models/provider_models.dart';
import '../registry/provider_registry.dart';

/// Aggregates search results from one or more providers.
///
/// Supports:
/// - Single provider (fast, default)
/// - Multi-provider (merge results, remove duplicates)
class SearchAggregator {
  SearchAggregator({
    required this.registry,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final ProviderRegistry registry;
  final AppLogger _logger;

  /// Search using a single provider (default behavior).
  Future<ProviderSearchResult> searchSingle(
    String query, {
    SearchFilter? filter,
    int page = 1,
    int limit = 20,
  }) async {
    final provider = registry.activeProvider;
    if (provider == null) {
      throw Exception('No active provider');
    }

    return provider.search(query, filter: filter, page: page, limit: limit);
  }

  /// Search across multiple providers and merge results.
  ///
  /// Useful for getting comprehensive results across catalogs.
  Future<ProviderSearchResult> searchMulti(
    String query, {
    SearchFilter? filter,
    int limit = 20,
  }) async {
    final results = <ProviderSearchResult>[];
    final futures = <Future<ProviderSearchResult>>[];

    // Search all healthy providers.
    for (final id in registry.enabledIds) {
      final provider = registry.getProvider(id);
      if (provider != null && registry.isHealthy(id)) {
        futures.add(
          provider.search(query, filter: filter, limit: limit)
              .catchError((e) {
            _logger.w('SearchAggregator: Search failed on $id');
            return const ProviderSearchResult();
          }),
        );
      }
    }

    final responses = await Future.wait(futures);
    results.addAll(responses.where((r) => r.tracks.isNotEmpty));

    // Merge and deduplicate.
    return _mergeResults(results, query);
  }

  /// Merge results from multiple providers.
  ProviderSearchResult _mergeResults(
    List<ProviderSearchResult> results,
    String query,
  ) {
    final allTracks = <ProviderTrack>[];
    final allAlbums = <ProviderAlbum>[];
    final allArtists = <ProviderArtist>[];
    final allPlaylists = <ProviderPlaylist>[];

    for (final result in results) {
      allTracks.addAll(result.tracks);
      allAlbums.addAll(result.albums);
      allArtists.addAll(result.artists);
      allPlaylists.addAll(result.playlists);
    }

    // Deduplicate by ID.
    final uniqueTracks = _deduplicateTracks(allTracks);
    final uniqueAlbums = _deduplicateAlbums(allAlbums);
    final uniqueArtists = _deduplicateArtists(allArtists);
    final uniquePlaylists = _deduplicatePlaylists(allPlaylists);

    // Sort by relevance (popularity, name match).
    uniqueTracks.sort((a, b) => _calculateRelevance(b, query).compareTo(_calculateRelevance(a, query)));

    return ProviderSearchResult(
      tracks: uniqueTracks.take(50).toList(),
      albums: uniqueAlbums.take(20).toList(),
      artists: uniqueArtists.take(20).toList(),
      playlists: uniquePlaylists.take(20).toList(),
      totalResults: uniqueTracks.length + uniqueAlbums.length + uniqueArtists.length + uniquePlaylists.length,
      query: query,
    );
  }

  List<ProviderTrack> _deduplicateTracks(List<ProviderTrack> tracks) {
    final seen = <String>{};
    return tracks.where((t) => seen.add('${t.title}|${t.artist}')).toList();
  }

  List<ProviderAlbum> _deduplicateAlbums(List<ProviderAlbum> albums) {
    final seen = <String>{};
    return albums.where((a) => seen.add('${a.title}|${a.artist}')).toList();
  }

  List<ProviderArtist> _deduplicateArtists(List<ProviderArtist> artists) {
    final seen = <String>{};
    return artists.where((a) => seen.add(a.name)).toList();
  }

  List<ProviderPlaylist> _deduplicatePlaylists(List<ProviderPlaylist> playlists) {
    final seen = <String>{};
    return playlists.where((p) => seen.add(p.title)).toList();
  }

  double _calculateRelevance(ProviderTrack track, String query) {
    double score = 0;
    final lowerQuery = query.toLowerCase();

    if (track.title.toLowerCase().contains(lowerQuery)) score += 10;
    if (track.artist.toLowerCase().contains(lowerQuery)) score += 5;
    if (track.popularity != null) score += track.popularity! / 100;

    return score;
  }
}

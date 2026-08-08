// ════════════════════════════════════════════════
// Project Lyra — Development Provider
// ════════════════════════════════════════════════
//
// Development/testing provider adapter.
// Returns mock data for testing the app without
// a real music catalog backend.
//
// Enabled via feature flag: 'use_development_provider'
// ════════════════════════════════════════════════

import 'dart:math';

import '../../imusic_provider.dart';
import '../../models/provider_models.dart';

/// Development provider for testing.
///
/// Returns realistic mock data for all operations.
/// Use only in development and internal testing.
class DevelopmentProvider implements IMusicProvider {
  DevelopmentProvider();

  final _random = Random();

  @override
  String get id => 'development';

  @override
  String get name => 'Development Provider';

  @override
  String get version => '1.0.0';

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        supportsSearch: true,
        supportsStreaming: true,
        supportsLyrics: true,
        supportsRecommendations: true,
        supportsTrending: true,
        supportsOffline: false,
        supportsHighQuality: true,
        supportsPodcasts: true,
        supportsAudiobooks: true,
        maxBitrate: 320,
        maxSearchResults: 50,
      );

  @override
  Future<void> initialize(ProviderInitConfig config) async {
    // No initialization needed for development.
  }

  @override
  Future<HealthStatus> healthCheck() async {
    return HealthStatus(
      isHealthy: true,
      latencyMs: 10,
      message: 'Development provider is always healthy',
      lastChecked: DateTime.now(),
    );
  }

  @override
  Future<void> dispose() async {}

  // ── Search ───────────────────────────────────

  @override
  Future<ProviderSearchResult> search(
    String query, {
    SearchFilter? filter,
    int page = 1,
    int limit = 20,
  }) async {
    await _simulateLatency();

    final tracks = List.generate(
      limit,
      (i) => _generateTrack('${query}_track_${i}'),
    );

    final albums = List.generate(
      min(5, limit),
      (i) => _generateAlbum('${query}_album_${i}'),
    );

    final artists = List.generate(
      min(3, limit),
      (i) => _generateArtist('${query}_artist_${i}'),
    );

    return ProviderSearchResult(
      tracks: tracks,
      albums: albums,
      artists: artists,
      totalResults: tracks.length + albums.length + artists.length,
      query: query,
      providerId: id,
    );
  }

  @override
  Future<List<String>> getSuggestions(String query) async {
    await _simulateLatency();
    return [
      '$query songs',
      '$query albums',
      '$query artists',
      'best of $query',
      '$query radio',
    ];
  }

  // ── Tracks ───────────────────────────────────

  @override
  Future<ProviderTrack> getTrack(String id) async {
    await _simulateLatency();
    return _generateTrack(id);
  }

  @override
  Future<List<ProviderTrack>> getTracks(List<String> ids) async {
    await _simulateLatency();
    return ids.map((id) => _generateTrack(id)).toList();
  }

  @override
  Future<ProviderStreamInfo> getStream(String id, {StreamQuality? quality}) async {
    await _simulateLatency();
    return ProviderStreamInfo(
      url: 'https://stream.dev.projectlyra.com/tracks/$id',
      quality: quality ?? StreamQuality.high,
      bitrateKbps: (quality ?? StreamQuality.high).bitrate,
      format: 'mp3',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<ProviderLyrics?> getLyrics(String id) async {
    await _simulateLatency();
    return ProviderLyrics(
      trackId: id,
      isSynced: true,
      source: 'development',
      lines: [
        const ProviderLyricsLine(text: '♪ Music fills the air ♪', timestamp: Duration(seconds: 0)),
        const ProviderLyricsLine(text: 'Dancing without a care', timestamp: Duration(seconds: 5)),
        const ProviderLyricsLine(text: 'The rhythm takes control', timestamp: Duration(seconds: 10)),
        const ProviderLyricsLine(text: 'Music fills my soul', timestamp: Duration(seconds: 15)),
        const ProviderLyricsLine(text: '♪ La la la la la ♪', timestamp: Duration(seconds: 20), isChorus: true),
      ],
    );
  }

  // ── Albums ───────────────────────────────────

  @override
  Future<ProviderAlbum> getAlbum(String id) async {
    await _simulateLatency();
    return _generateAlbum(id);
  }

  @override
  Future<List<ProviderTrack>> getAlbumTracks(String id, {int page = 1, int limit = 50}) async {
    await _simulateLatency();
    return List.generate(limit, (i) => _generateTrack('${id}_track_$i'));
  }

  // ── Artists ──────────────────────────────────

  @override
  Future<ProviderArtist> getArtist(String id) async {
    await _simulateLatency();
    return _generateArtist(id);
  }

  @override
  Future<List<ProviderTrack>> getArtistTopTracks(String id, {int limit = 10}) async {
    await _simulateLatency();
    return List.generate(limit, (i) => _generateTrack('${id}_top_$i'));
  }

  @override
  Future<List<ProviderAlbum>> getArtistAlbums(String id, {int page = 1, int limit = 20}) async {
    await _simulateLatency();
    return List.generate(limit, (i) => _generateAlbum('${id}_album_$i'));
  }

  @override
  Future<List<ProviderArtist>> getRelatedArtists(String id, {int limit = 10}) async {
    await _simulateLatency();
    return List.generate(limit, (i) => _generateArtist('${id}_related_$i'));
  }

  // ── Playlists ────────────────────────────────

  @override
  Future<ProviderPlaylist> getPlaylist(String id) async {
    await _simulateLatency();
    return ProviderPlaylist(
      id: id,
      title: 'Dev Playlist $id',
      description: 'A development test playlist',
      ownerName: 'Project Lyra Dev',
      trackCount: 25,
      followersCount: _random.nextInt(10000),
    );
  }

  @override
  Future<List<ProviderTrack>> getPlaylistTracks(String id, {int page = 1, int limit = 50}) async {
    await _simulateLatency();
    return List.generate(limit, (i) => _generateTrack('${id}_track_$i'));
  }

  // ── Recommendations ──────────────────────────

  @override
  Future<List<ProviderTrack>> getRecommendations({
    List<String>? seedTrackIds,
    List<String>? seedArtistIds,
    int limit = 20,
  }) async {
    await _simulateLatency();
    return List.generate(limit, (i) => _generateTrack('rec_$i'));
  }

  @override
  Future<List<ProviderTrack>> getTrending({String? genre, String? region, int limit = 20}) async {
    await _simulateLatency();
    return List.generate(limit, (i) => _generateTrack('trending_$i'));
  }

  @override
  Future<List<ProviderAlbum>> getNewReleases({String? region, int limit = 20}) async {
    await _simulateLatency();
    return List.generate(limit, (i) => _generateAlbum('new_$i'));
  }

  // ── Artwork ──────────────────────────────────

  @override
  Future<String?> getArtwork(String id, {ArtworkSize size = ArtworkSize.medium}) async {
    return 'https://picsum.photos/${size.pixelSize}?random=$id';
  }

  // ── Genres ───────────────────────────────────

  @override
  Future<List<String>> getGenres() async {
    return ['Pop', 'Rock', 'Hip-Hop', 'R&B', 'Electronic', 'Jazz', 'Classical', 'Country', 'Latin', 'K-Pop'];
  }

  // ── Mock Data Generators ─────────────────────

  ProviderTrack _generateTrack(String id) {
    final artists = ['Aria Nova', 'Luna Echo', 'Stellar Beat', 'Neon Pulse', 'Crystal Wave'];
    final albums = ['Midnight Dreams', 'Electric Sunrise', 'Ocean Waves', 'City Lights', 'Starfall'];

    return ProviderTrack(
      id: id,
      title: 'Track ${id.split('_').last}',
      artist: artists[_random.nextInt(artists.length)],
      artistId: 'artist_${_random.nextInt(100)}',
      album: albums[_random.nextInt(albums.length)],
      albumId: 'album_${_random.nextInt(100)}',
      artworkUrl: 'https://picsum.photos/300?random=$id',
      duration: Duration(seconds: 180 + _random.nextInt(120)),
      isExplicit: _random.nextInt(5) == 0,
      trackNumber: _random.nextInt(15) + 1,
      popularity: _random.nextInt(100),
    );
  }

  ProviderAlbum _generateAlbum(String id) {
    final artists = ['Aria Nova', 'Luna Echo', 'Stellar Beat', 'Neon Pulse', 'Crystal Wave'];

    return ProviderAlbum(
      id: id,
      title: 'Album ${id.split('_').last}',
      artist: artists[_random.nextInt(artists.length)],
      artistId: 'artist_${_random.nextInt(100)}',
      artworkUrl: 'https://picsum.photos/300?random=$id',
      releaseDate: '2024-${_random.nextInt(12) + 1}-${_random.nextInt(28) + 1}',
      totalTracks: _random.nextInt(15) + 5,
      genres: ['Pop', 'Electronic'],
    );
  }

  ProviderArtist _generateArtist(String id) {
    final names = ['Aria Nova', 'Luna Echo', 'Stellar Beat', 'Neon Pulse', 'Crystal Wave'];

    return ProviderArtist(
      id: id,
      name: names[_random.nextInt(names.length)],
      imageUrl: 'https://picsum.photos/300?random=$id',
      followersCount: _random.nextInt(1000000),
      genres: ['Pop', 'Electronic', 'Dance'],
      isVerified: _random.nextBool(),
    );
  }

  Future<void> _simulateLatency() async {
    await Future.delayed(Duration(milliseconds: 50 + _random.nextInt(200)));
  }
}

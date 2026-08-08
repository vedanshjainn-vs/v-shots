// ════════════════════════════════════════════════
// Project Lyra — Library Local Data Source
// ════════════════════════════════════════════════

import '../../../../../core/cache/cache_key.dart';
import '../../../../../core/cache/cache_manager.dart';
import '../../../../../core/cache/policies/cache_policy.dart';
import '../../../../../core/logging/app_logger.dart';
import '../../../../../core/storage/local_storage.dart';
import '../models/library_models.dart';

/// Local data source for library caching.
abstract class LibraryLocalDataSource {
  Future<LibraryModel?> getCachedLibrary();
  Future<void> cacheLibrary(LibraryModel library);
  Future<Set<String>> getLikedTrackIds();
  Future<void> setLikedTrackIds(Set<String> ids);
  Future<void> addLikedTrack(String trackId);
  Future<void> removeLikedTrack(String trackId);
  Future<Set<String>> getSavedAlbumIds();
  Future<void> setSavedAlbumIds(Set<String> ids);
  Future<Set<String>> getFollowedArtistIds();
  Future<void> setFollowedArtistIds(Set<String> ids);
  Future<void> clearCache();
}

/// Hive/SharedPreferences implementation.
class HiveLibraryLocalDataSource implements LibraryLocalDataSource {
  HiveLibraryLocalDataSource({
    required this.cacheManager,
    required this.localStorage,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final CacheManager cacheManager;
  final LocalStorage localStorage;
  final AppLogger _logger;

  static const String _namespace = 'library';
  static const String _likedKey = 'liked_track_ids';
  static const String _savedAlbumKey = 'saved_album_ids';
  static const String _followedArtistKey = 'followed_artist_ids';

  @override
  Future<LibraryModel?> getCachedLibrary() async {
    try {
      final key = CacheKey(namespace: _namespace, id: 'library');
      final raw = cacheManager.getRaw(key);
      if (raw == null) return null;
      // TODO(team): Deserialize from raw JSON.
      return null;
    } catch (e) {
      _logger.w('LibraryLocal: getCachedLibrary failed');
      return null;
    }
  }

  @override
  Future<void> cacheLibrary(LibraryModel library) async {
    try {
      final key = CacheKey(namespace: _namespace, id: 'library');
      await cacheManager.put<LibraryModel>(
        key: key,
        data: library,
        toJson: (data) => data.toJson(),
        ttl: CachePolicy.userSpecific.maxAge,
      );
    } catch (e) {
      _logger.w('LibraryLocal: cacheLibrary failed');
    }
  }

  @override
  Future<Set<String>> getLikedTrackIds() async {
    try {
      final ids = await localStorage.getStringList(_likedKey);
      return ids?.toSet() ?? {};
    } catch (e) {
      return {};
    }
  }

  @override
  Future<void> setLikedTrackIds(Set<String> ids) async {
    await localStorage.setStringList(_likedKey, ids.toList());
  }

  @override
  Future<void> addLikedTrack(String trackId) async {
    final ids = await getLikedTrackIds();
    ids.add(trackId);
    await setLikedTrackIds(ids);
  }

  @override
  Future<void> removeLikedTrack(String trackId) async {
    final ids = await getLikedTrackIds();
    ids.remove(trackId);
    await setLikedTrackIds(ids);
  }

  @override
  Future<Set<String>> getSavedAlbumIds() async {
    try {
      final ids = await localStorage.getStringList(_savedAlbumKey);
      return ids?.toSet() ?? {};
    } catch (e) {
      return {};
    }
  }

  @override
  Future<void> setSavedAlbumIds(Set<String> ids) async {
    await localStorage.setStringList(_savedAlbumKey, ids.toList());
  }

  @override
  Future<Set<String>> getFollowedArtistIds() async {
    try {
      final ids = await localStorage.getStringList(_followedArtistKey);
      return ids?.toSet() ?? {};
    } catch (e) {
      return {};
    }
  }

  @override
  Future<void> setFollowedArtistIds(Set<String> ids) async {
    await localStorage.setStringList(_followedArtistKey, ids.toList());
  }

  @override
  Future<void> clearCache() async {
    await cacheManager.invalidateNamespace(_namespace);
  }
}

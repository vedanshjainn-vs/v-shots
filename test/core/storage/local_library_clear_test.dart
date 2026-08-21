import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/storage/local_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clearAllUserData wipes likes, recents, playlists, searches', () async {
    SharedPreferences.setMockInitialValues({});
    final lib = LocalLibrary.instance;
    await lib.initialize();
    await lib.clearAllUserData();
    await lib.toggleLiked({'id': 'abc', 'title': 'Song', 'artist': 'Artist'});
    await lib.recordRecentlyPlayed({
      'id': 'abc',
      'title': 'Song',
      'artist': 'Artist',
    });
    await lib.createPlaylist('Mine');
    await lib.recordRecentSearch('arijit');
    expect(lib.likedSongs.value, isNotEmpty);
    expect(lib.recentlyPlayed.value, isNotEmpty);
    expect(lib.playlists.value, isNotEmpty);
    expect(lib.recentSearches.value, isNotEmpty);

    await lib.clearAllUserData();

    expect(lib.likedSongs.value, isEmpty);
    expect(lib.recentlyPlayed.value, isEmpty);
    expect(lib.playlists.value, isEmpty);
    expect(lib.recentSearches.value, isEmpty);
    expect(lib.artistPlayCounts, isEmpty);
  });
}

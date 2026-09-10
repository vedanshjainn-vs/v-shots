import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/storage/personalization_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PersonalizationStore.instance.reset();
    await PersonalizationStore.instance.initialize();
  });

  tearDown(() async {
    await PersonalizationStore.instance.reset();
  });

  group('PersonalizationStore — preference persistence', () {
    test('completeOnboarding persists languages, genres, artists, songs',
        () async {
      final store = PersonalizationStore.instance;
      await store.completeOnboarding(
        languages: ['Punjabi', 'Hindi'],
        genres: ['Romantic'],
        artists: ['Diljit Dosanjh'],
        songs: const [
          FavoriteSong(id: 'abc12345678', title: 'Lover', artist: 'Diljit'),
        ],
      );

      expect(store.onboarded, isTrue);
      expect(store.preferredLanguages, ['Punjabi', 'Hindi']);
      expect(store.preferredGenres, ['Romantic']);
      expect(store.favoriteArtists, ['Diljit Dosanjh']);
      expect(store.favoriteSongs, hasLength(1));
      expect(store.favoriteSongs.first.title, 'Lover');
      expect(store.updatedAt, isNotNull);
    });

    test('preferences survive store re-initialization (app restart)', () async {
      await PersonalizationStore.instance.completeOnboarding(
        languages: ['English'],
        genres: ['Pop'],
        artists: ['Ed Sheeran'],
      );
      // Simulate restart: a fresh initialize() re-reads from disk.
      await PersonalizationStore.instance.initialize();
      final store = PersonalizationStore.instance;
      expect(store.preferredLanguages, ['English']);
      expect(store.preferredGenres, ['Pop']);
      expect(store.favoriteArtists, ['Ed Sheeran']);
      expect(store.onboarded, isTrue);
    });

    test('updatePreferences replaces only provided fields and bumps revision',
        () async {
      final store = PersonalizationStore.instance;
      await store.completeOnboarding(
        languages: ['Hindi'],
        genres: ['Bollywood'],
        artists: ['Arijit Singh'],
      );
      final revBefore = store.revision;

      await store.updatePreferences(genres: ['Romantic', 'Sad']);
      expect(store.preferredGenres, ['Romantic', 'Sad']);
      // Untouched fields survive.
      expect(store.preferredLanguages, ['Hindi']);
      expect(store.favoriteArtists, ['Arijit Singh']);
      expect(store.revision, greaterThan(revBefore));
    });

    test('listeners fire on every change (cache invalidation contract)',
        () async {
      final store = PersonalizationStore.instance;
      var notified = 0;
      store.addListener(() => notified++);
      await store.completeOnboarding(languages: ['Tamil']);
      await store.updatePreferences(genres: ['Devotional']);
      await store.reset();
      expect(notified, 3);
    });

    test('skip path: markOnboardedSkipped completes without choices', () async {
      final store = PersonalizationStore.instance;
      await store.markOnboardedSkipped();
      expect(store.onboarded, isTrue);
      expect(store.hasPreferences, isFalse);
    });

    test('FavoriteSong map round-trip rejects malformed entries', () {
      expect(FavoriteSong.fromMap({'id': 'x', 'title': ''}), isNull);
      expect(FavoriteSong.fromMap('nonsense'), isNull);
      expect(FavoriteSong.fromMap({'id': 'x', 'title': 'T'}), isNotNull);
      const a = FavoriteSong(id: 'x', title: 'T');
      const b = FavoriteSong(id: 'x', title: 'T');
      expect(a, b);
    });
  });

  group('PersonalizationStore — remote merge (cross-device sync)', () {
    test('adopts fresher remote bundle', () async {
      final store = PersonalizationStore.instance;
      await store.completeOnboarding(languages: ['Hindi']);
      final localUpdated = store.updatedAt!;

      final remoteNewer = DateTime.now().add(const Duration(minutes: 5));
      final adopted = store.adoptRemoteBundle({
        'onboarded': true,
        'languages': ['Punjabi', 'English'],
        'genres': ['Romantic'],
        'artists': ['Karan Aujla'],
        'songs': [
          {'id': 'vid11111111', 'title': 'Softly', 'artist': 'Karan Aujla'},
        ],
        'updated_at': remoteNewer.toIso8601String(),
      });

      expect(adopted, isTrue);
      expect(store.preferredLanguages, ['Punjabi', 'English']);
      expect(store.favoriteArtists, ['Karan Aujla']);
      expect(store.updatedAt!.isAfter(localUpdated), isTrue);
    });

    test('rejects older remote bundle (local wins)', () async {
      final store = PersonalizationStore.instance;
      await store.completeOnboarding(languages: ['Hindi']);

      final remoteOlder = DateTime.now().subtract(const Duration(hours: 2));
      final adopted = store.adoptRemoteBundle({
        'onboarded': true,
        'languages': ['Marathi'],
        'updated_at': remoteOlder.toIso8601String(),
      });

      expect(adopted, isFalse);
      expect(store.preferredLanguages, ['Hindi']);
    });

    test('toBundle round-trips through adoptRemoteBundle', () async {
      final store = PersonalizationStore.instance;
      await store.completeOnboarding(
        languages: ['Bengali'],
        genres: ['Indie'],
        artists: ['Anupam Roy'],
        songs: const [
          FavoriteSong(id: 'vid22222222', title: 'Amake Amar Moto')
        ],
      );
      final bundle = store.toBundle();

      await store.reset();
      final adopted = store.adoptRemoteBundle(bundle);
      expect(adopted, isTrue);
      expect(store.preferredLanguages, ['Bengali']);
      expect(store.favoriteArtists, ['Anupam Roy']);
      expect(store.favoriteSongs.first.id, 'vid22222222');
    });
  });
}

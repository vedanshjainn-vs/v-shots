import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/features/home/home_feed_service.dart';

void main() {
  staleKeyRegressionTests();
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home CMS mapping', () {
    test(
      'personalized CMS keys keep the recommendation engine, not catalog search',
      () {
        final service = HomeFeedService();
        final shelves = service.buildShelfDescriptors(
          enableRemoteHome: true,
          cmsSections: [
            {
              'id': 'made_for_you',
              'section_key': 'made_for_you',
              'title': 'Made For You',
              'section_type': 'personalized',
              'source_type': 'personalized',
              'source_value': 'made_for_you',
              'query': 'made for you personalized',
              'visible': true,
              'published': true,
              'max_items': 12,
              'sort_order': 1,
            },
            {
              'id': 'because_listened',
              'section_key': 'because_listened',
              'title': 'Because You Listened To',
              'section_type': 'personalized',
              'source_type': 'personalized',
              'source_value': 'because_listened',
              'query': 'because you listened to',
              'visible': true,
              'published': true,
              'max_items': 12,
              'sort_order': 2,
            },
            {
              'id': 'punjabi',
              'section_key': 'punjabi',
              'title': 'Punjabi Bangers',
              'section_type': 'home_section',
              'source_type': 'youtube_search',
              'source_value': 'latest punjabi pop hits official audio',
              'query': 'latest punjabi pop hits official audio',
              'visible': true,
              'published': true,
              'max_items': 15,
              'sort_order': 3,
            },
          ],
        );

        expect(shelves.first.kind, HomeShelfKind.continueListening);
        final mfy = shelves.firstWhere((s) => s.id == 'made_for_you');
        expect(mfy.kind, HomeShelfKind.madeForYou);
        expect(mfy.query, isNull);
        final byld = shelves.firstWhere((s) => s.id == 'because_listened');
        expect(byld.kind, HomeShelfKind.becauseYouListenedTo);
        final punjabi = shelves.firstWhere((s) => s.id == 'punjabi');
        expect(punjabi.kind, HomeShelfKind.catalog);
        expect(punjabi.query, 'latest punjabi pop hits official audio');
      },
    );

    test('hidden or unpublished CMS rows are skipped', () {
      final service = HomeFeedService();
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: [
          {
            'id': 'hidden',
            'section_key': 'hidden',
            'title': 'Hidden',
            'source_type': 'youtube_search',
            'query': 'x',
            'visible': false,
            'published': true,
          },
          {
            'id': 'draft',
            'section_key': 'draft',
            'title': 'Draft',
            'source_type': 'youtube_search',
            'query': 'y',
            'visible': true,
            'published': false,
          },
        ],
      );
      expect(
        shelves.every((s) => s.kind == HomeShelfKind.continueListening),
        isTrue,
      );
    });

    test('youtube_manual shelves use pinned CMS items', () {
      final service = HomeFeedService();
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: [
          {
            'id': 'editors',
            'section_key': 'editors',
            'title': "Editor's Picks",
            'source_type': 'youtube_manual',
            'visible': true,
            'published': true,
            'max_items': 5,
          },
        ],
        cmsItems: {
          'editors': [
            {
              'id': '1',
              'section_id': 'editors',
              'content_id': 'dQw4w9WgXcQ',
              'youtube_video_id': 'dQw4w9WgXcQ',
              'title': 'Never Gonna Give You Up',
              'artist': 'Rick Astley',
              'is_enabled': true,
            },
          ],
        },
      );
      final manual = shelves.firstWhere((s) => s.id == 'editors');
      expect(manual.kind, HomeShelfKind.manual);
      expect(manual.manualItems, isNotEmpty);
      expect(manual.manualItems.first['id'], 'dQw4w9WgXcQ');
    });

    test('enableRemoteHome false ignores CMS and uses compiled defaults', () {
      final service = HomeFeedService();
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: false,
        cmsSections: [
          {
            'id': 'only_cms',
            'title': 'Should not appear',
            'source_type': 'youtube_search',
            'query': 'nope',
            'visible': true,
            'published': true,
          },
        ],
      );
      expect(shelves.any((s) => s.id == 'only_cms'), isFalse);
      expect(shelves.any((s) => s.id == 'mfy'), isTrue);
    });

    test('empty CMS falls back to compiled defaults', () {
      final service = HomeFeedService();
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: const [],
      );
      expect(shelves.any((s) => s.id == 'mfy'), isTrue);
      expect(
        shelves.any((s) => s.kind == HomeShelfKind.continueListening),
        isTrue,
      );
    });

    test('malformed CMS rows are skipped without throwing', () {
      final service = HomeFeedService();
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: [
          {},
          {'id': '', 'title': 12, 'visible': 'maybe'},
        ],
      );
      expect(
        shelves.every((s) => s.kind == HomeShelfKind.continueListening),
        isTrue,
      );
    });

    test('JioSaavn CMS item maps onto a normalized track', () {
      final service = HomeFeedService();
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        jiosaavnEnabled: true,
        jiosaavnSearchFallback: false,
        cmsSections: [
          {
            'id': 'jiosaavn_test',
            'section_key': 'jiosaavn_test',
            'title': 'JioSaavn Test',
            'source_type': 'jiosaavn_manual',
            'visible': true,
            'published': true,
            'max_items': 5,
          },
        ],
        cmsItems: {
          'jiosaavn_test': [
            {
              'id': 'item-1',
              'section_id': 'jiosaavn_test',
              'content_id': 'kesariya',
              'title': 'Kesariya',
              'artist': 'Arijit Singh',
              'jiosaavn_url':
                  'https://www.jiosaavn.com/song/kesariya/RDPkZEVaUXw',
              'provider': 'jiosaavn',
              'playback_provider': 'jiosaavn',
              'fallback_provider': 'youtube',
              'youtube_video_id': '',
              'is_enabled': true,
            },
          ],
        },
      );
      final shelf = shelves.firstWhere((s) => s.id == 'jiosaavn_test');
      expect(shelf.kind, HomeShelfKind.manual);
      expect(shelf.manualItems, isNotEmpty);
      final track = shelf.manualItems.first;
      expect(track['title'], 'Kesariya');
      expect(track['artist'], 'Arijit Singh');
      expect(track['jiosaavnUrl'], contains('jiosaavn.com/song/'));
      expect(track['playbackSource'], 'jiosaavn');
      expect(track['youtubeId'], isEmpty);
    });

    test('JioSaavn items are omitted when the flag is off', () {
      final service = HomeFeedService();
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        jiosaavnEnabled: false,
        cmsSections: [
          {
            'id': 'jiosaavn_test',
            'title': 'JioSaavn Test',
            'source_type': 'jiosaavn_manual',
            'visible': true,
            'published': true,
          },
        ],
        cmsItems: {
          'jiosaavn_test': [
            {
              'id': 'item-1',
              'section_id': 'jiosaavn_test',
              'title': 'Kesariya',
              'jiosaavn_url':
                  'https://www.jiosaavn.com/song/kesariya/RDPkZEVaUXw',
              'provider': 'jiosaavn',
              'playback_provider': 'jiosaavn',
              'is_enabled': true,
            },
          ],
        },
      );
      final shelf = shelves.firstWhere((s) => s.id == 'jiosaavn_test');
      expect(shelf.manualItems, isEmpty);
    });
  });
}

// ── PHASE 17.5 REGRESSION: stale personalized keys must NOT hijack shelves ──
void staleKeyRegressionTests() {
  group('stale personalized keys (production bug regression)', () {
    test('youtube_playlist with key continue_listening stays a playlist shelf',
        () {
      final service = HomeFeedService();
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: [
          {
            'id': 'continue_123',
            'section_key': 'continue_listening',
            'title': 'My Playlist',
            'section_type': 'home_section',
            'source_type': 'youtube_playlist',
            'source_value': 'https://youtube.com/playlist?list=PLabc123xyz',
            'visible': true,
            'published': true,
            'max_items': 10,
          },
        ],
      );
      final shelf = shelves.singleWhere((s) => s.id == 'continue_123');
      expect(shelf.kind, HomeShelfKind.catalog,
          reason: 'playlist type must win over the stale key');
      expect(shelf.sourceType, 'youtube_playlist');
      expect(shelf.query, isNull);
      // The auto-inserted Continue Listening is the ONLY continue shelf.
      expect(
        shelves.where((s) => s.kind == HomeShelfKind.continueListening).length,
        1,
      );
    });

    test('youtube_search with key made_for_you stays a catalog shelf', () {
      final service = HomeFeedService();
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: [
          {
            'id': 'made_for_you',
            'section_key': 'made_for_you',
            'title': 'Made For You',
            'section_type': 'home_section',
            'source_type': 'youtube_search',
            'source_value': 'arijit singh songs',
            'query': 'arijit singh songs',
            'visible': true,
            'published': true,
            'max_items': 12,
          },
        ],
      );
      final shelf = shelves.singleWhere((s) => s.id == 'made_for_you');
      expect(shelf.kind, HomeShelfKind.catalog);
      expect(shelf.query, 'arijit singh songs');
    });

    test('jiosaavn_manual with key continue_listening is not continue', () {
      final service = HomeFeedService();
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        jiosaavnEnabled: true,
        cmsSections: [
          {
            'id': 'jsv_123',
            'section_key': 'continue_listening',
            'title': 'JioSaavn Picks',
            'section_type': 'home_section',
            'source_type': 'jiosaavn_manual',
            'source_value': '',
            'visible': true,
            'published': true,
            'max_items': 5,
          },
        ],
      );
      expect(
        shelves.where((s) => s.kind == HomeShelfKind.continueListening).length,
        1,
        reason: 'only the auto-inserted Continue Listening may exist',
      );
    });

    test('personalized sections still map by key (no regression)', () {
      final service = HomeFeedService();
      final shelves = service.buildShelfDescriptors(
        enableRemoteHome: true,
        cmsSections: [
          {
            'id': 'trending_now',
            'section_key': 'continue_listening',
            'title': 'Continue Listening 💖',
            'section_type': 'personalized',
            'source_type': 'personalized',
            'source_value': 'continue_listening',
            'visible': true,
            'published': true,
            'max_items': 15,
          },
        ],
      );
      final shelf = shelves.singleWhere((s) => s.id == 'trending_now');
      expect(shelf.kind, HomeShelfKind.continueListening);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/features/home/home_feed_service.dart';

void main() {
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
              'section_type': 'category',
              'source_type': 'youtube_search',
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
              'section_type': 'category',
              'source_type': 'youtube_search',
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
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// V Shots — YouTube Data API Client Tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/providers/adapters/youtube/youtube_data_api_client.dart';

void main() {
  group('YouTubeVideoItem ISO 8601 Duration Parser', () {
    test('parses PT3M45S into 225 seconds', () {
      expect(YouTubeVideoItem.parseIso8601Duration('PT3M45S'), 225);
    });

    test('parses PT1H2M10S into 3730 seconds', () {
      expect(YouTubeVideoItem.parseIso8601Duration('PT1H2M10S'), 3730);
    });

    test('parses PT45S into 45 seconds', () {
      expect(YouTubeVideoItem.parseIso8601Duration('PT45S'), 45);
    });

    test('parses PT12M into 720 seconds', () {
      expect(YouTubeVideoItem.parseIso8601Duration('PT12M'), 720);
    });

    test('handles empty or malformed strings gracefully', () {
      expect(YouTubeVideoItem.parseIso8601Duration(''), 0);
      expect(YouTubeVideoItem.parseIso8601Duration('invalid'), 0);
    });
  });

  group('YouTubeDataApiClient Fallback Catalog & Resilience', () {
    late YouTubeDataApiClient client;

    setUp(() {
      client = YouTubeDataApiClient();
    });

    tearDown(() {
      client.dispose();
    });

    test('returns curated tracks when offline or without API key', () async {
      final results = await client.searchMusicVideos('Arijit Singh');
      expect(results, isNotEmpty);
      expect(results.any((r) => r.channelTitle.contains('Arijit')), isTrue);
    });

    test('respects maxResults limit', () async {
      final results = await client.searchMusicVideos('hits', maxResults: 3);
      expect(results.length, lessThanOrEqualTo(3));
    });

    test('respects excludeIds', () async {
      const excludedId = 'kJQP7kiw5Fk';
      final results = await client.searchMusicVideos(
        'Despacito',
        excludeIds: {excludedId},
      );
      expect(results.any((r) => r.id == excludedId), isFalse);
    });

    test('getVideoDetails retrieves metadata for existing track', () async {
      final details = await client.getVideoDetails('kJQP7kiw5Fk');
      expect(details, isNotNull);
      expect(details!.id, 'kJQP7kiw5Fk');
      expect(details.title, contains('Despacito'));
    });

    test('catalog has no fabricated video IDs or thumbnail mismatches',
        () async {
      // Search across several categories and assert every returned video has
      // a well-formed, non-empty videoId and a thumbnail that corresponds to
      // THAT SAME videoId (never a generic/placeholder or a different video).
      const queries = [
        'bollywood songs',
        'punjabi songs',
        'devotional',
        'global pop',
        'indie acoustic',
        'workout',
        'sad emotional',
      ];
      for (final q in queries) {
        final results = await client.searchMusicVideos(q, maxResults: 25);
        expect(results, isNotEmpty,
            reason: 'fallback should never be empty for "$q"');
        for (final r in results) {
          expect(r.id.length, 11,
              reason: 'videoId for "${r.title}" must be an 11-char YouTube id');
          expect(r.thumbnailUrl, contains(r.id),
              reason:
                  'thumbnail for "${r.title}" must come from the same videoId ${r.id}');
        }
      }
    });

    test('known tracks map to their correct real videos', () async {
      final kesariya = await client.getVideoDetails('g6fnFALEseI');
      expect(kesariya!.title.toLowerCase(), contains('kesariya'));

      final aaftab = await client.getVideoDetails('U77d9912lrw');
      expect(aaftab!.title.toLowerCase(), contains('aaftaab'));

      final chooLo = await client.getVideoDetails('sFMRqxCexDk');
      expect(chooLo!.title.toLowerCase(), contains('choo lo'));
    });
  });
  group('Home Section Isolation', () {
    late YouTubeDataApiClient client;
    setUp(() => client = YouTubeDataApiClient());
    tearDown(() => client.dispose());

    test('each Home section returns ONLY its own category', () async {
      const cases = {
        'chill lofi late night beats official audio': 'ambient',
        'top bollywood hindi songs official music video': 'bollywood',
        'latest punjabi pop hits official audio': 'punjabi',
        'hindi indie acoustic songs official audio': 'indie',
        'billboard top global pop hits official audio': 'global',
        'devotional bhajan aarti official audio': 'devotional',
        'workout gym motivation hype songs': 'workout',
      };
      for (final entry in cases.entries) {
        final results = await client.searchMusicVideos(
          entry.key,
          maxResults: 15,
        );
        expect(results, isNotEmpty, reason: '${entry.key} should not be empty');
        for (final r in results) {
          expect(r.category, entry.value,
              reason: 'category leak for "${entry.key}" -> ${r.title}');
        }
      }
    });
  });
}

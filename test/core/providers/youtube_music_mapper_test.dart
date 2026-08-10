// ═════════════════════════════════════════════════════════════════════════════
// V Shots — YoutubeMusicMapper tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/providers/adapters/youtube/youtube_data_api_client.dart';
import 'package:v_shots/core/providers/adapters/youtube/youtube_music_mapper.dart';
import 'package:v_shots/shared/utils/text_utils.dart';

YouTubeVideoItem _makeVideo({
  required String id,
  required String title,
  required String author,
  int durationSeconds = 180,
}) {
  return YouTubeVideoItem(
    id: id,
    title: title,
    channelTitle: author,
    thumbnailUrl: 'https://img.youtube.com/vi/$id/hqdefault.jpg',
    durationSeconds: durationSeconds,
  );
}

void main() {
  const mapper = YoutubeMusicMapper();

  group('isPlayableMusic', () {
    test('rejects videos longer than maxMinutes', () {
      final video = _makeVideo(
        id: 'aaaaaaaaaaa',
        title: 'Long video',
        author: 'Someone',
        durationSeconds: 20 * 60,
      );
      expect(mapper.isPlayableMusic(video, maxMinutes: 15), isFalse);
    });

    test('rejects videos shorter than minMinutes when a floor is set', () {
      final video = _makeVideo(
        id: 'bbbbbbbbbbb',
        title: 'Tiny clip',
        author: 'Someone',
        durationSeconds: 30,
      );
      expect(
        mapper.isPlayableMusic(video, maxMinutes: 12, minMinutes: 1),
        isFalse,
      );
    });

    test('rejects titles containing non-music keywords', () {
      final video = _makeVideo(
        id: 'ccccccccccc',
        title: 'Full Podcast Episode 12',
        author: 'Someone',
        durationSeconds: 5 * 60,
      );
      expect(mapper.isPlayableMusic(video), isFalse);
    });

    test('accepts a normal-length music video with a clean title', () {
      final video = _makeVideo(
        id: 'ddddddddddd',
        title: 'Real Song (Official Audio)',
        author: 'Real Artist',
        durationSeconds: 3 * 60 + 30,
      );
      expect(mapper.isPlayableMusic(video), isTrue);
    });
  });

  group('mapSearchResults', () {
    const id1 = 'aaaaaaaaaa1';
    const id2 = 'aaaaaaaaaa2';
    const id3 = 'aaaaaaaaaa3';
    const id4 = 'aaaaaaaaaa4';

    test('filters, excludes, and caps at limit', () {
      final videos = [
        _makeVideo(
          id: id1,
          title: 'Song One',
          author: 'A',
          durationSeconds: 3 * 60,
        ),
        _makeVideo(
          id: id2,
          title: 'Song Two',
          author: 'B',
          durationSeconds: 3 * 60,
        ),
        _makeVideo(
          id: id3,
          title: 'Podcast Talk',
          author: 'C',
          durationSeconds: 3 * 60,
        ),
        _makeVideo(
          id: id4,
          title: 'Song Four',
          author: 'D',
          durationSeconds: 30 * 60,
        ),
      ];

      final results = mapper.mapSearchResults(
        videos,
        limit: 5,
        excludeIds: {id2},
      );

      expect(results, hasLength(1));
      expect(results.first.id, id1);
      expect(results.first.title, 'Song One');
    });
  });

  group('cleanTitle (shared/utils/text_utils.dart)', () {
    test('strips leading "Artist - " prefix', () {
      expect(cleanTitle('Real Artist - Real Song', 'Real Artist'), 'Real Song');
    });

    test('strips (Official Video)/[Official Audio] suffixes', () {
      expect(cleanTitle('Song (Official Video)', 'Artist'), 'Song');
      expect(cleanTitle('Song [Official Audio]', 'Artist'), 'Song');
    });

    test('strips (Lyrics)/(Audio) suffixes', () {
      expect(cleanTitle('Song (Lyrics)', 'Artist'), 'Song');
      expect(cleanTitle('Song (Audio)', 'Artist'), 'Song');
    });

    test('falls back to the original title if cleaning empties it', () {
      expect(cleanTitle('(Official Video)', 'Artist'), '(Official Video)');
    });
  });
}

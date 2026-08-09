// ════════════════════════════════════════════════
// V Shots — YoutubeMusicMapper tests (Phase 11)
// ════════════════════════════════════════════════
//
// Tests the pure filter/clean/map logic consolidated from what used to
// be 3 near-duplicate inline copies (Home/Search/For You feed) — see
// youtube_music_mapper.dart's file header. No real YouTube network
// call is made; `Video` objects are constructed directly.
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/providers/adapters/youtube/youtube_music_mapper.dart';
import 'package:v_shots/shared/utils/text_utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Video _makeVideo({
  required String id,
  required String title,
  required String author,
  Duration? duration,
}) {
  return Video(
    VideoId(id),
    title,
    author,
    ChannelId('UC${id.padRight(22, '0')}'),
    DateTime(2024, 1, 1), // uploadDate
    null, // uploadDateRaw
    null, // publishDate
    '', // description
    duration,
    ThumbnailSet(id),
    const [], // keywords
    const Engagement(0, 0, 0),
    false, // isLive
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
        duration: const Duration(minutes: 20),
      );
      expect(mapper.isPlayableMusic(video, maxMinutes: 15), isFalse);
    });

    test('rejects videos shorter than minMinutes when a floor is set', () {
      final video = _makeVideo(
        id: 'bbbbbbbbbbb',
        title: 'Tiny clip',
        author: 'Someone',
        duration: const Duration(seconds: 30),
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
        duration: const Duration(minutes: 5),
      );
      expect(mapper.isPlayableMusic(video), isFalse);
    });

    test('accepts a normal-length music video with a clean title', () {
      final video = _makeVideo(
        id: 'ddddddddddd',
        title: 'Real Song (Official Audio)',
        author: 'Real Artist',
        duration: const Duration(minutes: 3, seconds: 30),
      );
      expect(mapper.isPlayableMusic(video), isTrue);
    });
  });

  group('mapSearchResults', () {
    // Real YouTube video IDs are exactly 11 chars from a specific
    // charset — VideoId's constructor validates this, so test ids must
    // look like real ones (arbitrary but 11 chars, alnum+-_).
    const id1 = 'aaaaaaaaaa1';
    const id2 = 'aaaaaaaaaa2';
    const id3 = 'aaaaaaaaaa3';
    const id4 = 'aaaaaaaaaa4';

    test('filters, excludes, and caps at limit', () {
      final videos = [
        _makeVideo(
            id: id1, title: 'Song One', author: 'A', duration: const Duration(minutes: 3)),
        _makeVideo(
            id: id2, title: 'Song Two', author: 'B', duration: const Duration(minutes: 3)),
        _makeVideo(
            id: id3,
            title: 'Podcast Talk',
            author: 'C',
            duration: const Duration(minutes: 3)),
        _makeVideo(
            id: id4, title: 'Song Four', author: 'D', duration: const Duration(minutes: 30)),
      ];

      final results = mapper.mapSearchResults(
        videos,
        limit: 5,
        excludeIds: {id2},
      );

      // id2 excluded, id3 filtered (podcast), id4 filtered (too long) —
      // only id1 remains.
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
      // Pathological input that would fully strip to empty — must not
      // return an empty string.
      expect(cleanTitle('(Official Video)', 'Artist'), '(Official Video)');
    });
  });
}

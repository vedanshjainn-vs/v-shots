// ═════════════════════════════════════════════════════════════════════════════
// V Shots — InnerTube normalizer tests
//
// Verifies the InnerTube → ProviderTrack mapping and the shared quality
// filter (podcast/compilation/jukebox exclusion + duration caps + dedup),
// so Home / Discovery / Search only ever surface clean, playable music.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/innertube/inner_tube_models.dart';
import 'package:v_shots/core/innertube/inner_tube_normalizer.dart';

InnerTubeVideoItem _item(
  String id, {
  String title = 'Song',
  String channel = 'Artist',
  int duration = 200,
}) =>
    InnerTubeVideoItem(
      videoId: id,
      title: title,
      channelName: channel,
      thumbnailUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      durationSeconds: duration,
    );

void main() {
  const normalizer = InnerTubeNormalizer();

  group('quality filter', () {
    test('rejects podcasts, compilations, jukeboxes, interviews', () {
      expect(normalizer.isPlayableMusic(_item('1', title: 'My Podcast ep 1')),
          isFalse);
      expect(normalizer.isPlayableMusic(_item('2', title: 'Chill Compilation')),
          isFalse);
      expect(normalizer.isPlayableMusic(_item('3', title: 'Bollywood Jukebox')),
          isFalse);
      expect(normalizer.isPlayableMusic(_item('4', title: 'Artist Interview')),
          isFalse);
    });

    test('rejects videos longer than the max duration', () {
      expect(
        normalizer.isPlayableMusic(_item('5', duration: 16 * 60)),
        isFalse,
      );
      expect(
        normalizer.isPlayableMusic(_item('6', duration: 3 * 60)),
        isTrue,
      );
    });

    test('respects a minimum duration when set', () {
      expect(
        normalizer.isPlayableMusic(
          _item('7', duration: 30),
          minMinutes: 1,
        ),
        isFalse,
      );
    });

    test('accepts normal tracks', () {
      expect(
        normalizer.isPlayableMusic(_item('8', title: 'Tum Hi Ho')),
        isTrue,
      );
    });
  });

  group('mapping', () {
    test('maps to ProviderTrack with one videoId identity', () {
      final track = normalizer.toProviderTrack(_item('vid1'));
      expect(track.id, 'vid1');
      expect(track.artist, 'Artist');
      expect(track.durationSeconds, 200);
    });

    test('cleanTitle strips official-video suffixes and artist prefix', () {
      final track = normalizer.toProviderTrack(
        _item(
          'vid2',
          title: 'Arijit Singh - Tum Hi Ho (Official Video)',
          channel: 'Arijit Singh',
        ),
      );
      expect(track.title, 'Tum Hi Ho');
    });

    test('falls back to Unknown Artist when channel is missing', () {
      final track = normalizer.toProviderTrack(
        _item('vid3', channel: ''),
      );
      expect(track.artist, 'Unknown Artist');
    });
  });

  group('mapSearchResults', () {
    test('filters, maps, dedupes, and respects limit + excludeIds', () {
      final items = [
        _item('a', title: 'Good Song'),
        _item('b', title: 'Interview with star'), // filtered out
        _item('c', title: 'Another Good Song'),
        _item('a', title: 'Good Song'), // duplicate id
      ];
      final result = normalizer.mapSearchResults(
        items,
        limit: 10,
        excludeIds: {'c'},
      );
      expect(result.map((t) => t.id), ['a']);
    });

    test('stops at the requested limit', () {
      final items = List.generate(
        10,
        (i) => _item('id$i', title: 'Track $i'),
      );
      final result = normalizer.mapSearchResults(items, limit: 3);
      expect(result, hasLength(3));
    });
  });
}

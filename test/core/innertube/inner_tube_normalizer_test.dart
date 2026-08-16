// ═════════════════════════════════════════════════════════════════════════════
// V Shots — InnerTube normalizer tests
//
// Verifies the InnerTube → ProviderTrack mapping and the content policy:
//   • official/verified uploads surface first
//   • non-music + unofficial-upload signals are dropped in the strict pass
//   • a relaxed fallback guarantees shelves never come back empty
//   • duration caps + dedup still apply
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/innertube/inner_tube_models.dart';
import 'package:v_shots/core/innertube/inner_tube_normalizer.dart';

InnerTubeVideoItem _item(
  String id, {
  String title = 'Song',
  String channel = 'Artist',
  int duration = 200,
  bool isOfficial = false,
  String? channelId,
}) =>
    InnerTubeVideoItem(
      videoId: id,
      title: title,
      channelName: channel,
      thumbnailUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      durationSeconds: duration,
      isOfficial: isOfficial,
      channelId: channelId,
    );

void main() {
  const normalizer = InnerTubeNormalizer();

  group('strict quality filter', () {
    test('rejects clearly non-music (podcast/interview/reaction/tutorial)', () {
      expect(
        normalizer.isPlayableMusic(_item('1', title: 'My Podcast ep 1')),
        isFalse,
      );
      expect(
        normalizer.isPlayableMusic(_item('4', title: 'Artist Interview')),
        isFalse,
      );
      expect(
        normalizer.isPlayableMusic(_item('9', title: 'Reaction video')),
        isFalse,
      );
      expect(
        normalizer.isPlayableMusic(_item('10', title: 'FL Tutorial')),
        isFalse,
      );
    });

    test(
      'rejects unofficial-upload signals (lyrics/karaoke/slowed/status)',
      () {
        expect(
          normalizer.isPlayableMusic(_item('11', title: 'Song Lyrics')),
          isFalse,
        );
        expect(
          normalizer.isPlayableMusic(_item('12', title: 'Song Karaoke Track')),
          isFalse,
        );
        expect(
          normalizer.isPlayableMusic(_item('13', title: 'Slowed + Reverb')),
          isFalse,
        );
        expect(
          normalizer.isPlayableMusic(
            _item('14', title: 'WhatsApp Status Song'),
          ),
          isFalse,
        );
      },
    );

    test(
        'accepts official original songs (no longer drops compilations by '
        'title — duration cap handles long ones)', () {
      expect(
        normalizer.isPlayableMusic(_item('8', title: 'Tum Hi Ho')),
        isTrue,
      );
      // A short "compilation" under the duration cap is still music.
      expect(
        normalizer.isPlayableMusic(
          _item('2', title: 'Chill Compilation', duration: 240),
        ),
        isTrue,
      );
    });

    test('rejects videos longer than the max duration', () {
      expect(
        normalizer.isPlayableMusic(_item('5', duration: 16 * 60)),
        isFalse,
      );
      expect(normalizer.isPlayableMusic(_item('6', duration: 3 * 60)), isTrue);
    });

    test('respects a minimum duration when set', () {
      expect(
        normalizer.isPlayableMusic(_item('7', duration: 30), minMinutes: 1),
        isFalse,
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
      final track = normalizer.toProviderTrack(_item('vid3', channel: ''));
      expect(track.artist, 'Unknown Artist');
    });

    test('passes official + channelId metadata into ProviderTrack', () {
      final track = normalizer.toProviderTrack(
        _item(
          'vid4',
          isOfficial: true,
          channelId: 'UC_official_123',
        ),
      );
      expect(track.isOfficial, isTrue);
      expect(track.channelId, 'UC_official_123');
    });

    test('never fabricates official: unbadged items stay false/null', () {
      final track = normalizer.toProviderTrack(_item('vid5'));
      expect(track.isOfficial, isFalse);
      expect(track.channelId, isNull);
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

    test('surfaces official uploads before unofficial ones', () {
      final items = [
        _item('unofficial1', title: 'Tum Hi Ho', channel: 'LyricsChannel'),
        _item(
          'official1',
          title: 'Tum Hi Ho (Official Video)',
          channel: 'Arijit Singh',
          isOfficial: true,
        ),
        _item('unofficial2', title: 'Tum Hi Ho Cover', channel: 'FanChannel'),
      ];
      final result = normalizer.mapSearchResults(items, limit: 10);
      expect(
        result.first.id,
        'official1',
        reason: 'official/verified uploads must come first',
      );
      expect(result.map((t) => t.id), contains('official1'));
    });

    test('relaxed fallback keeps content when everything is unofficial', () {
      final items = [
        _item('u1', title: 'Song Lyrics Video', channel: 'LyricsChannel'),
        _item('u2', title: 'Song Slowed Reverb', channel: 'SlowChannel'),
      ];
      final result = normalizer.mapSearchResults(items, limit: 10);
      // Strict pass drops both; relaxed pass returns them rather than empty.
      expect(result, isNotEmpty);
      expect(result.map((t) => t.id), containsAll(['u1', 'u2']));
    });

    test('still returns empty for genuinely non-music-only input', () {
      final items = [
        _item('p1', title: 'My Podcast ep 1'),
        _item('p2', title: 'Artist Interview'),
      ];
      final result = normalizer.mapSearchResults(items, limit: 10);
      expect(result, isEmpty);
    });

    test('stops at the requested limit', () {
      final items = List.generate(10, (i) => _item('id$i', title: 'Track $i'));
      final result = normalizer.mapSearchResults(items, limit: 3);
      expect(result, hasLength(3));
    });
  });
}

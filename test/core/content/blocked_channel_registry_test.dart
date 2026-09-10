import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/content/blocked_channel_registry.dart';
import 'package:v_shots/core/music/music_validator.dart';

void main() {
  final registry = BlockedChannelRegistry.instance;

  group('BlockedChannelRegistry — owner blocklist', () {
    test('contains the three owner-blocked channels', () {
      expect(registry.length, 3);
      expect(
        BlockedChannelRegistry.entries
            .any((e) => e.displayName == 'Prakash Jojawar'),
        isTrue,
      );
      expect(
        BlockedChannelRegistry.entries
            .any((e) => e.displayName == 'Rawat Super Star Music'),
        isTrue,
      );
      expect(
        BlockedChannelRegistry.entries
            .any((e) => e.displayName == 'Gaurav Mali'),
        isTrue,
      );
    });

    test('exact channel ID blocks (authoritative identifier)', () {
      expect(
        registry.isBlocked(channelId: 'UCigy0uZUtH6V2PAYHftQ4Qg'),
        isTrue,
      );
      expect(
        registry.isBlocked(channelId: 'UCTNwxS7Cptx0J6tMPGGV9Dw'),
        isTrue,
      );
      expect(
        registry.isBlocked(channelId: 'UCvFeU7u_H_d2o6NXSsWbSdw'), // unrelated
        isFalse,
      );
    });

    test('alternate casing cannot bypass channel IDs or names', () {
      expect(
        registry.isBlocked(channelId: 'UCIGY0UZUT H6V2PAYHFTQ4QG'.trim()),
        isFalse, // IDs are case-sensitive exact — altered ID is unknown
      );
      expect(registry.isBlocked(channelName: 'PRAKASH JOJAWAR'), isTrue);
      expect(registry.isBlocked(channelName: 'gaurav mali'), isTrue);
      expect(registry.isBlocked(channelName: 'RAWAT SUPER STAR MUSIC'), isTrue);
    });

    test('name normalization: punctuation, spacing and case variants', () {
      expect(registry.isBlocked(channelName: 'prakash  jojawar'), isTrue);
      expect(registry.isBlocked(channelName: 'Rawat-Super-Star-Music'), isTrue);
      expect(
          registry.isBlocked(channelName: 'Rawat   Superstar  Music'), isTrue);
      // No-space concatenation IS a recognized re-spacing variant —
      // exactly the kind of bypass the loose key must catch.
      expect(registry.isBlocked(channelName: 'RAWATSUPERSTARMUSIC'), isTrue);
      expect(registry.isBlocked(channelName: 'RawatSuperstarMusic'), isTrue);
      expect(registry.isBlocked(channelName: 'Gaurav Mali.'), isTrue);
    });

    test('aliases block (PRG Hindi Audio rebrand etc.)', () {
      expect(registry.isBlocked(channelName: 'PRG Hindi Audio'), isTrue);
      expect(registry.isBlocked(channelName: 'prg hindi audio'), isTrue);
      expect(registry.isBlocked(channelName: 'Rawat Super Star'), isTrue);
      expect(registry.isBlocked(channelName: 'Gaurav Mali Official'), isTrue);
    });

    test('URL variants all resolve to the block', () {
      expect(
        registry.isBlocked(
          channelUrl:
              'https://www.youtube.com/channel/UCigy0uZUtH6V2PAYHftQ4Qg',
        ),
        isTrue,
      );
      expect(
        registry.isBlocked(channelUrl: 'https://youtube.com/@prghindiaudio'),
        isTrue,
      );
      expect(
        registry.isBlocked(channelUrl: 'https://www.youtube.com/@GauravMalii'),
        isTrue,
      );
      expect(
        registry.isBlocked(
            channelUrl: 'https://m.youtube.com/c/RawatSuperStarMusic'),
        isTrue,
      );
      expect(
        registry.isBlocked(
          channelUrl:
              'https://www.youtube.com/channel/UCvFeU7u_H_d2o6NXSsWbSdw',
        ),
        isFalse,
      );
    });

    test('NO substring false positives — unrelated channels stay allowed', () {
      expect(
          registry.isBlocked(channelName: 'Prakash Jojawar Fan Club'), isFalse);
      expect(registry.isBlocked(channelName: 'The Gaurav Mali Experience'),
          isFalse);
      expect(
          registry.isBlocked(channelName: 'Rawat Super Star Music Live India'),
          isFalse);
      expect(registry.isBlocked(channelName: 'Gauravv Malli'), isFalse);
      expect(registry.isBlocked(channelName: 'T-Series'), isFalse);
      expect(registry.isBlocked(channelName: 'Zee Music Company'), isFalse);
    });

    test('artist fallback catches tracks that only carry artist metadata', () {
      expect(registry.isBlocked(artist: 'Prakash Jojawar'), isTrue);
      expect(registry.isBlocked(artist: 'Gaurav Mali'), isTrue);
      expect(registry.isBlocked(artist: 'Arijit Singh'), isFalse);
    });

    test('empty / null signals never block', () {
      expect(registry.isBlocked(), isFalse);
      expect(registry.isBlocked(channelName: ''), isFalse);
      expect(registry.isBlocked(channelId: '', channelName: ''), isFalse);
    });
  });

  group('isContentAllowed — track-level eligibility', () {
    Map<String, dynamic> track(Map<String, dynamic> extra) => {
          'id': 'dQw4w9WgXcQ',
          'title': 'Some Song',
          'artist': 'Some Artist',
          ...extra,
        };

    test('blocked channelTitle rejected', () {
      expect(
        BlockedChannelRegistry.isContentAllowed(
          track({'channelTitle': 'Prakash Jojawar'}),
        ),
        isFalse,
      );
      expect(
        BlockedChannelRegistry.isContentAllowed(
          track({'channel': 'Gaurav Mali'}),
        ),
        isFalse,
      );
    });

    test('blocked channelId rejected even with innocent channelTitle', () {
      // Duplicated-metadata bypass attempt: id says blocked, title lies.
      expect(
        BlockedChannelRegistry.isContentAllowed(track({
          'channelId': 'UCigy0uZUtH6V2PAYHftQ4Qg',
          'channelTitle': 'Totally Legit Music',
          'artist': 'Someone Else',
        })),
        isFalse,
      );
    });

    test('clean tracks allowed', () {
      expect(
        BlockedChannelRegistry.isContentAllowed(
          track({
            'channelTitle': 'T-Series',
            'channelId': 'UCq-Fj5jknLsUf-MWSy4_brA'
          }),
        ),
        isTrue,
      );
    });

    test('filterBlocked preserves order and drops only blocked', () {
      final tracks = [
        track({'id': 'a', 'channelTitle': 'T-Series'}),
        track({'id': 'b', 'channelTitle': 'Prakash Jojawar'}),
        track({'id': 'c', 'channelTitle': 'Zee Music Company'}),
        track({'id': 'd', 'channelId': 'UCTNwxS7Cptx0J6tMPGGV9Dw'}),
      ];
      final filtered = BlockedChannelRegistry.filterBlocked(tracks);
      expect(filtered.map((t) => t['id']), ['a', 'c']);
    });
  });

  group('sanitizeQueue — playback last line of defense', () {
    Map<String, dynamic> t(String id, String channel) => {
          'id': id,
          'title': 'Song $id',
          'artist': 'Artist $id',
          'channelTitle': channel,
        };

    test('blocked tracks removed from queue, start index mapped', () {
      final queue = [t('a', 'X'), t('b', 'Prakash Jojawar'), t('c', 'Y')];
      final (start, safe) = BlockedChannelRegistry.sanitizeQueue(queue, 2);
      expect(safe.map((x) => x['id']), ['a', 'c']);
      expect(start, 1); // 'c' was index 2, maps to 1 in sanitized list
    });

    test('starting ON a blocked track shifts to previous eligible', () {
      final queue = [t('a', 'X'), t('b', 'Gaurav Mali'), t('c', 'Y')];
      final (start, safe) = BlockedChannelRegistry.sanitizeQueue(queue, 1);
      expect(safe.map((x) => x['id']), ['a', 'c']);
      expect(start, 0);
    });

    test('all-blocked queue returns empty', () {
      final queue = [t('a', 'Prakash Jojawar'), t('b', 'Gaurav Mali')];
      final (start, safe) = BlockedChannelRegistry.sanitizeQueue(queue, 0);
      expect(safe, isEmpty);
      expect(start, -1);
    });

    test('clean queue untouched (index preserved)', () {
      final queue = [t('a', 'X'), t('b', 'Y'), t('c', 'Z')];
      final (start, safe) = BlockedChannelRegistry.sanitizeQueue(queue, 1);
      expect(safe.length, 3);
      expect(start, 1);
    });
  });

  group('MusicContentValidator — BLOCKED_CHANNEL is authoritative', () {
    const validator = MusicContentValidator();

    test('blocked channel rejected with BLOCKED_CHANNEL reason', () {
      final result = validator.validate({
        'id': 'x1',
        'title': 'Romantic Hindi Song 2026',
        'artist': 'Prakash Jojawar',
        'channelTitle': 'Prakash Jojawar',
        'duration': 210,
        'artwork': 'https://i.ytimg.com/vi/x1/hq720.jpg',
        'isOfficial': true,
      });
      expect(result.isMusic, isFalse);
      expect(result.rejectionReason, 'BLOCKED_CHANNEL');
    });

    test('blocked channel rejected BEFORE the music-confidence path', () {
      // Even a perfectly-formed, official-looking track is rejected.
      final result = validator.validate({
        'id': 'x2',
        'title': 'Official Audio',
        'artist': 'Gaurav Mali',
        'channelId': 'UCTNwxS7Cptx0J6tMPGGV9Dw',
        'channelTitle': 'Gaurav Mali',
        'duration': 200,
        'artwork': 'https://i.ytimg.com/vi/x2/hq720.jpg',
        'isOfficial': true,
      });
      expect(result.rejectionReason, 'BLOCKED_CHANNEL');
      expect(result.confidence, 0.0);
    });

    test('identical track WITHOUT the blocked channel still validates', () {
      final result = validator.validate({
        'id': 'x3',
        'title': 'Official Audio',
        'artist': 'Arijit Singh',
        'channelId': 'UCq-Fj5jknLsUf-MWSy4_brA',
        'channelTitle': 'T-Series',
        'duration': 200,
        'artwork': 'https://i.ytimg.com/vi/x3/hq720.jpg',
        'isOfficial': true,
      });
      expect(result.rejectionReason, isNot('BLOCKED_CHANNEL'));
    });
  });
}

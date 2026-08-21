// ═════════════════════════════════════════════════════════════════════════════
// V Shots — MusicContentValidator / canonicalizer tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/music/music_canonicalizer.dart';
import 'package:v_shots/core/music/music_validator.dart';

Map<String, dynamic> _t(
  String id,
  String title,
  String artist, {
  int duration = 200,
  bool official = false,
}) =>
    {
      'id': id,
      'title': title,
      'artist': artist,
      'artwork': 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      'duration': duration,
      if (official) 'isOfficial': true,
    };

void main() {
  const validator = MusicContentValidator();

  group('MusicContentValidator', () {
    test('rejects non-music (gaming/news/podcast/reaction/vlog)', () {
      expect(
        validator.validate(_t('1', 'PUBG Gameplay', 'Gamer')).isMusic,
        isFalse,
      );
      expect(
        validator.validate(_t('2', 'Daily News Update', 'News24')).isMusic,
        isFalse,
      );
      expect(
        validator.validate(_t('3', 'The Daily Podcast', 'Host')).isMusic,
        isFalse,
      );
      expect(
        validator.validate(_t('4', 'Reacting to Top Songs', 'Reactor')).isMusic,
        isFalse,
      );
      expect(
        validator.validate(_t('5', 'My Daily Vlog', 'Vlogger')).isMusic,
        isFalse,
      );
    });

    test('accepts real music with artist + duration', () {
      final r = validator.validate(_t('6', 'Tum Hi Ho', 'Arijit Singh'));
      expect(r.isMusic, isTrue);
      expect(
        r.confidence,
        greaterThanOrEqualTo(MusicContentValidator.threshold),
      );
    });

    test('official/verified uploads score much higher', () {
      final plain = validator.validate(_t('7', 'Song X', 'Artist Y'));
      final official = validator.validate(
        _t('8', 'Song X', 'Artist Y', official: true),
      );
      expect(official.confidence, greaterThan(plain.confidence));
    });

    test('unofficial-upload signals lower confidence', () {
      final official = validator.validate(
        _t('9', 'Tum Hi Ho (Official Video)', 'Arijit Singh', official: true),
      );
      final lyrics = validator.validate(
        _t('10', 'Tum Hi Ho Lyrics', 'LyricsHub'),
      );
      expect(lyrics.confidence, lessThan(official.confidence));
    });

    test('never fabricates official: unbadged items stay non-official', () {
      expect(_t('11', 'Song', 'Artist')['isOfficial'], isNull);
    });
  });

  group('canonicalization / dedup', () {
    test('canonicalMusicKey merges official-audio vs music-video variants', () {
      final a = canonicalMusicKey(
        _t('a', 'Tum Hi Ho (Official Audio)', 'Arijit Singh'),
      );
      final b = canonicalMusicKey(
        _t('b', 'Tum Hi Ho (Official Video)', 'Arijit Singh'),
      );
      final c = canonicalMusicKey(_t('c', 'Tum Hi Ho', 'Arijit Singh'));
      expect(a, b);
      expect(a, c);
    });

    test('deduplicateMusicItems keeps ONE canonical representation', () {
      final tracks = [
        _t('a', 'Tum Hi Ho (Official Audio)', 'Arijit Singh'),
        _t('b', 'Tum Hi Ho (Official Video)', 'Arijit Singh', official: true),
        _t('c', 'Tum Hi Ho', 'Arijit Singh'),
      ];
      final result = deduplicateMusicItems(tracks);
      expect(result, hasLength(1));
      expect(
        result.single['id'],
        'b',
        reason: 'official representation must win',
      );
    });

    test('distinct songs stay distinct', () {
      final result = deduplicateMusicItems([
        _t('a', 'Song One', 'Artist'),
        _t('b', 'Song Two', 'Artist'),
      ]);
      expect(result, hasLength(2));
    });
  });

  group('validateAndFilterMusic', () {
    test('drops non-music and keeps music (canonicalized)', () {
      final result = validateAndFilterMusic([
        _t('a', 'Romantic Song', 'T-Series'),
        _t('b', 'PUBG Gameplay', 'Gamer'),
        _t('c', 'Sad Song', 'Sony Music'),
      ]);
      expect(result.map((t) => t['id']).toList(), ['a', 'c']);
    });

    test('empty input stays empty', () {
      expect(validateAndFilterMusic(const []), isEmpty);
    });
  });
}

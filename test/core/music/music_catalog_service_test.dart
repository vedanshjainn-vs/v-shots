// ═════════════════════════════════════════════════════════════════════════════
// V Shots — MusicCatalogService + variant/canonicalization refinement tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/music/music_catalog_service.dart';
import 'package:v_shots/core/music/music_canonicalizer.dart';
import 'package:v_shots/core/music/music_models.dart';
import 'package:v_shots/core/music/music_validator.dart';

Map<String, dynamic> _t(
  String id,
  String title,
  String artist, {
  int duration = 200,
  bool official = false,
  String? channelId,
}) =>
    {
      'id': id,
      'title': title,
      'artist': artist,
      'artwork': 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      'duration': duration,
      if (official) 'isOfficial': true,
      if (channelId != null) 'channelId': channelId,
    };

void main() {
  const validator = MusicContentValidator();

  group('officiality / metadata / variant scores', () {
    test('officialityScore: badge > title-official > none', () {
      final badged = validator.validate(
        _t('1', 'Song X', 'Artist', official: true, channelId: 'UC1'),
      );
      final titleOfficial = validator.validate(
        _t('2', 'Song X (Official)', 'Artist'),
      );
      final plain = validator.validate(_t('3', 'Song X', 'Artist'));
      expect(
        badged.officialityScore,
        greaterThan(titleOfficial.officialityScore),
      );
      expect(
        titleOfficial.officialityScore,
        greaterThan(plain.officialityScore),
      );
    });

    test('metadataQualityScore reflects completeness', () {
      final full = validator.validate(
        _t('1', 'Song X', 'Artist', official: true, channelId: 'UC1'),
      );
      expect(full.metadataQualityScore, 1.0);
      final bare = validator.validate({'id': '2', 'title': 'T'});
      expect(bare.metadataQualityScore, lessThan(full.metadataQualityScore));
    });

    test('variant classification', () {
      expect(
        validator
            .validate(_t('a', 'Song X (Official Remix)', 'A', official: true))
            .variant,
        MusicVariantType.officialRemix,
      );
      expect(
        validator.validate(_t('b', 'Song X Karaoke', 'K')).variant,
        MusicVariantType.karaoke,
      );
      expect(
        validator.validate(_t('c', 'Song X Slowed Reverb', 'S')).variant,
        MusicVariantType.slowedReverb,
      );
    });

    test('content type detection', () {
      expect(
        validator
            .validate(_t('d', 'Song X Official Video', 'A'))
            .detectedContentType,
        MusicContentType.musicVideo,
      );
      expect(
        validator.validate(_t('e', 'Song X', 'A')).detectedContentType,
        MusicContentType.song,
      );
    });

    test('official remix/live accepted; random karaoke rejected', () {
      final remix = validator.validate(
        _t(
          'f',
          'Song X (Official Remix)',
          'A',
          official: true,
          channelId: 'UC1',
        ),
      );
      expect(remix.isMusic, isTrue);

      final karaoke = validator.validate(
        _t('g', 'Song X Karaoke', 'RandomFan'),
      );
      expect(
        karaoke.isMusic,
        isFalse,
        reason: 'random-uploader karaoke must not reach primary shelves',
      );
    });
  });

  group('canonicalization preserves versions', () {
    test('remix/live/acoustic stay distinct entities', () {
      final base = canonicalMusicKey(_t('1', 'Song X', 'A'));
      final remix = canonicalMusicKey(_t('2', 'Song X Remix', 'A'));
      final live = canonicalMusicKey(_t('3', 'Song X (Live)', 'A'));
      expect(base, isNot(remix));
      expect(base, isNot(live));
    });

    test('audio/video variants of the same song merge to one', () {
      final audio = _t('1', 'Song X (Official Audio)', 'A', official: true);
      final video = _t('2', 'Song X (Official Video)', 'A', official: true);
      final result = deduplicateMusicItems([audio, video]);
      expect(result, hasLength(1));
      expect(
        result.single['id'],
        '2',
        reason: 'official music video preferred over audio',
      );
    });
  });

  group('MusicCatalogService', () {
    test('ingest validates + dedupes + reports diagnostics', () {
      const catalog = MusicCatalogService();
      final result = catalog.ingest([
        _t('a', 'Good Song', 'Artist'),
        _t('b', 'PUBG Gameplay', 'Gamer'), // rejected
        _t('a', 'Good Song', 'Artist'), // raw duplicate
      ]);
      expect(result.items.map((t) => t['id']).toList(), ['a']);
      expect(result.rejected, 1);
      expect(result.duplicates, 1);
    });

    test('cache key differentiates modes and filters', () {
      final forYou = musicCatalogCacheKey(mode: 'for_you');
      final trending = musicCatalogCacheKey(mode: 'trending');
      final trendingHindi = musicCatalogCacheKey(
        mode: 'trending',
        languages: ['hindi'],
        moods: ['romantic'],
      );
      expect(forYou, isNot(trending));
      expect(trending, isNot(trendingHindi));
      expect(
        trendingHindi,
        musicCatalogCacheKey(
          mode: 'trending',
          languages: ['hindi'],
          moods: ['romantic'],
        ),
      );
    });
  });
}

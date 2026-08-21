// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Music entity resolver + title/canonical tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/music/music_entities.dart';
import 'package:v_shots/core/music/music_entity_resolver.dart';
import 'package:v_shots/core/providers/provider_models.dart';

ProviderTrack _track(
  String id,
  String title,
  String artist, {
  String? channelId,
  bool official = false,
}) => ProviderTrack(
  id: id,
  title: title,
  artist: artist,
  artworkUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
  durationSeconds: 200,
  channelId: channelId,
  isOfficial: official,
);

void main() {
  const resolver = MusicEntityResolver();

  group('normalizeMusicTitle', () {
    test('strips representation markers', () {
      expect(normalizeMusicTitle('Tum Hi Ho (Official Video)'), 'Tum Hi Ho');
      expect(normalizeMusicTitle('Tum Hi Ho Official Audio'), 'Tum Hi Ho');
      expect(normalizeMusicTitle('Song | Official Video | Full HD'), 'Song');
    });

    test('keeps meaningful variants', () {
      expect(normalizeMusicTitle('Tum Hi Ho Remix'), 'Tum Hi Ho Remix');
      expect(normalizeMusicTitle('Tum Hi Ho Acoustic'), 'Tum Hi Ho Acoustic');
      expect(normalizeMusicTitle('Tum Hi Ho Live'), 'Tum Hi Ho Live');
    });
  });

  group('canonicalSongId / variants', () {
    test(
      'same song, different YouTube representations → same canonical id',
      () {
        final a = resolver.resolveTrack(
          _track('v1', 'Tum Hi Ho (Official Video)', 'Arijit Singh'),
        );
        final b = resolver.resolveTrack(
          _track('v2', 'Tum Hi Ho (Official Audio)', 'Arijit Singh'),
        );
        expect(a.canonicalId, b.canonicalId);
      },
    );

    test('remix / live stay separate', () {
      final original = resolver.resolveTrack(
        _track('v1', 'Tum Hi Ho', 'Arijit Singh'),
      );
      final remix = resolver.resolveTrack(
        _track('v2', 'Tum Hi Ho Remix', 'Arijit Singh'),
      );
      final live = resolver.resolveTrack(
        _track('v3', 'Tum Hi Ho (Live)', 'Arijit Singh'),
      );
      expect(remix.canonicalId, isNot(original.canonicalId));
      expect(live.canonicalId, isNot(original.canonicalId));
      expect(
        resolver
            .resolveTrack(_track('v4', 'Tum Hi Ho (Live)', 'Arijit Singh'))
            .variant,
        MusicVariant.live,
      );
    });

    test('never uses the YouTube videoId as the canonical id', () {
      final r = resolver.resolveTrack(
        _track('videoId123', 'Song X', 'Artist Y'),
      );
      expect(r.canonicalId, isNot('videoId123'));
      expect(r.canonicalId, contains('song x'));
    });
  });

  group('artist/channel separation', () {
    test('prefers real artistId (channelId) when present', () {
      final r = resolver.resolveTrack(
        _track('v1', 'Song', 'Arijit Singh', channelId: 'UC_official'),
      );
      expect(r.artist.id, 'UC_official');
      expect(r.artist.name, 'Arijit Singh');
    });

    test('falls back to name identity when no channelId', () {
      final r = resolver.resolveTrack(_track('v1', 'Song', 'Unknown Channel'));
      expect(r.artist.id, startsWith('artist:'));
      expect(r.artist.name, 'Unknown Channel');
    });

    test('verified follows the real official badge, never the name', () {
      final r = resolver.resolveTrack(
        _track('v1', 'Song', 'Official Music Records', official: false),
      );
      expect(
        r.artist.verified,
        isFalse,
        reason: '"official" in the name is NOT a verification signal',
      );
    });
  });
}

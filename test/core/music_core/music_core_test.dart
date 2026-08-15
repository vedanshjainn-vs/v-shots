// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — music_core tests (vision §3, §5, §22, §47, §48)
//
// Verifies:
//   - capability matrix declares YouTube playback via official IFrame only
//   - track normalizer does NOT merge distinct versions (live/remastered)
//     but DOES collapse genuine duplicates (official-audio variants)
//   - playback resolver respects provider availability + auth + region
//   - no unauthorized playback path is ever invented
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/music_core/playback_resolver.dart';
import 'package:v_shots/core/music_core/provider_capabilities.dart';
import 'package:v_shots/core/music_core/track_normalizer.dart';

void main() {
  const normalizer = TrackNormalizer();
  const matrix = ProviderCapabilityMatrix.youtubeOnly;
  const resolver = PlaybackResolver(matrix: matrix);

  group('ProviderCapabilityMatrix', () {
    test('YouTube allows full playback (official IFrame)', () {
      final yt = matrix.byId('youtube');
      expect(yt, isNotNull);
      expect(yt!.allowsFullPlayback, isTrue);
      expect(yt.supports(ProviderCapability2.fullPlayback), isTrue);
      expect(yt.allowsBackgroundPlayback, isFalse);
    });

    test('Spotify/Apple are declared but do NOT claim full playback', () {
      expect(matrix.byId('spotify')!.allowsFullPlayback, isFalse);
      expect(matrix.byId('applemusic')!.allowsFullPlayback, isFalse);
    });
  });

  group('TrackNormalizer', () {
    test('does NOT merge distinct versions (live vs studio)', () {
      // Same base, but "Live" is a distinct version, not a duplicate.
      final v = normalizer.versionOf('Song Name', 'Song Name - Live');
      expect(v, isNot(TrackVersion.original));
    });

    test('does NOT merge remastered as original duplicate', () {
      final v = normalizer.versionOf('Song', 'Song (2011 Remaster)');
      expect(v, TrackVersion.remastered);
    });

    test('collapses official-audio/lyric duplicates to the same base', () {
      expect(
        normalizer.isSameBaseTrack(
          titleA: 'Kesariya',
          titleB: 'Kesariya (Official Audio)',
          artistA: 'Arijit Singh',
          artistB: 'Arijit Singh',
        ),
        isTrue,
      );
    });

    test('classifies sped-up / slowed / instrumental versions', () {
      expect(
          normalizer.versionOf('Song', 'Song - Sped Up'), TrackVersion.spedUp);
      expect(normalizer.versionOf('Song', 'Song Slowed'), TrackVersion.slowed);
      expect(normalizer.versionOf('Song', 'Song (Instrumental)'),
          TrackVersion.instrumental);
    });
  });

  group('PlaybackResolver', () {
    test('YouTube is playable via official IFrame when eligible', () {
      final r = resolver.resolve(eligibleProviderIds: ['youtube']);
      expect(r.playable, isTrue);
      expect(r.source, 'youtube_iframe');
    });

    test('no eligible provider -> unavailable (never invents a source)', () {
      final r = resolver.resolve(eligibleProviderIds: []);
      expect(r.playable, isFalse);
      expect(r.reason, 'Playback unavailable');
    });

    test('region-blocked -> unavailable', () {
      final r = resolver.resolve(
        eligibleProviderIds: ['youtube'],
        regionAllowed: false,
      );
      expect(r.playable, isFalse);
    });

    test('auth-required provider without auth -> not playable, clear reason',
        () {
      final r = resolver.resolve(
        eligibleProviderIds: ['spotify'],
        userAuthenticated: false,
      );
      expect(r.playable, isFalse);
      expect(r.reason.toLowerCase(), contains('sign in'));
    });

    test('own licensed catalog is the top-priority source', () {
      final r = resolver.resolve(
        eligibleProviderIds: ['youtube', 'vshots_licensed'],
        userAuthenticated: true,
      );
      expect(r.playable, isTrue);
      expect(r.source, 'vshots_licensed_cdn');
    });
  });
}

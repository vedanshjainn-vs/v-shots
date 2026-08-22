import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/playback/playback_router.dart';
import 'package:v_shots/core/remote_config/remote_feature_flags.dart';

void main() {
  const permalink = 'https://www.jiosaavn.com/song/kesariya/RDPkZEVaUXw';

  PlaybackRouter router({bool jio = true, bool search = true}) =>
      PlaybackRouter(
        policy: PlaybackPolicy(
          jiosaavnWebPlayback: jio,
          jiosaavnSearchFallback: search,
        ),
      );

  Map<String, dynamic> track({
    String? id,
    String? youtubeId,
    String? jiosaavnUrl,
    String? playbackSource,
    String title = 'Kesariya',
    String artist = 'Arijit Singh',
    String? fallbackSource,
  }) =>
      {
        if (id != null) 'id': id,
        if (youtubeId != null) 'youtubeId': youtubeId,
        if (jiosaavnUrl != null) 'jiosaavnUrl': jiosaavnUrl,
        if (playbackSource != null) 'playbackSource': playbackSource,
        if (fallbackSource != null) 'fallbackSource': fallbackSource,
        'title': title,
        'artist': artist,
      };

  group('AUTO', () {
    test('exact JioSaavn URL wins when flag on', () async {
      final target = await router().resolvePlayback(
        track(jiosaavnUrl: permalink, youtubeId: 'dQw4w9WgXcQ'),
      );
      expect(target.isUnavailable, isFalse);
      expect(target.source, PlaybackSource.jiosaavn);
      expect(target.url, permalink);
    });

    test('YouTube id when no permalink', () async {
      final target = await router().resolvePlayback(track(id: 'dQw4w9WgXcQ'));
      expect(target.source, PlaybackSource.youtube);
      expect(target.url, contains('watch?v=dQw4w9WgXcQ'));
    });

    test('search fallback when enabled and no youtube id', () async {
      final target = await router(
        search: true,
      ).resolvePlayback(track(playbackSource: 'auto'));
      expect(target.source, PlaybackSource.jiosaavn);
      expect(target.url, contains('/search/songs/'));
    });

    test('unavailable when no sources', () async {
      final target = await router(
        jio: false,
        search: false,
      ).resolvePlayback(track(title: 'X'));
      expect(target.isUnavailable, isTrue);
    });
  });

  group('JIOSAAVN', () {
    test('flag off is unavailable', () async {
      final target = await router(jio: false).resolvePlayback(
        track(playbackSource: 'jiosaavn', jiosaavnUrl: permalink),
      );
      expect(target.isUnavailable, isTrue);
    });

    test('permalink', () async {
      final target = await router().resolvePlayback(
        track(playbackSource: 'jiosaavn', jiosaavnUrl: permalink),
      );
      expect(target.url, permalink);
    });

    test('missing url uses search when enabled', () async {
      final target = await router(
        search: true,
      ).resolvePlayback(track(playbackSource: 'jiosaavn'));
      expect(target.url, contains('/search/songs/'));
    });

    test('missing url is unavailable when search off', () async {
      final target = await router(
        search: false,
      ).resolvePlayback(track(playbackSource: 'jiosaavn'));
      expect(target.isUnavailable, isTrue);
    });
  });

  group('YOUTUBE', () {
    test('valid id', () async {
      final target = await router().resolvePlayback(
        track(playbackSource: 'youtube', id: 'dQw4w9WgXcQ'),
      );
      expect(target.source, PlaybackSource.youtube);
      expect(target.isUnavailable, isFalse);
    });

    test('missing id is unavailable', () async {
      final target = await router().resolvePlayback(
        track(playbackSource: 'youtube', title: 'Nope'),
      );
      expect(target.isUnavailable, isTrue);
    });
  });

  group('fallback recording', () {
    test('does not switch to YouTube before failure', () async {
      final target = await router().resolvePlayback(
        track(
          playbackSource: 'jiosaavn',
          jiosaavnUrl: permalink,
          youtubeId: 'dQw4w9WgXcQ',
          fallbackSource: 'youtube',
        ),
      );
      expect(target.source, PlaybackSource.jiosaavn);
      expect(target.url, permalink);
      expect(target.fallbackSource, PlaybackSource.youtube);
      expect(target.fallbackUrl, contains('dQw4w9WgXcQ'));
    });
  });

  group('feature flag off', () {
    test('AUTO ignores JioSaavn url and uses YouTube', () async {
      final target = await router(
        jio: false,
      ).resolvePlayback(track(jiosaavnUrl: permalink, id: 'dQw4w9WgXcQ'));
      expect(target.source, PlaybackSource.youtube);
      expect(target.url, contains('dQw4w9WgXcQ'));
    });
  });

  group('wired flags (PHASE 15)', () {
    test('enable_youtube_web_playback OFF + no JioSaavn → unavailable',
        () async {
      final target = await PlaybackRouter(
        policy: const PlaybackPolicy(
          jiosaavnWebPlayback: false,
          jiosaavnSearchFallback: false,
          youtubeWebPlayback: false,
        ),
      ).resolvePlayback(track(id: 'dQw4w9WgXcQ'));
      expect(target.isUnavailable, isTrue);
      expect(
          target.unavailableReason, contains('YouTube playback is turned off'));
    });

    test(
        'enable_youtube_web_playback OFF + jio permalink → JioSaavn still works',
        () async {
      final target = await PlaybackRouter(
        policy: const PlaybackPolicy(
          jiosaavnWebPlayback: true,
          jiosaavnSearchFallback: true,
          youtubeWebPlayback: false,
        ),
      ).resolvePlayback(
        track(jiosaavnUrl: permalink, id: 'dQw4w9WgXcQ'),
      );
      expect(target.source, PlaybackSource.jiosaavn);
      expect(target.url, permalink);
    });

    test('enable_jiosaavn_exact_urls OFF → permalink skipped, search used',
        () async {
      final target = await PlaybackRouter(
        policy: const PlaybackPolicy(
          jiosaavnWebPlayback: true,
          jiosaavnSearchFallback: true,
          jiosaavnExactUrls: false,
        ),
      ).resolvePlayback(
        track(
          jiosaavnUrl: permalink,
          title: 'Kesariya',
          artist: 'Arijit Singh',
        ),
      );
      expect(target.source, PlaybackSource.jiosaavn);
      expect(target.url, isNot(permalink));
      expect(target.url, contains('/search/songs/'));
    });

    test('enable_jiosaavn_exact_urls OFF + search OFF → unavailable', () async {
      final target = await PlaybackRouter(
        policy: const PlaybackPolicy(
          jiosaavnWebPlayback: true,
          jiosaavnSearchFallback: false,
          jiosaavnExactUrls: false,
        ),
      ).resolvePlayback(track(jiosaavnUrl: permalink));
      expect(target.isUnavailable, isTrue);
    });

    test('flags ON (defaults) → permalink honored', () async {
      final target = await PlaybackRouter(
        policy: const PlaybackPolicy(
          jiosaavnWebPlayback: true,
          jiosaavnSearchFallback: true,
        ),
      ).resolvePlayback(track(jiosaavnUrl: permalink, id: 'dQw4w9WgXcQ'));
      expect(target.source, PlaybackSource.jiosaavn);
      expect(target.url, permalink);
    });
  });
}

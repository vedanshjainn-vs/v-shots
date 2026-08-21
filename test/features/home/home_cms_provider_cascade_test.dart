// ─────────────────────────────────────────────────────────────────────────────
// V Shots — Home CMS provider cascade + PlaybackRouter provider paths
// (PHASE 10: Provider AUTO / YOUTUBE / JIOSAAVN, feature flags, no media
// extraction, no unofficial JioSaavn API)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/playback/playback_router.dart';
import 'package:v_shots/core/remote_config/remote_feature_flags.dart';
import 'package:v_shots/features/home/home_feed_service.dart';

const validPermalink = 'https://www.jiosaavn.com/song/tum-hi-ho/RTdzdkFmQWs';

List<Map<String, dynamic>> manualSection({
  String sectionProvider = 'auto',
  String sectionPlayback = 'auto',
  String sectionFallback = 'none',
  List<Map<String, dynamic>>? items,
}) =>
    [
      {
        'id': 'picks',
        'section_key': 'picks',
        'title': 'Picks',
        'source_type': 'manual',
        'visible': true,
        'published': true,
        'max_items': 10,
        'provider': sectionProvider,
        'playback_provider': sectionPlayback,
        'fallback_provider': sectionFallback,
      },
    ];

Map<String, dynamic> item({
  String provider = 'auto',
  String playback = 'auto',
  String fallback = 'none',
  String ytId = 'dQw4w9WgXcQ',
  String? jioUrl,
}) =>
    {
      'id': 'i1',
      'section_id': 'picks',
      'content_id': ytId,
      'youtube_video_id': ytId,
      'title': 'Song',
      'artist': 'Artist',
      'is_enabled': true,
      'provider': provider,
      'playback_provider': playback,
      'fallback_provider': fallback,
      if (jioUrl != null) 'jiosaavn_url': jioUrl,
    };

Map<String, dynamic> buildTrack({
  String sectionProvider = 'auto',
  String sectionPlayback = 'auto',
  String sectionFallback = 'none',
  Map<String, dynamic>? itemRow,
  bool jiosaavnEnabled = true,
}) {
  final shelves = HomeFeedService().buildShelfDescriptors(
    enableRemoteHome: true,
    jiosaavnEnabled: jiosaavnEnabled,
    jiosaavnSearchFallback: true,
    cmsSections: manualSection(
      sectionProvider: sectionProvider,
      sectionPlayback: sectionPlayback,
      sectionFallback: sectionFallback,
    ),
    cmsItems: {
      'picks': [itemRow ?? item()],
    },
  );
  final shelf = shelves.singleWhere((s) => s.id == 'picks');
  expect(shelf.kind, HomeShelfKind.manual);
  expect(shelf.manualItems, isNotEmpty);
  return shelf.manualItems.first;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home CMS provider cascade', () {
    test('item AUTO inherits section provider JIOSAAVN', () {
      final track = buildTrack(sectionProvider: 'jiosaavn');
      expect(track['provider'], 'jiosaavn');
      expect(track['playbackSource'], 'auto');
    });

    test('item AUTO inherits section playback JIOSAAVN', () {
      final track = buildTrack(
        sectionProvider: 'jiosaavn',
        sectionPlayback: 'jiosaavn',
      );
      expect(track['provider'], 'jiosaavn');
      expect(track['playbackSource'], 'jiosaavn');
    });

    test('explicit item provider YOUTUBE beats section JIOSAAVN', () {
      final track = buildTrack(
        sectionProvider: 'jiosaavn',
        sectionPlayback: 'jiosaavn',
        itemRow: item(provider: 'youtube', playback: 'youtube'),
      );
      expect(track['provider'], 'youtube');
      expect(track['playbackSource'], 'youtube');
    });

    test('JioSaavn flag OFF forces youtube routing even for jio items', () {
      final track = buildTrack(
        sectionProvider: 'jiosaavn',
        sectionPlayback: 'jiosaavn',
        itemRow: item(
          provider: 'jiosaavn',
          playback: 'jiosaavn',
          jioUrl: validPermalink,
        ),
        jiosaavnEnabled: false,
      );
      expect(track['playbackSource'], 'youtube');
      expect(track['provider'], 'youtube');
      expect(track.containsKey('jiosaavnUrl'), isFalse);
    });
  });

  group('PlaybackRouter provider paths', () {
    PlaybackRouter routerWith({bool jio = true, bool search = true}) =>
        PlaybackRouter(
          policy: PlaybackPolicy(
            jiosaavnWebPlayback: jio,
            jiosaavnSearchFallback: search,
          ),
        );

    test('Provider YOUTUBE → YouTube watch URL only', () async {
      final target = await routerWith().resolvePlayback({
        'playbackSource': 'youtube',
        'youtubeId': 'dQw4w9WgXcQ',
        'jiosaavnUrl': validPermalink,
      });
      expect(target.source, PlaybackSource.youtube);
      expect(target.url, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    });

    test('Provider JIOSAAVN + permalink → JioSaavn webpage', () async {
      final target = await routerWith().resolvePlayback({
        'playbackSource': 'jiosaavn',
        'youtubeId': 'dQw4w9WgXcQ',
        'jiosaavnUrl': validPermalink,
        'fallbackSource': 'youtube',
      });
      expect(target.source, PlaybackSource.jiosaavn);
      expect(target.url, validPermalink);
      expect(target.fallbackSource, PlaybackSource.youtube);
    });

    test('Provider JIOSAAVN + flag OFF → unavailable (never silent YouTube)',
        () async {
      final target = await routerWith(jio: false).resolvePlayback({
        'playbackSource': 'jiosaavn',
        'youtubeId': 'dQw4w9WgXcQ',
        'jiosaavnUrl': validPermalink,
      });
      expect(target.isUnavailable, isTrue);
      expect(target.unavailableReason, contains('turned off'));
    });

    test('Provider AUTO + jio permalink + flag ON → JioSaavn first', () async {
      final target = await routerWith().resolvePlayback({
        'playbackSource': 'auto',
        'youtubeId': 'dQw4w9WgXcQ',
        'jiosaavnUrl': validPermalink,
      });
      expect(target.source, PlaybackSource.jiosaavn);
      expect(target.url, validPermalink);
    });

    test('Provider AUTO + no permalink → YouTube', () async {
      final target = await routerWith().resolvePlayback({
        'playbackSource': 'auto',
        'youtubeId': 'dQw4w9WgXcQ',
      });
      expect(target.source, PlaybackSource.youtube);
    });

    test('Provider AUTO + no YouTube + search fallback ON → JioSaavn search',
        () async {
      final target = await routerWith().resolvePlayback({
        'playbackSource': 'auto',
        'title': 'Tum Hi Ho',
        'artist': 'Arijit Singh',
      });
      expect(target.source, PlaybackSource.jiosaavn);
      expect(target.url, contains('jiosaavn.com/search/'));
    });

    test('never resolves to a media/stream URL (no extraction)', () async {
      final router = routerWith();
      final tracks = <Map<String, dynamic>>[
        {
          'playbackSource': 'auto',
          'youtubeId': 'dQw4w9WgXcQ',
          'jiosaavnUrl': 'https://cdn.example.com/song.m3u8',
        },
        {
          'playbackSource': 'jiosaavn',
          'youtubeId': 'dQw4w9WgXcQ',
          'jiosaavnUrl':
              'https://www.jiosaavn.com/api.php?__call=song.getDetails',
        },
        {
          'playbackSource': 'auto',
          'url': 'https://stream.example.com/a.mp3',
          'title': 'X',
        },
      ];
      for (final track in tracks) {
        final target = await router.resolvePlayback(track);
        if (!target.isUnavailable) {
          expect(
            target.url.contains('.mp3') ||
                target.url.contains('.m3u8') ||
                target.url.contains('.m4a') ||
                target.url.contains('/api.php'),
            isFalse,
            reason: 'resolved a media/API URL: ${target.url}',
          );
          expect(
            target.url.startsWith('https://www.youtube.com/watch') ||
                target.url.contains('jiosaavn.com/'),
            isTrue,
            reason: 'unexpected URL: ${target.url}',
          );
        }
      }
    });
  });

  group('RemoteFeatureFlags', () {
    test('safe defaults keep JioSaavn OFF', () {
      RemoteFeatureFlags.instance.debugOverride(null);
      expect(RemoteFeatureFlags.instance.enableJioSaavnWebPlayback, isFalse);
      expect(RemoteFeatureFlags.instance.enableRemoteHome, isTrue);
    });

    test('override turns JioSaavn ON', () {
      RemoteFeatureFlags.instance.debugOverride({
        'enable_jiosaavn_web_playback': true,
        'enable_remote_home': true,
      });
      expect(RemoteFeatureFlags.instance.enableJioSaavnWebPlayback, isTrue);
      RemoteFeatureFlags.instance.debugOverride(null);
    });
  });
}

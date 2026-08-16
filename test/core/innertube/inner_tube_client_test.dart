// ═════════════════════════════════════════════════════════════════════════════
// V Shots — InnerTube client parsing tests
//
// Uses http's MockClient with a realistic InnerTube JSON fixture so parsing
// (videoRenderer, lockupViewModel, continuation tokens, duration/view-count)
// is verified deterministically without any network access.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:v_shots/core/innertube/inner_tube_client.dart';

const _searchFixture = '''
{
  "contents": {
    "twoColumnSearchResultsRenderer": {
      "primaryContents": {
        "sectionListRenderer": {
          "contents": [
            {
              "itemSectionRenderer": {
                "contents": [
                  {
                    "videoRenderer": {
                      "videoId": "O5gwxm3NxFU",
                      "title": {"runs": [{"text": "Best Of Arijit Singh 2024"}]},
                      "ownerText": {"runs": [{"text": "ABT Lofi Music"}]},
                      "lengthText": {"simpleText": "4:32"},
                      "viewCountText": {"simpleText": "66,544,320 views"},
                      "thumbnail": {"thumbnails": [{"url": "https://i.ytimg.com/vi/O5gwxm3NxFU/hq720.jpg"}]}
                    }
                  },
                  {
                    "videoRenderer": {
                      "videoId": "jRIc-a9Vp4g",
                      "title": {"runs": [{"text": "Arijit Singh - Tum Hi Ho (Official Video)"}]},
                      "ownerText": {"runs": [{"text": "Soulful Zeeshu"}]},
                      "lengthText": {"simpleText": "1:00:52"},
                      "viewCountText": {"simpleText": "5.7M views"},
                      "thumbnail": {"thumbnails": [{"url": "https://i.ytimg.com/vi/jRIc-a9Vp4g/hqdefault.jpg"}]}
                    }
                  },
                  {
                    "continuationItemRenderer": {
                      "continuationEndpoint": {
                        "continuationCommand": {"token": "CONTINUATION_TOKEN_123"}
                      }
                    }
                  }
                ]
              }
            }
          ]
        }
      }
    }
  }
}
''';

const _relatedFixture = '''
{
  "contents": {
    "twoColumnWatchNextResults": {
      "secondaryResults": {
        "secondaryResults": {
          "results": [
            {
              "lockupViewModel": {
                "contentId": "jRIc-a9Vp4g",
                "contentType": "LOCKUP_CONTENT_TYPE_VIDEO",
                "contentImage": {
                  "thumbnailViewModel": {
                    "image": {"sources": [{"url": "https://i.ytimg.com/vi/jRIc-a9Vp4g/hqdefault.jpg"}]}
                  }
                },
                "metadata": {
                  "lockupMetadataViewModel": {
                    "title": {"content": "Arijit Singh - Tum Hi Ho"},
                    "metadata": {
                      "contentMetadataViewModel": {
                        "metadataRows": [
                          {"metadataParts": [{"text": {"content": "Soulful Zeeshu"}}, {"text": {"content": "5.7M views"}}]}
                        ]
                      }
                    }
                  }
                }
              }
            }
          ]
        }
      }
    }
  }
}
''';

InnerTubeClient _clientReturning(String body) {
  final mock = MockClient((request) async {
    return http.Response(
      body,
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  // Fixed key/version bypass the (network) context-extraction step.
  return InnerTubeClient(
    httpClient: mock,
    apiKey: 'TEST_KEY',
    clientVersion: '2.20260813.05.00',
  );
}

const _officialFixture = '''
{
  "contents": {
    "twoColumnSearchResultsRenderer": {
      "primaryContents": {
        "sectionListRenderer": {
          "contents": [
            {
              "itemSectionRenderer": {
                "contents": [
                  {
                    "videoRenderer": {
                      "videoId": "officialVIDEO1",
                      "title": {"runs": [{"text": "Tum Hi Ho (Official Video)"}]},
                      "ownerText": {"runs": [{"text": "Arijit Singh"}]},
                      "lengthText": {"simpleText": "4:26"},
                      "viewCountText": {"simpleText": "1.2B views"},
                      "thumbnail": {"thumbnails": [{"url": "https://i.ytimg.com/vi/officialVIDEO1/hqdefault.jpg"}]},
                      "ownerBadges": [
                        {"metadataBadgeRenderer": {"style": "BADGE_STYLE_TYPE_VERIFIED_ARTIST"}}
                      ]
                    }
                  },
                  {
                    "videoRenderer": {
                      "videoId": "fanVIDEO999",
                      "title": {"runs": [{"text": "Tum Hi Ho Lyrics"}]},
                      "ownerText": {"runs": [{"text": "Lyrics Channel"}]},
                      "lengthText": {"simpleText": "4:26"},
                      "thumbnail": {"thumbnails": [{"url": "https://i.ytimg.com/vi/fanVIDEO999/hqdefault.jpg"}]}
                    }
                  }
                ]
              }
            }
          ]
        }
      }
    }
  }
}
''';

void main() {
  group('InnerTubeClient search', () {
    test(
      'parses videoRenderer items (id/title/channel/duration/viewCount)',
      () async {
        final client = _clientReturning(_searchFixture);
        final items = await client.search('arijit singh');

        expect(items, hasLength(2));
        expect(items.first.videoId, 'O5gwxm3NxFU');
        expect(items.first.title, 'Best Of Arijit Singh 2024');
        expect(items.first.channelName, 'ABT Lofi Music');
        expect(items.first.durationSeconds, 272); // 4:32
        expect(items.first.viewCount, 66544320);
        expect(
          items.first.thumbnailUrl,
          'https://i.ytimg.com/vi/O5gwxm3NxFU/hq720.jpg',
        );

        // 1:00:52 -> 3652s
        expect(items[1].durationSeconds, 3652);
        expect(items[1].viewCount, 5700000); // 5.7M
      },
    );

    test('detects official/verified creator badges', () async {
      final client = _clientReturning(_officialFixture);
      final items = await client.search('tum hi ho');

      expect(items, hasLength(2));
      final official = items.firstWhere((i) => i.videoId == 'officialVIDEO1');
      final fan = items.firstWhere((i) => i.videoId == 'fanVIDEO999');
      expect(
        official.isOfficial,
        isTrue,
        reason: 'OFFICIAL/VERIFIED badge must be detected',
      );
      expect(fan.isOfficial, isFalse);
    });

    test('searchPage surfaces the continuation token', () async {
      final client = _clientReturning(_searchFixture);
      final page = await client.searchPage('arijit singh');
      expect(page.items, hasLength(2));
      expect(page.continuationToken, 'CONTINUATION_TOKEN_123');
    });

    test('search excludes requested ids', () async {
      final client = _clientReturning(_searchFixture);
      final items = await client.search(
        'arijit singh',
        excludeIds: {'O5gwxm3NxFU'},
      );
      expect(items.map((i) => i.videoId), isNot(contains('O5gwxm3NxFU')));
    });

    test('related() parses lockupViewModel videos', () async {
      final client = _clientReturning(_relatedFixture);
      final items = await client.related('seedVideoId');

      expect(items, hasLength(1));
      expect(items.first.videoId, 'jRIc-a9Vp4g');
      expect(items.first.title, 'Arijit Singh - Tum Hi Ho');
      expect(items.first.channelName, 'Soulful Zeeshu');
      expect(items.first.thumbnailUrl, contains('hqdefault.jpg'));
    });

    test('returns empty gracefully on a non-200 response', () async {
      final mock = MockClient((request) async => http.Response('oops', 403));
      final client = InnerTubeClient(
        httpClient: mock,
        apiKey: 'TEST_KEY',
        clientVersion: 'x',
      );
      expect(await client.search('anything'), isEmpty);
    });
  });
}

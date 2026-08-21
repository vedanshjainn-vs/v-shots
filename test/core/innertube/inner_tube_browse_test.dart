// ═════════════════════════════════════════════════════════════════════════════
// V Shots — InnerTube browse parsing tests (PHASE 17)
// Deterministic fixtures for playlist (lockupViewModel), channel
// (videoRenderer grid) and trending responses — no network access.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:v_shots/core/innertube/inner_tube_client.dart';

const _playlistFixture = '''
{
  "contents": {
    "twoColumnBrowseResultsRenderer": {
      "tabs": [{
        "tabRenderer": {
          "title": "Playlist",
          "content": {
            "sectionListRenderer": {
              "contents": [
                {
                  "itemSectionRenderer": {
                    "contents": [
                      {
                        "lockupViewModel": {
                          "contentId": "PLVIDEO1",
                          "contentType": "LOCKUP_CONTENT_TYPE_VIDEO",
                          "metadata": {
                            "lockupMetadataViewModel": {
                              "title": {"content": "First Song"},
                              "metadata": {"rows": [{"metadataParts": [{"text": {"content": "Artist One"}}]}]}
                            }
                          }
                        }
                      },
                      {
                        "lockupViewModel": {
                          "contentId": "PLVIDEO2",
                          "contentType": "LOCKUP_CONTENT_TYPE_VIDEO",
                          "metadata": {
                            "lockupMetadataViewModel": {
                              "title": {"content": "Second Song"},
                              "metadata": {"rows": [{"metadataParts": [{"text": {"content": "Artist Two"}}]}]}
                            }
                          }
                        }
                      },
                      {"continuationItemViewModel": {"continuation": "next-page-token"}}
                    ]
                  }
                }
              ]
            }
          }
        }
      }]
    }
  }
}
''';

const _channelFixture = '''
{
  "contents": {
    "twoColumnBrowseResultsRenderer": {
      "tabs": [{
        "tabRenderer": {
          "title": "Videos",
          "content": {
            "sectionListRenderer": {
              "contents": [{
                "itemSectionRenderer": {
                  "contents": [{
                    "richItemRenderer": {
                      "content": {
                        "videoRenderer": {
                          "videoId": "CHVIDEO1",
                          "title": {"runs": [{"text": "Channel Upload"}]},
                          "ownerText": {"runs": [{"text": "The Channel"}]},
                          "lengthText": {"simpleText": "10:00"}
                        }
                      }
                    }
                  }]
                }
              }]
            }
          }
        }
      }]
    }
  }
}
''';

void main() {
  group('InnerTube browse parsing', () {
    test('playlistVideos parses lockupViewModel items in playlist order',
        () async {
      final client = InnerTubeClient(
        apiKey: 'k',
        clientVersion: 'v',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/youtubei/v1/browse');
          expect(request.body, contains('VLPLabc123'));
          return http.Response(_playlistFixture, 200);
        }),
      );
      final items = await client.playlistVideos('PLabc123', limit: 10);
      expect(items.length, 2);
      expect(items[0].videoId, 'PLVIDEO1');
      expect(items[0].title, 'First Song');
      expect(items[1].videoId, 'PLVIDEO2');
      expect(items[1].title, 'Second Song');
      // playlist order preserved
      expect(items.map((i) => i.videoId).toList(), ['PLVIDEO1', 'PLVIDEO2']);
    });

    test('channelVideos parses classic videoRenderer grid', () async {
      final client = InnerTubeClient(
        apiKey: 'k',
        clientVersion: 'v',
        httpClient: MockClient((request) async {
          expect(request.body, contains('UCchannel123'));
          return http.Response(_channelFixture, 200);
        }),
      );
      final items = await client.channelVideos('UCchannel123', limit: 10);
      expect(items.length, 1);
      expect(items.first.videoId, 'CHVIDEO1');
      expect(items.first.channelName, 'The Channel');
    });

    test('trending builds regional context (gl override)', () async {
      String? sentGl;
      final client = InnerTubeClient(
        apiKey: 'k',
        clientVersion: 'v',
        gl: 'IN',
        httpClient: MockClient((request) async {
          sentGl =
              RegExp(r'"gl":"([A-Z]{2})"').firstMatch(request.body)?.group(1);
          return http.Response('{"contents": {}}', 200);
        }),
      );
      await client.trending(region: 'US', limit: 5);
      expect(sentGl, 'US');
    });

    test('playlist with only unavailable entries returns empty list', () async {
      final client = InnerTubeClient(
        apiKey: 'k',
        clientVersion: 'v',
        httpClient: MockClient(
          (request) async => http.Response('{"contents": {"alerts": []}}', 200),
        ),
      );
      expect(await client.playlistVideos('PLempty', limit: 10), isEmpty);
    });

    test('rejects empty playlist id without a request', () async {
      var requested = false;
      final client = InnerTubeClient(
        apiKey: 'k',
        clientVersion: 'v',
        httpClient: MockClient((request) async {
          requested = true;
          return http.Response('{}', 200);
        }),
      );
      expect(await client.playlistVideos('  ', limit: 10), isEmpty);
      expect(requested, isFalse);
    });
  });
}

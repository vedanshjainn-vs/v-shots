// ═════════════════════════════════════════════════════════════════════════════
// V Shots — YouTube URL normalization tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/shared/utils/youtube_url.dart';

void main() {
  group('extractYoutubeVideoId', () {
    test('handles www.youtube.com/watch?v= with extra params', () {
      expect(
        extractYoutubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        extractYoutubeVideoId(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30s&list=PLx',
        ),
        'dQw4w9WgXcQ',
      );
    });

    test('handles bare / m. / plain youtube.com', () {
      expect(
        extractYoutubeVideoId('https://youtube.com/watch?v=abcDEF12345'),
        'abcDEF12345',
      );
      expect(
        extractYoutubeVideoId('https://m.youtube.com/watch?v=abcDEF12345'),
        'abcDEF12345',
      );
    });

    test('handles youtu.be short links', () {
      expect(
        extractYoutubeVideoId('https://youtu.be/abcDEF12345'),
        'abcDEF12345',
      );
    });

    test('handles /shorts, /embed, /live, /v', () {
      expect(
        extractYoutubeVideoId('https://www.youtube.com/shorts/abcDEF12345'),
        'abcDEF12345',
      );
      expect(
        extractYoutubeVideoId('https://www.youtube.com/embed/abcDEF12345'),
        'abcDEF12345',
      );
      expect(
        extractYoutubeVideoId('https://www.youtube.com/live/abcDEF12345'),
        'abcDEF12345',
      );
      expect(
        extractYoutubeVideoId('https://www.youtube.com/v/abcDEF12345'),
        'abcDEF12345',
      );
    });

    test('accepts a bare video id', () {
      expect(extractYoutubeVideoId('abcDEF12345'), 'abcDEF12345');
    });

    test('rejects non-YouTube hosts and malformed urls', () {
      expect(extractYoutubeVideoId('https://example.com/watch?v=x'), isNull);
      expect(extractYoutubeVideoId('not a url'), isNull);
      expect(extractYoutubeVideoId(''), isNull);
      expect(extractYoutubeVideoId('https://www.youtube.com/'), isNull);
      expect(extractYoutubeVideoId('https://youtu.be/short'), isNull);
    });
  });

  group('youtubeWatchUrl / isSupportedYoutubeUrl', () {
    test('builds the canonical watch URL', () {
      expect(
        youtubeWatchUrl('abcDEF12345'),
        'https://www.youtube.com/watch?v=abcDEF12345',
      );
    });

    test('isSupportedYoutubeUrl mirrors extract', () {
      expect(isSupportedYoutubeUrl('https://youtu.be/abcDEF12345'), isTrue);
      expect(isSupportedYoutubeUrl('https://example.com/x'), isFalse);
    });
  });

  group('playlist / channel ids', () {
    test('extracts playlist ids from URLs and bare tokens', () {
      expect(
        extractYoutubePlaylistId('PLrAXtmRdnEQy6nuLMOVlkwJZKj9X8nK8x'),
        'PLrAXtmRdnEQy6nuLMOVlkwJZKj9X8nK8x',
      );
      expect(
        extractYoutubePlaylistId(
          'https://www.youtube.com/playlist?list=PLrAXtmRdnEQy6nuLMOVlkwJZKj9X8nK8x',
        ),
        'PLrAXtmRdnEQy6nuLMOVlkwJZKj9X8nK8x',
      );
      expect(extractYoutubePlaylistId('latest punjabi songs'), isNull);
    });

    test('extracts channel ids from URLs and bare tokens', () {
      expect(
        extractYoutubeChannelId('UCuAXFkgsw1L7xaCfnd5JJOw'),
        'UCuAXFkgsw1L7xaCfnd5JJOw',
      );
      expect(
        extractYoutubeChannelId(
          'https://www.youtube.com/channel/UCuAXFkgsw1L7xaCfnd5JJOw',
        ),
        'UCuAXFkgsw1L7xaCfnd5JJOw',
      );
      expect(extractYoutubeChannelId('@ArijitSingh'), isNull);
    });
  });
}

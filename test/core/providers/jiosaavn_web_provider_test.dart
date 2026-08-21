import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/providers/jiosaavn_web_provider.dart';

void main() {
  const permalink = 'https://www.jiosaavn.com/song/kesariya/RDPkZEVaUXw';

  group('JioSaavn URL validation', () {
    test('valid permalink', () {
      expect(JioSaavnWebProvider.isValidPermalink(permalink), isTrue);
      expect(JioSaavnWebProvider.isValidJioSaavnUrl(permalink), isTrue);
    });

    test('rejects http', () {
      expect(
        JioSaavnWebProvider.isValidJioSaavnUrl(
          'http://www.jiosaavn.com/song/kesariya/RDPkZEVaUXw',
        ),
        isFalse,
      );
    });

    test('rejects invalid domain', () {
      expect(
        JioSaavnWebProvider.isValidJioSaavnUrl(
          'https://evil.example.com/song/kesariya/abc',
        ),
        isFalse,
      );
    });

    test('rejects api endpoint', () {
      expect(
        JioSaavnWebProvider.isValidJioSaavnUrl(
          'https://api.jiosaavn.com/song/kesariya/abc',
        ),
        isFalse,
      );
    });

    test('rejects mp3', () {
      expect(
        JioSaavnWebProvider.isValidJioSaavnUrl(
          'https://www.jiosaavn.com/song/x/abc.mp3',
        ),
        isFalse,
      );
    });

    test('rejects m3u8', () {
      expect(
        JioSaavnWebProvider.isValidJioSaavnUrl(
          'https://www.jiosaavn.com/media/x.m3u8',
        ),
        isFalse,
      );
    });

    test('rejects javascript and data urls', () {
      expect(
        JioSaavnWebProvider.isValidJioSaavnUrl('javascript:alert(1)'),
        isFalse,
      );
      expect(
        JioSaavnWebProvider.isValidJioSaavnUrl('data:text/html,hi'),
        isFalse,
      );
    });

    test('search url is allowed as a page, not a permalink', () {
      const search = 'https://www.jiosaavn.com/search/songs/Kesariya';
      expect(JioSaavnWebProvider.isValidSearchUrl(search), isTrue);
      expect(JioSaavnWebProvider.isValidPermalink(search), isFalse);
      expect(JioSaavnWebProvider.isValidJioSaavnUrl(search), isTrue);
    });
  });

  group('resolveWebUrl', () {
    test('returns permalink when valid', () async {
      final url = await JioSaavnWebProvider.instance.resolveWebUrl(
        title: 'Kesariya',
        artist: 'Arijit Singh',
        permalink: permalink,
      );
      expect(url, permalink);
    });

    test('search fallback when enabled and permalink missing', () async {
      final url = await JioSaavnWebProvider.instance.resolveWebUrl(
        title: 'Kesariya',
        artist: 'Arijit Singh',
        allowSearchFallback: true,
      );
      expect(url, contains('https://www.jiosaavn.com/search/songs/'));
      expect(url, contains(Uri.encodeComponent('Kesariya')));
    });

    test('no search fallback when disabled', () async {
      final url = await JioSaavnWebProvider.instance.resolveWebUrl(
        title: 'Kesariya',
        artist: 'Arijit Singh',
        allowSearchFallback: false,
      );
      expect(url, isNull);
    });
  });
}

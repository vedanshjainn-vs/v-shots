// ═════════════════════════════════════════════════════════════════════════════
// V Shots — VShotsBrowserSession host-policy tests (pure)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/features/foryou/vshots_browser_session.dart';

void main() {
  group('isAllowedBrowserHost', () {
    test('allows YouTube + Google infrastructure hosts', () {
      expect(isAllowedBrowserHost('www.youtube.com'), isTrue);
      expect(isAllowedBrowserHost('m.youtube.com'), isTrue);
      expect(isAllowedBrowserHost('youtu.be'), isTrue);
      expect(isAllowedBrowserHost('googlevideo.com'), isTrue);
      expect(isAllowedBrowserHost('i.ytimg.com'), isTrue);
      expect(isAllowedBrowserHost('accounts.google.com'), isTrue);
    });

    test('blocks arbitrary external hosts', () {
      expect(isAllowedBrowserHost('evil.example.com'), isFalse);
      expect(isAllowedBrowserHost('example.com'), isFalse);
      expect(
        isAllowedBrowserHost('youtube.com.evil.com'),
        isFalse,
        reason: 'suffix trick must not pass',
      );
      expect(isAllowedBrowserHost(''), isFalse);
    });

    test('is case-insensitive', () {
      expect(isAllowedBrowserHost('WWW.YOUTUBE.COM'), isTrue);
    });

    test('allows official JioSaavn page hosts', () {
      expect(isAllowedBrowserHost('www.jiosaavn.com'), isTrue);
      expect(isAllowedBrowserHost('jiosaavn.com'), isTrue);
      expect(isAllowedBrowserHost('static.saavncdn.com'), isTrue);
    });

    test('rejects JioSaavn API and third-party wrappers', () {
      expect(isAllowedBrowserHost('api.jiosaavn.com'), isFalse);
      expect(isAllowedBrowserHost('saavn.me'), isFalse);
    });
  });
}

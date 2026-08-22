// ═════════════════════════════════════════════════════════════════════════════
// V Shots — VShotsBrowserSession host-policy tests (pure)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/features/foryou/vshots_browser_session.dart';

void main() {
  group('VShotsBrowserSession native events', () {
    test('adState(true/false) reaches the onAdState callback', () async {
      final adEvents = <bool>[];
      final session = VShotsBrowserSession(
        onPageStarted: () {},
        onPageFinished: () {},
        onError: (_) {},
        onAdState: adEvents.add,
      );
      await session.debugHandleNativeEvent(const MethodCall('adState', true));
      await session.debugHandleNativeEvent(const MethodCall('adState', false));
      expect(adEvents, [true, false]);
      session.dispose();
    });

    test('no onAdState callback → adState event is ignored safely', () async {
      final session = VShotsBrowserSession(
        onPageStarted: () {},
        onPageFinished: () {},
        onError: (_) {},
      );
      await session.debugHandleNativeEvent(const MethodCall('adState', true));
      session.dispose();
    });

    test('videoEnded event (early auto-advance path) forwards the id',
        () async {
      String? endedId;
      final session = VShotsBrowserSession(
        onPageStarted: () {},
        onPageFinished: () {},
        onError: (_) {},
        onVideoEnded: (id) => endedId = id,
      );
      // The session extracts the id from the LAST LOADED url — set one via
      // the load path would need a platform channel, so simulate by sending
      // the event without a loaded url: id resolves to '' and the callback
      // still fires (the SHEET falls back to the current track id).
      await session.debugHandleNativeEvent(const MethodCall('videoEnded'));
      expect(endedId, '');
      session.dispose();
    });
  });

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

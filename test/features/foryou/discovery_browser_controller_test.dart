// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Discovery browser controller tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/features/foryou/discovery_browser_controller.dart';

Map<String, dynamic> _track(String id) => {
  'id': id,
  'title': 'Title $id',
  'artist': 'Artist',
  'artwork': 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
  'duration': 200,
};

void main() {
  group('DiscoveryBrowserController', () {
    test('open sets open + collapsed + loading and canonical url', () {
      final c = DiscoveryBrowserController();
      expect(c.isOpen, isFalse);

      c.open(_track('abcDEF12345'));
      expect(c.isOpen, isTrue);
      expect(c.isExpanded, isFalse);
      expect(c.isLoading, isTrue);
      expect(c.videoId, 'abcDEF12345');
      expect(c.url, 'https://www.youtube.com/watch?v=abcDEF12345');
      expect(c.error, isNull);
    });

    test('opening another track reuses the single session', () {
      final c = DiscoveryBrowserController();
      c.open(_track('aaa11122233'));
      c.open(_track('bbb44455566'));
      expect(c.isOpen, isTrue);
      expect(c.videoId, 'bbb44455566');
      expect(c.url, 'https://www.youtube.com/watch?v=bbb44455566');
    });

    test('close clears state and url', () {
      final c = DiscoveryBrowserController();
      c.open(_track('abcDEF12345'));
      c.close();
      expect(c.isOpen, isFalse);
      expect(c.isExpanded, isFalse);
      expect(c.url, isNull);
      expect(c.track, isNull);
    });

    test('expand/minimize toggle expansion', () {
      final c = DiscoveryBrowserController();
      c.open(_track('abcDEF12345'));
      c.expand();
      expect(c.isExpanded, isTrue);
      c.minimize();
      expect(c.isExpanded, isFalse);
    });

    test('loading/error/pagePlaying transitions notify', () {
      final c = DiscoveryBrowserController();
      var notified = 0;
      c.addListener(() => notified++);

      c.setLoading(true);
      c.setError('boom');
      c.setPagePlaying(true);
      expect(notified, 3);
      expect(c.isLoading, isTrue);
      expect(c.error, 'boom');
      expect(c.pagePlaying, isTrue);
    });

    test('track without an id has no url', () {
      final c = DiscoveryBrowserController();
      c.open({'title': 'No id', 'artist': 'X'});
      expect(c.isOpen, isTrue);
      expect(c.url, isNull);
    });
  });

  group('BrowserState machine', () {
    test('CLOSED -> COLLAPSED -> EXPANDED -> COLLAPSED -> CLOSED', () {
      final c = DiscoveryBrowserController();
      expect(c.state, BrowserState.closed);

      c.open(_track('abcDEF12345'));
      expect(
        c.state,
        BrowserState.collapsed,
        reason: 'open() must land in the collapsed state',
      );

      c.expand();
      expect(c.state, BrowserState.expanded);

      c.minimize();
      expect(
        c.state,
        BrowserState.collapsed,
        reason: 'minimize must NOT close — just collapse',
      );

      c.close();
      expect(c.state, BrowserState.closed);
    });

    test('state never claims expanded while closed', () {
      final c = DiscoveryBrowserController();
      c.open(_track('abcDEF12345'));
      c.expand();
      c.close();
      expect(c.state, BrowserState.closed);
      expect(c.isExpanded, isFalse);
    });

    test(
      'collapse (minimize) keeps isOpen true and preserves the track/url',
      () {
        final c = DiscoveryBrowserController();
        c.open(_track('abcDEF12345'));
        final urlBefore = c.url;
        c.expand();
        c.minimize();
        expect(c.isOpen, isTrue);
        expect(
          c.url,
          urlBefore,
          reason: 'collapsing must not reset or reload the URL',
        );
      },
    );
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// V Shots — VShotsPlaybackManager tests (global playback source of truth)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/playback/vshots_playback_manager.dart';

Map<String, dynamic> _track(String id) => {
      'id': id,
      'title': 'T $id',
      'artist': 'A',
      'artwork': 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      'duration': 200,
    };

void main() {
  test('play() opens the single global session with the track', () {
    final m = VShotsPlaybackManager.instance;
    m.play(_track('vid1'));
    expect(m.isOpen, isTrue);
    expect(m.currentTrack?['id'], 'vid1');
    expect(m.browser.url, 'https://www.youtube.com/watch?v=vid1');
    expect(m.currentIndex, 0);
    m.close();
  });

  test('playQueue() keeps a queue and next()/previous() cycle through it', () {
    final m = VShotsPlaybackManager.instance;
    final tracks = [_track('a'), _track('b'), _track('c')];
    m.playQueue(tracks, 1);
    expect(m.currentTrack?['id'], 'b');
    expect(m.queue.length, 3);

    final sameBrowser = m.browser;
    m.next();
    expect(m.currentTrack?['id'], 'c');
    expect(m.browser, sameBrowser,
        reason: 'next() must reuse the SAME browser session, never a new one');
    expect(m.isOpen, isTrue);

    m.next();
    expect(m.currentTrack?['id'], 'a', reason: 'queue must wrap');

    m.previous();
    expect(m.currentTrack?['id'], 'c');
    m.close();
  });

  test('close() clears the session and the queue', () {
    final m = VShotsPlaybackManager.instance;
    m.playQueue([_track('x'), _track('y')], 0);
    expect(m.isOpen, isTrue);

    m.close();
    expect(m.isOpen, isFalse);
    expect(m.currentTrack, isNull);
    expect(m.queue, isEmpty);
  });

  test('replaying the same video reuses the session', () {
    final m = VShotsPlaybackManager.instance;
    m.play(_track('vid1'));
    final firstBrowser = m.browser;
    m.play(_track('vid1'));
    expect(m.browser, firstBrowser);
    expect(m.currentTrack?['id'], 'vid1');
    m.close();
  });

  test('next()/previous() are no-ops without a queue', () {
    final m = VShotsPlaybackManager.instance;
    m.close();
    m.next();
    m.previous();
    expect(m.isOpen, isFalse);
  });
}

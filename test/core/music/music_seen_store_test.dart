// ═════════════════════════════════════════════════════════════════════════════
// V Shots — MusicSeenStore decaying penalty tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/recommendation/music_seen_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MusicSeenStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = MusicSeenStore();
    await store.initialize();
  });

  test('record / hasSeen / timesSeen', () async {
    expect(store.hasSeen('song-1'), isFalse);
    await store.record('song-1');
    expect(store.hasSeen('song-1'), isTrue);
    expect(store.timesSeen('song-1'), 1);
    await store.record('song-1');
    expect(store.timesSeen('song-1'), 2);
  });

  test('unseen songs have zero penalty', () {
    expect(store.penalty('never-seen'), 0);
  });

  test('penalty decays with age and never permanently hides', () {
    final now = DateTime(2026, 8, 17, 12);

    store.debugSetLastSeen('song-1', now); // just played
    expect(store.penalty('song-1', now: now), 1.0);

    store.debugSetLastSeen('song-2', now.subtract(const Duration(days: 1)));
    expect(store.penalty('song-2', now: now), closeTo(0.5, 0.01));

    store.debugSetLastSeen('song-3', now.subtract(const Duration(days: 3)));
    expect(store.penalty('song-3', now: now), closeTo(0.125, 0.01));

    store.debugSetLastSeen('song-4', now.subtract(const Duration(days: 7)));
    expect(
      store.penalty('song-4', now: now),
      lessThan(0.05),
      reason: 'a song seen 7 days ago is nearly free',
    );
  });
}

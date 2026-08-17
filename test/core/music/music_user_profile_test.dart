// ═════════════════════════════════════════════════════════════════════════════
// V Shots — MusicUserProfileBuilder tests (language/mood affinities, skips)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/recommendation/music_user_profile_builder.dart';
import 'package:v_shots/core/recommendation/signal_event.dart';
import 'package:v_shots/core/recommendation/signal_store.dart';
import 'package:v_shots/core/storage/local_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SignalStore.instance.initialize();
    await SignalStore.instance.clear();
    await LocalLibrary.instance.initialize();
    await LocalLibrary.instance.clearRecentlyPlayed();
  });

  test('empty signals → empty profile (cold start)', () {
    final profile = MusicUserProfileBuilder().build();
    expect(profile.isEmpty, isTrue);
  });

  test('completed plays build language + mood affinity', () async {
    final now = DateTime.now();
    for (var i = 0; i < 3; i++) {
      await SignalStore.instance.record(
        SignalEvent(
          type: SignalType.completed,
          timestamp: now.subtract(Duration(minutes: i)),
          trackId: 'r$i',
          artist: 'Arijit Singh',
          title: 'Romantic Hindi Song $i',
        ),
      );
    }
    final profile = MusicUserProfileBuilder().build();
    expect(profile.languageAffinity['hindi'], greaterThan(0));
    expect(profile.moodAffinity['romantic'], greaterThan(0));
    expect(profile.artistAffinity, contains('Arijit Singh'));
  });

  test('immediate skips produce an artist skip penalty (decaying)', () async {
    await SignalStore.instance.record(
      SignalEvent(
        type: SignalType.skip,
        timestamp: DateTime.now(),
        trackId: 's1',
        artist: 'SkipArtist',
        title: 'Meh Song',
        value: 5, // immediate skip
      ),
    );
    final profile = MusicUserProfileBuilder().build();
    expect(profile.artistSkipPenalty['SkipArtist'], greaterThan(0));
  });
}

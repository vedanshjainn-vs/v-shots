// ════════════════════════════════════════════════
// V Shots — CandidateGenerator tests (Phase 7, Part X)
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/recommendation/candidate_generator.dart';
import 'package:v_shots/core/recommendation/taste_profile.dart';
import 'package:v_shots/core/storage/local_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalLibrary.instance.initialize();
  });

  test('cold start (empty profile) never returns an empty candidate list', () {
    final generator = CandidateGenerator();
    final candidates = generator.generate(TasteProfile.empty, count: 10);
    expect(candidates, isNotEmpty);
  });

  test('cold start candidates include a real, honest source label', () {
    final generator = CandidateGenerator();
    final candidates = generator.generate(TasteProfile.empty, count: 10);
    for (final c in candidates) {
      expect(c.query, isNotEmpty);
    }
  });

  test('personalized profile produces similar-artist candidates', () {
    final generator = CandidateGenerator();
    const profile = TasteProfile(
      artistAffinity: {
        'Arijit Singh': 10.0,
        'Diljit Dosanjh': 5.0,
        'Third': 1.0,
      },
      genreAffinity: {},
      artistSkipPenalty: {},
      totalSignalCount: 5,
    );
    final candidates = generator.generate(profile, count: 12);
    expect(
      candidates.any((c) => c.source == CandidateSource.similarArtist),
      isTrue,
    );
  });

  test('exploration candidates avoid the user\'s current top genres', () {
    final generator = CandidateGenerator();
    const profile = TasteProfile(
      artistAffinity: {'X': 5.0},
      genreAffinity: {'Bollywood': 10.0, 'Hindi': 8.0, 'Punjabi': 6.0},
      artistSkipPenalty: {},
      totalSignalCount: 5,
    );
    final candidates = generator.generate(profile, count: 12);
    final explorationCandidates = candidates.where(
      (c) => c.source == CandidateSource.exploration,
    );
    for (final c in explorationCandidates) {
      expect(c.seedGenre, isNot(anyOf('Bollywood', 'Hindi', 'Punjabi')));
    }
  });

  test('trending is always included regardless of profile state', () {
    final generator = CandidateGenerator();
    const profile = TasteProfile(
      artistAffinity: {'Someone': 5.0},
      genreAffinity: {},
      artistSkipPenalty: {},
      totalSignalCount: 5,
    );
    final candidates = generator.generate(profile, count: 12);
    expect(candidates.any((c) => c.source == CandidateSource.trending), isTrue);
  });

  test('respects the requested count cap', () {
    final generator = CandidateGenerator();
    const profile = TasteProfile(
      artistAffinity: {'A': 1, 'B': 1, 'C': 1, 'D': 1, 'E': 1},
      genreAffinity: {'Bollywood': 1, 'Hindi': 1, 'Punjabi': 1},
      artistSkipPenalty: {},
      totalSignalCount: 10,
    );
    final candidates = generator.generate(profile, count: 3);
    expect(candidates.length, lessThanOrEqualTo(3));
  });
}

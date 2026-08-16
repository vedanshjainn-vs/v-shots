// ═════════════════════════════════════════════════════════════════════════════
// V Shots — PersonalizationStore tests
//
// Uses shared_preferences' mock helper (same pattern as LocalLibrary tests)
// to verify the onboarding preferences really persist and re-load.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/storage/personalization_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PersonalizationStore.instance.reset();
    await PersonalizationStore.instance.initialize();
  });

  test('starts un-onboarded with no preferences', () {
    expect(PersonalizationStore.instance.onboarded, isFalse);
    expect(PersonalizationStore.instance.hasPreferences, isFalse);
  });

  test('completeOnboarding persists languages and genres', () async {
    await PersonalizationStore.instance.completeOnboarding(
      languages: ['Hindi', 'Punjabi'],
      genres: ['Romantic', 'Punjabi'],
    );

    expect(PersonalizationStore.instance.onboarded, isTrue);
    expect(PersonalizationStore.instance.hasPreferences, isTrue);
    expect(
      PersonalizationStore.instance.preferredLanguages,
      containsAll(['Hindi', 'Punjabi']),
    );
    expect(
      PersonalizationStore.instance.preferredGenres,
      containsAll(['Romantic', 'Punjabi']),
    );
  });

  test('writes real values to the backing SharedPreferences', () async {
    await PersonalizationStore.instance.completeOnboarding(
      languages: ['English'],
      genres: ['Rock'],
    );

    // Verify at the storage layer (the singleton's initialize() reads these
    // same keys on the next app launch).
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('v_shots.onboarded.v1'), isTrue);
    expect(prefs.getString('v_shots.pref_languages.v1'), contains('English'));
    expect(prefs.getString('v_shots.pref_genres.v1'), contains('Rock'));
  });

  test('skipping onboarding (empty prefs) still marks onboarded', () async {
    await PersonalizationStore.instance.completeOnboarding();

    expect(PersonalizationStore.instance.onboarded, isTrue);
    expect(PersonalizationStore.instance.hasPreferences, isFalse);
  });
}

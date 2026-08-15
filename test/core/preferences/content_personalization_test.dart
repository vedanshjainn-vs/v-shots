// ═════════════════════════════════════════════════════════════════════════
// V Shots — Content Personalization Tests (Phase 21)
//
// Verifies:
//   - preference persistence round-trip
//   - India + Hindi filtering produces Hindi-language queries
//   - India + Punjabi produces Punjabi-language queries
//   - US + English produces English-language queries
//   - vibe queries are language-aware
//   - country defaults produce correct language sets
//   - cold-start queries blend preferences + trending
//   - effective languages fall back sensibly
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_shots/core/preferences/content_personalization_service.dart';
import 'package:v_shots/core/preferences/user_preferences.dart';

void main() {
  final svc = ContentPersonalizationService.instance;

  group('UserPreferences persistence', () {
    test('round-trips through local storage', () async {
      SharedPreferences.setMockInitialValues({});
      await PreferencesStore.instance.initialize();
      final prefs = UserPreferences(
        country: 'India',
        languages: ['Hindi', 'Punjabi'],
        genres: ['Bollywood', 'Punjabi'],
        vibes: ['Romantic'],
        onboardingCompleted: true,
      );
      await PreferencesStore.instance.save(prefs);
      final loaded = PreferencesStore.instance.preferences;
      expect(loaded.country, 'India');
      expect(loaded.languages, contains('Hindi'));
      expect(loaded.languages, contains('Punjabi'));
      expect(loaded.onboardingCompleted, isTrue);
    });
  });

  group('ContentPersonalizationService query building', () {
    test('India + Hindi produces Hindi-language queries', () {
      final p = UserPreferences(country: 'India', languages: ['Hindi']);
      final q = svc.buildQuery(p, categoryIntent: 'latest songs');
      expect(q.toLowerCase(), contains('hindi'));
      expect(q.toLowerCase(), contains('latest songs'));
    });

    test('India + Punjabi produces Punjabi-language queries', () {
      final p = UserPreferences(country: 'India', languages: ['Punjabi']);
      final q = svc.buildQuery(p, categoryIntent: 'hits');
      expect(q.toLowerCase(), contains('punjabi'));
    });

    test('US + English produces English-language queries', () {
      final p =
          UserPreferences(country: 'United States', languages: ['English']);
      final q = svc.buildQuery(p, categoryIntent: 'pop hits');
      expect(q.toLowerCase(), contains('english'));
      expect(q.toLowerCase(), contains('pop hits'));
    });

    test('vibe query is language-aware', () {
      final p = UserPreferences(country: 'India', languages: ['Hindi']);
      final q = svc.buildVibeQuery(p, 'Romantic');
      expect(q.toLowerCase(), contains('hindi'));
      // Romantic should include romance/love intent
      expect(q.toLowerCase(), anyOf(contains('romantic'), contains('love')));
    });

    test('effectiveLanguages uses explicit picks first', () {
      final p = UserPreferences(country: 'India', languages: ['English']);
      expect(svc.effectiveLanguages(p), ['English']);
    });

    test('effectiveLanguages falls back to country defaults', () {
      final p = UserPreferences(country: 'India');
      expect(svc.effectiveLanguages(p), contains('Hindi'));
      final pUS = UserPreferences(country: 'United States');
      expect(svc.effectiveLanguages(pUS), contains('English'));
    });

    test('cold-start queries blend preferences and trending', () {
      final p = UserPreferences(
        country: 'India',
        languages: ['Hindi', 'Punjabi'],
        genres: ['Bollywood'],
      );
      final queries = svc.coldStartQueries(p, count: 4);
      expect(queries, isNotEmpty);
      // At least one query is language/preference-driven.
      final joined = queries.join(' ').toLowerCase();
      expect(joined.contains('hindi') || joined.contains('punjabi'), isTrue);
    });
  });
}

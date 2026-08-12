// ═════════════════════════════════════════════════════════════════════════
// V Shots — LanguageCountryScorer Tests (Phases 4, 5, 6)
//
// Verifies confidence-based language/country scoring:
//   - obvious language markers (punjabi, korean) detect correctly
//   - unknown Latin-script content stays UNKNOWN (never forced to English)
//   - Hindi user rejects a strong Korean/Spanish mismatch
//   - country score is a real component
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/preferences/user_preferences.dart';
import 'package:v_shots/core/recommendation/language_country_scorer.dart';

void main() {
  final scorer = LanguageCountryScorer();

  group('language detection', () {
    test('detects obvious Punjabi marker', () {
      final r = scorer.detectLanguage('Punjabi New Song', 'Diljit');
      expect(r.language, 'Punjabi');
      expect(r.confidence, greaterThan(0.5));
    });

    test('detects obvious Korean marker', () {
      final r = scorer.detectLanguage('K-pop Song', 'Kpop');
      expect(r.language, 'Korean');
      expect(r.confidence, greaterThan(0.5));
    });

    test('unknown Latin-script content stays UNKNOWN', () {
      final r =
          scorer.detectLanguage('Some Random Instrumental', 'UnknownChannel');
      // No marker present — must NOT be forced to Hindi or English; unknown.
      expect(r.language.isEmpty, isTrue);
      expect(r.confidence, 0);
    });
  });

  group('language score vs preferences', () {
    test('Hindi user scores Punjabi higher than Korean', () {
      final prefs =
          UserPreferences(country: 'India', languages: ['Hindi', 'Punjabi']);
      final punjabi = scorer.languageScore(
          title: 'Punjabi Song', channel: 'Punjabi', prefs: prefs);
      final korean = scorer.languageScore(
          title: 'K-pop Song', channel: 'Kpop', prefs: prefs);
      expect(punjabi, greaterThan(korean));
    });

    test('unknown content gets neutral score, not 0 or 1', () {
      final prefs = UserPreferences(country: 'India', languages: ['Hindi']);
      final s = scorer.languageScore(
          title: 'Tum Hi Ho', channel: 'Singer', prefs: prefs);
      expect(s, inInclusiveRange(0.3, 0.6));
    });
  });

  group('strong language mismatch (Phase 6)', () {
    test('Hindi user rejects Korean candidate', () {
      final prefs = UserPreferences(country: 'India', languages: ['Hindi']);
      expect(
        scorer.isStrongLanguageMismatch(
            title: 'K-pop Song', channel: 'Kpop', prefs: prefs),
        isTrue,
      );
    });

    test('unknown content is not a mismatch (no false rejection)', () {
      final prefs = UserPreferences(country: 'India', languages: ['Hindi']);
      expect(
        scorer.isStrongLanguageMismatch(
            title: 'Tum Hi Ho', channel: 'Singer', prefs: prefs),
        isFalse,
      );
    });
  });

  group('country score', () {
    test('candidate in preferred country language scores higher', () {
      final prefs = UserPreferences(country: 'India', languages: ['Punjabi']);
      final inCountry = scorer.countryScore(
          title: 'Punjabi Song', channel: 'Punjabi', prefs: prefs);
      final outCountry = scorer.countryScore(
          title: 'K-pop Song', channel: 'Kpop', prefs: prefs);
      expect(inCountry, greaterThan(outCountry));
    });
  });
}

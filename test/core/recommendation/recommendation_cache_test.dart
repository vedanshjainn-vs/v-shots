// ════════════════════════════════════════════════
// V Shots — RecommendationCache tests (Phase 7, Part X)
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/recommendation/recommendation_cache.dart';
import 'package:v_shots/core/recommendation/taste_profile.dart';

void main() {
  setUp(() => RecommendationCache.instance.clear());

  test('setFeed then getFeed returns the same tracks', () {
    RecommendationCache.instance.setFeed('key1', const []);
    expect(RecommendationCache.instance.getFeed('key1'), isNotNull);
  });

  test('getFeed returns null for an unknown key', () {
    expect(RecommendationCache.instance.getFeed('never-set'), isNull);
  });

  test('isFeedFresh is true immediately after set', () {
    RecommendationCache.instance.setFeed('key2', const []);
    expect(RecommendationCache.instance.isFeedFresh('key2'), isTrue);
  });

  test('setCachedProfile then getCachedProfile round-trips', () {
    RecommendationCache.instance.setCachedProfile(TasteProfile.empty);
    expect(RecommendationCache.instance.getCachedProfile(), TasteProfile.empty);
  });

  test('invalidateProfile clears only the profile, not feed cache', () {
    RecommendationCache.instance.setFeed('key3', const []);
    RecommendationCache.instance.setCachedProfile(TasteProfile.empty);

    RecommendationCache.instance.invalidateProfile();

    expect(RecommendationCache.instance.getCachedProfile(), isNull);
    expect(RecommendationCache.instance.getFeed('key3'), isNotNull);
  });

  test('invalidateAll clears both feed cache and profile', () {
    RecommendationCache.instance.setFeed('key4', const []);
    RecommendationCache.instance.setCachedProfile(TasteProfile.empty);

    RecommendationCache.instance.invalidateAll();

    expect(RecommendationCache.instance.getCachedProfile(), isNull);
    expect(RecommendationCache.instance.getFeed('key4'), isNull);
  });
}

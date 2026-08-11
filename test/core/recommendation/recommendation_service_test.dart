// ═════════════════════════════════════════════════════════════════════════════
// V Shots — RecommendationService Tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/recommendation/recommendation_service.dart';
import 'package:v_shots/features/foryou/for_you_feed_service.dart';

void main() {
  group('RecommendationService & Expanded Vibes', () {
    test('availableMoods contains all expanded categories', () {
      final moods = ForYouFeedService.availableMoods;
      expect(moods.length, greaterThanOrEqualTo(22));

      final labels = moods.map((m) => m['label']!).toList();
      expect(labels, contains('Trending Hits'));
      expect(labels, contains('Devotional & Bhajans'));
      expect(labels, contains('Sufi & Ghazals'));
      expect(labels, contains('90s Nostalgia'));
      expect(labels, contains('Workout Cardio'));
      expect(labels, contains('Sleep & Ambient'));
      expect(labels, contains('Kids & Family'));
      expect(labels, contains('Marathi Hits'));
      expect(labels, contains('Gujarati Hits'));
      expect(labels, contains('Tamil Hits'));
      expect(labels, contains('Telugu Hits'));
      expect(labels, contains('Bengali Hits'));
      expect(labels, contains('Wedding & Sangeet'));
      expect(labels, contains('Monsoon Vibes'));
      expect(labels, contains('Motivational'));
    });

    test('UserContext updates and persists vibe and region preferences', () {
      final service = RecommendationService.instance;
      service.setMood('Romantic & Love', 'romantic love songs hindi');
      expect(service.context.selectedMood, 'Romantic & Love');
      expect(service.context.selectedMoodQuery, 'romantic love songs hindi');

      service.setLocationRegion('Punjab');
      expect(service.context.locationRegion, 'Punjab');
    });

    test('getPersonalizedHomeQuery derives queries from user context', () {
      final service = RecommendationService.instance;
      service.setMood('Punjabi Bangers', 'latest punjabi pop hits official');
      final query = service.getPersonalizedHomeQuery();
      expect(query, isNotEmpty);
    });
  });
}

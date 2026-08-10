// ═════════════════════════════════════════════════════════════════════════════
// V Shots — YouTubeMusicProvider Tests
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/providers/adapters/youtube/youtube_music_provider.dart';
import 'package:v_shots/core/providers/music_provider.dart';

void main() {
  group('YouTubeMusicProvider Compliance & Functionality', () {
    late YouTubeMusicProvider provider;

    setUp(() async {
      provider = YouTubeMusicProvider();
      await provider.initialize();
    });

    tearDown(() async {
      await provider.dispose();
    });

    test('declares correct compliant capabilities', () {
      expect(provider.supports(ProviderCapability.search), isTrue);
      expect(provider.supports(ProviderCapability.getTrack), isTrue);
      expect(provider.supports(ProviderCapability.getArtwork), isTrue);
      expect(provider.supports(ProviderCapability.getLyrics), isTrue);
      expect(provider.supports(ProviderCapability.getTrending), isTrue);
      expect(provider.supports(ProviderCapability.getRecommendations), isTrue);
      // Extraction capability must be false for YouTube
      expect(provider.supports(ProviderCapability.getStream), isFalse);
    });

    test('getStream rejects unofficial stream extraction', () async {
      final result = await provider.getStream('kJQP7kiw5Fk');
      expect(result.isFailure, isTrue);
      expect(result.error, contains('extraction is prohibited'));
    });

    test('search returns mapped ProviderTrack objects', () async {
      final result = await provider.search('Diljit Dosanjh', limit: 5);
      expect(result.isSuccess, isTrue);
      expect(result.data, isNotEmpty);
      expect(result.data!.first.id, isNotEmpty);
      expect(result.data!.first.title, isNotEmpty);
    });

    test('getTrending returns curated trending hits', () async {
      final result = await provider.getTrending(limit: 5);
      expect(result.isSuccess, isTrue);
      expect(result.data, isNotEmpty);
    });

    test('getRecommendations returns recommended tracks', () async {
      final result = await provider.getRecommendations(
        excludeIds: const {},
        limit: 5,
      );
      expect(result.isSuccess, isTrue);
      expect(result.data, isNotEmpty);
    });
  });
}

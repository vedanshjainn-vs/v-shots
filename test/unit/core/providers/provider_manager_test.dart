// ════════════════════════════════════════════════
// Project Lyra — Provider Manager Tests
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lyra/core/providers/adapters/development/development_provider.dart';
import 'package:project_lyra/core/providers/imusic_provider.dart';
import 'package:project_lyra/core/providers/manager/provider_manager.dart';
import 'package:project_lyra/core/providers/registry/provider_registry.dart';

import '../../../fakes/fake_cache.dart';

void main() {
  group('ProviderRegistry', () {
    late ProviderRegistry registry;
    late DevelopmentProvider devProvider;

    setUp(() {
      registry = ProviderRegistry();
      devProvider = DevelopmentProvider();
    });

    test('register and retrieve provider', () {
      registry.register(devProvider);

      expect(registry.isRegistered('development'), true);
      expect(registry.getProvider('development'), isNotNull);
    });

    test('enable and disable provider', () {
      registry.register(devProvider);

      expect(registry.isEnabled('development'), true);

      registry.disable('development');
      expect(registry.isEnabled('development'), false);

      registry.enable('development');
      expect(registry.isEnabled('development'), true);
    });

    test('set active provider', () async {
      registry.register(devProvider);
      await registry.initializeProvider(
        'development',
        const ProviderInitConfig(apiKey: 'test'),
      );

      final success = await registry.setActiveProvider('development');
      expect(success, true);
      expect(registry.activeProviderId, 'development');
    });

    test('fail to set disabled provider as active', () async {
      registry.register(devProvider, enabled: false);

      final success = await registry.setActiveProvider('development');
      expect(success, false);
    });

    test('unregister removes provider', () {
      registry.register(devProvider);
      expect(registry.isRegistered('development'), true);

      registry.unregister('development');
      expect(registry.isRegistered('development'), false);
    });
  });

  group('DevelopmentProvider', () {
    late DevelopmentProvider provider;

    setUp(() {
      provider = DevelopmentProvider();
    });

    test('returns correct metadata', () {
      expect(provider.id, 'development');
      expect(provider.name, 'Development Provider');
      expect(provider.capabilities.supportsSearch, true);
      expect(provider.capabilities.supportsStreaming, true);
    });

    test('healthCheck returns healthy', () async {
      final health = await provider.healthCheck();
      expect(health.isHealthy, true);
    });

    test('search returns results', () async {
      final result = await provider.search('test query');
      expect(result.tracks.isNotEmpty, true);
      expect(result.albums.isNotEmpty, true);
      expect(result.query, 'test query');
    });

    test('getTrack returns track', () async {
      final track = await provider.getTrack('test_123');
      expect(track.id, 'test_123');
      expect(track.title.isNotEmpty, true);
    });

    test('getStream returns stream info', () async {
      final stream = await provider.getStream('test_123');
      expect(stream.url.isNotEmpty, true);
      expect(stream.quality, StreamQuality.high);
    });

    test('getLyrics returns lyrics', () async {
      final lyrics = await provider.getLyrics('test_123');
      expect(lyrics, isNotNull);
      expect(lyrics!.lines.isNotEmpty, true);
    });

    test('getRecommendations returns tracks', () async {
      final tracks = await provider.getRecommendations();
      expect(tracks.isNotEmpty, true);
    });

    test('getTrending returns tracks', () async {
      final tracks = await provider.getTrending();
      expect(tracks.isNotEmpty, true);
    });

    test('getGenres returns genres', () async {
      final genres = await provider.getGenres();
      expect(genres.isNotEmpty, true);
    });
  });
}

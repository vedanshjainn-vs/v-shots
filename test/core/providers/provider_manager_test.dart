// ════════════════════════════════════════════════
// V Shots — ProviderManager / ProviderRegistry tests (Phase 11)
// ════════════════════════════════════════════════
//
// Uses a small in-memory FakeProvider (no real network/YouTube calls)
// so these tests are fast, deterministic, and runnable in any sandbox
// — real YouTube connectivity is verified separately via CI/manual
// device testing (see docs/CURRENT_BASELINE.md Section 8's note on why
// this sandbox itself cannot reach youtube.com).
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/providers/music_provider.dart';
import 'package:v_shots/core/providers/provider_config.dart';
import 'package:v_shots/core/providers/provider_manager.dart';
import 'package:v_shots/core/providers/provider_models.dart';
import 'package:v_shots/core/providers/provider_registry.dart';
import 'package:v_shots/core/providers/provider_result.dart';

/// A minimal, fully-controllable fake provider for tests — no network
/// calls, deterministic results, and switches that let tests simulate
/// failure/unhealthiness on demand.
class FakeProvider implements MusicProvider {
  FakeProvider(this._id, {this.healthy = true, this.failSearch = false});

  final String _id;
  bool healthy;
  bool failSearch;
  int searchCallCount = 0;

  @override
  String get id => _id;

  @override
  String get displayName => 'Fake $_id';

  @override
  Set<ProviderCapability> get capabilities => ProviderCapability.values.toSet();

  @override
  bool supports(ProviderCapability capability) =>
      capabilities.contains(capability);

  @override
  Future<void> initialize() async {}

  @override
  Future<ProviderHealth> healthCheck() async =>
      ProviderHealth(healthy: healthy, message: healthy ? null : 'unhealthy');

  @override
  Future<ProviderResult<List<ProviderTrack>>> search(
    String query, {
    int limit = 20,
    int maxDurationMinutes = 15,
    int minDurationMinutes = 0,
    Set<String> excludeIds = const {},
  }) async {
    searchCallCount++;
    if (failSearch) return ProviderResult.failure('$_id search failed');
    return ProviderResult.success([
      ProviderTrack(
        id: '$_id-track-1',
        title: 'Track from $_id',
        artist: 'Artist',
        artworkUrl: 'https://example.com/art.jpg',
        durationSeconds: 180,
      ),
    ]);
  }

  @override
  Future<ProviderResult<ProviderTrack>> getTrack(String id) async {
    return ProviderResult.success(
      ProviderTrack(
        id: id,
        title: 'Title',
        artist: 'Artist',
        artworkUrl: '',
        durationSeconds: 100,
      ),
    );
  }

  @override
  Future<ProviderResult<String>> getStream(String id) async {
    return ProviderResult.success('https://example.com/stream/$id');
  }

  @override
  Future<ProviderResult<String>> getArtwork(String id) async {
    return ProviderResult.success('https://example.com/art/$id');
  }

  @override
  Future<ProviderResult<ProviderLyrics>> getLyrics({
    required String trackName,
    required String artistName,
    int? durationSeconds,
  }) async {
    return ProviderResult.success(const ProviderLyrics(plainText: 'la la la'));
  }

  @override
  Future<ProviderResult<List<ProviderTrack>>> getTrending({int limit = 15}) {
    return search('trending', limit: limit);
  }

  @override
  Future<ProviderResult<List<ProviderTrack>>> getRecommendations({
    required Set<String> excludeIds,
    int limit = 10,
  }) {
    return search('recommendations', limit: limit);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('ProviderRegistry', () {
    test('registers and retrieves providers by id', () {
      final registry = ProviderRegistry();
      final provider = FakeProvider('youtube');
      registry.register(provider);

      expect(registry['youtube'], same(provider));
      expect(registry['nonexistent'], isNull);
      expect(registry.isNotEmpty, isTrue);
    });

    test(
      'inPriorityOrder respects config order and skips unregistered ids',
      () {
        final registry = ProviderRegistry();
        final youtube = FakeProvider('youtube');
        registry.register(youtube);

        const config = ProviderConfig(
          activeProvider: 'youtube',
          enabledProviders: ['youtube'],
          // 'spotify' is listed in priority but never registered — must
          // be silently skipped, not throw.
          providerPriority: ['spotify', 'youtube'],
        );

        final ordered = registry.inPriorityOrder(config);
        expect(ordered, [youtube]);
      },
    );

    test('inPriorityOrder excludes disabled providers', () {
      final registry = ProviderRegistry();
      final youtube = FakeProvider('youtube');
      registry.register(youtube);

      const config = ProviderConfig(
        activeProvider: 'youtube',
        enabledProviders: [], // youtube registered but not enabled
        providerPriority: ['youtube'],
      );

      expect(registry.inPriorityOrder(config), isEmpty);
    });
  });

  group('ProviderManager', () {
    test('activeProvider exposes the configured provider', () {
      final registry = ProviderRegistry()..register(FakeProvider('youtube'));
      final manager = ProviderManager(registry: registry);
      expect(manager.activeProvider?.id, 'youtube');
    });

    test(
      'search routes to the healthy provider and returns real data',
      () async {
        final registry = ProviderRegistry()..register(FakeProvider('youtube'));
        final manager = ProviderManager(registry: registry);

        final result = await manager.search('test query');
        expect(result.isSuccess, isTrue);
        expect(result.data!.single.title, 'Track from youtube');
      },
    );

    test('search fails gracefully when no provider is registered', () async {
      final manager = ProviderManager(registry: ProviderRegistry());
      final result = await manager.search('anything');
      expect(result.isFailure, isTrue);
    });

    test(
      'failover: a failing provider falls through to the next one',
      () async {
        final failing = FakeProvider('broken', failSearch: true);
        final working = FakeProvider('backup');
        final registry = ProviderRegistry()
          ..register(failing)
          ..register(working);

        const config = ProviderConfig(
          activeProvider: 'broken',
          enabledProviders: ['broken', 'backup'],
          providerPriority: ['broken', 'backup'],
        );
        final manager = ProviderManager(registry: registry, config: config);

        final result = await manager.search('query');
        expect(result.isSuccess, isTrue);
        expect(result.data!.single.title, 'Track from backup');
      },
    );

    test('checkAllHealth reports each registered provider\'s health', () async {
      final healthy = FakeProvider('a', healthy: true);
      final unhealthy = FakeProvider('b', healthy: false);
      final registry = ProviderRegistry()
        ..register(healthy)
        ..register(unhealthy);
      const config = ProviderConfig(
        activeProvider: 'a',
        enabledProviders: ['a', 'b'],
        providerPriority: ['a', 'b'],
      );
      final manager = ProviderManager(registry: registry, config: config);

      final health = await manager.checkAllHealth();
      expect(health['a']!.healthy, isTrue);
      expect(health['b']!.healthy, isFalse);
    });
  });

  group('ProviderTrack conversion', () {
    test('toTrackMap/fromTrackMap round-trip preserves data', () {
      const track = ProviderTrack(
        id: 'abc123',
        title: 'My Song',
        artist: 'My Artist',
        artworkUrl: 'https://example.com/x.jpg',
        durationSeconds: 210,
      );
      final map = track.toTrackMap();
      expect(map['id'], 'abc123');
      expect(map['title'], 'My Song');
      expect(map['artist'], 'My Artist');
      expect(map['artwork'], 'https://example.com/x.jpg');
      expect(map['duration'], 210);

      final roundTripped = ProviderTrack.fromTrackMap(map);
      expect(roundTripped.id, track.id);
      expect(roundTripped.title, track.title);
      expect(roundTripped.durationSeconds, track.durationSeconds);
    });
  });
}

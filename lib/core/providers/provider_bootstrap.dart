// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Provider Architecture: bootstrap/wiring
// ═════════════════════════════════════════════════════════════════════════════

import 'adapters/youtube/youtube_data_api_client.dart';
import 'adapters/youtube/youtube_music_provider.dart';
import 'music_repository.dart';
import 'provider_config.dart';
import 'provider_manager.dart';
import 'provider_registry.dart';

/// Builds a real [MusicRepository] backed by the configured providers.
MusicRepository buildMusicRepository({YouTubeDataApiClient? apiClient}) {
  final registry = ProviderRegistry()
    ..register(YouTubeMusicProvider(apiClient: apiClient));
  final manager = ProviderManager(
    registry: registry,
    config: ProviderConfig.defaultConfig,
  );
  // ignore: discarded_futures
  manager.initializeAll();
  return MusicRepository(manager);
}

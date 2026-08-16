// ═════════════════════════════════════════════════════════════════════════════
// V Shots — Provider Architecture: bootstrap/wiring
// ═════════════════════════════════════════════════════════════════════════════

import '../innertube/inner_tube_client.dart';
import 'adapters/innertube/inner_tube_music_provider.dart';
import 'adapters/youtube/youtube_data_api_client.dart';
import 'adapters/youtube/youtube_music_provider.dart';
import 'music_repository.dart';
import 'provider_config.dart';
import 'provider_manager.dart';
import 'provider_registry.dart';

/// Builds a real [MusicRepository] backed by the configured providers.
///
/// Priority: InnerTube (primary discovery metadata) → YouTube Data API v3
/// (fallback). Playback is unaffected — it remains the official YouTube
/// IFrame player.
MusicRepository buildMusicRepository({
  YouTubeDataApiClient? apiClient,
  InnerTubeClient? innerTubeClient,
}) {
  final registry = ProviderRegistry()
    ..register(InnerTubeMusicProvider(client: innerTubeClient))
    ..register(YouTubeMusicProvider(apiClient: apiClient));
  final manager = ProviderManager(
    registry: registry,
    config: ProviderConfig.defaultConfig,
  );
  // ignore: discarded_futures
  manager.initializeAll();
  return MusicRepository(manager);
}

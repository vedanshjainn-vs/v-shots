// ════════════════════════════════════════════════
// V Shots — Provider Architecture: bootstrap/wiring
// ════════════════════════════════════════════════
//
// One small factory function that assembles the real object graph:
//   YoutubeExplode (existing, shared instance)
//     -> YouTubeMusicProvider (wraps it)
//     -> ProviderRegistry (registers it)
//     -> ProviderManager (routes to it)
//     -> MusicRepository (what UI code actually depends on)
//
// Kept as a single function (not scattered construction across
// main.dart) so there is exactly one place that decides how providers
// are wired together — matches this task's "ONE SOURCE OF TRUTH"
// anti-regression rule.
// ════════════════════════════════════════════════

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'adapters/youtube/youtube_music_provider.dart';
import 'music_repository.dart';
import 'provider_config.dart';
import 'provider_manager.dart';
import 'provider_registry.dart';

/// Builds a real [MusicRepository] backed by the app's existing shared
/// [youtubeExplode] instance (main.dart's `sharedYt` — this function
/// does NOT construct a new YoutubeExplode()). Call once, e.g. in
/// main() or as part of a top-level global initializer, and reuse the
/// returned repository everywhere.
MusicRepository buildMusicRepository(YoutubeExplode youtubeExplode) {
  final registry = ProviderRegistry()
    ..register(YouTubeMusicProvider(youtubeExplode));
  final manager = ProviderManager(
    registry: registry,
    config: ProviderConfig.defaultConfig,
  );
  // Fire-and-forget: initialize() just marks the provider ready (see
  // YouTubeMusicProvider.initialize()'s doc — there's no async setup
  // to actually await for YouTube today), so this doesn't need to
  // block app startup. Awaiting it here would add a startup-blocking
  // step for zero real benefit, conflicting with Phase 9's "no
  // indefinite startup blocking" goal.
  // ignore: discarded_futures
  manager.initializeAll();
  return MusicRepository(manager);
}

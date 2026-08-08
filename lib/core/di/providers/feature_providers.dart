// ════════════════════════════════════════════════
// Project Lyra — Feature DI Registration
// ════════════════════════════════════════════════
//
// Registers all feature repositories, data sources,
// and use cases in the Riverpod container.
// ════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Auth ──────────────────────────────────────
import '../../../features/auth/presentation/providers/auth_providers.dart';

// ── Home ──────────────────────────────────────
import '../../../features/home/domain/repositories/home_repository.dart';
import '../../../features/home/domain/usecases/home_usecases.dart';

// ── Library ───────────────────────────────────
import '../../../features/library/domain/repositories/library_repository.dart';
import '../../../features/library/domain/usecases/library_usecases.dart';

// ── Search ────────────────────────────────────
import '../../../features/search/domain/repositories/search_repository.dart';
import '../../../features/search/domain/usecases/search_usecases.dart';

// ── Player ────────────────────────────────────
import '../../../features/player/domain/repositories/player_repository.dart';
import '../../../features/player/domain/usecases/player_usecases.dart';

// ── Playlist ──────────────────────────────────
import '../../../features/playlist/domain/repositories/playlist_repository.dart';
import '../../../features/playlist/domain/usecases/playlist_usecases.dart';

// ── Downloads ─────────────────────────────────
import '../../../features/downloads/domain/repositories/download_repository.dart';
import '../../../features/downloads/domain/usecases/download_usecases.dart';

// ── Recommendation ────────────────────────────
import '../../../features/recommendation/domain/repositories/recommendation_repository.dart';
import '../../../features/recommendation/domain/usecases/recommendation_usecases.dart';

// ── Notifications ─────────────────────────────
import '../../../features/notifications/domain/repositories/notification_repository.dart';
import '../../../features/notifications/domain/usecases/notification_usecases.dart';

// ── Settings ──────────────────────────────────
import '../../../features/settings/domain/repositories/settings_repository.dart';
import '../../../features/settings/domain/usecases/settings_usecases.dart';

// ── Subscription ──────────────────────────────
import '../../../features/subscription/domain/repositories/subscription_repository.dart';
import '../../../features/subscription/domain/usecases/subscription_usecases.dart';

// ── History ───────────────────────────────────
import '../../../features/history/domain/repositories/history_repository.dart';
import '../../../features/history/domain/usecases/history_usecases.dart';

// ── Profile ───────────────────────────────────
import '../../../features/profile/domain/repositories/profile_repository.dart';
import '../../../features/profile/domain/usecases/profile_usecases.dart';

// ═══════════════════════════════════════════════════
// REPOSITORIES — Concrete implementations injected here.
// TODO(team): Replace placeholder implementations with
// real data source integrations as features are built.
// ═══════════════════════════════════════════════════

// Auth repository is already registered in auth_providers.dart.
// Export it for convenience.
export '../../../features/auth/presentation/providers/auth_providers.dart' show authRepositoryProvider;

// ── Home ──────────────────────────────────────
// TODO(team): Register HomeRepositoryImpl when implemented.
// final homeRepositoryProvider = Provider<HomeRepository>((ref) {
//   return HomeRepositoryImpl(...);
// });

// ── Library ───────────────────────────────────
// TODO(team): Register LibraryRepositoryImpl when implemented.

// ── Search ────────────────────────────────────
// TODO(team): Register SearchRepositoryImpl when implemented.

// ── Player ────────────────────────────────────
// TODO(team): Register PlayerRepositoryImpl when implemented.

// ── Playlist ──────────────────────────────────
// TODO(team): Register PlaylistRepositoryImpl when implemented.

// ── Downloads ─────────────────────────────────
// TODO(team): Register DownloadRepositoryImpl when implemented.

// ── Recommendation ────────────────────────────
// TODO(team): Register RecommendationRepositoryImpl when implemented.

// ── Notifications ─────────────────────────────
// TODO(team): Register NotificationRepositoryImpl when implemented.

// ── Settings ──────────────────────────────────
// TODO(team): Register SettingsRepositoryImpl when implemented.

// ── Subscription ──────────────────────────────
// TODO(team): Register SubscriptionRepositoryImpl when implemented.

// ── History ───────────────────────────────────
// TODO(team): Register HistoryRepositoryImpl when implemented.

// ── Profile ───────────────────────────────────
// TODO(team): Register ProfileRepositoryImpl when implemented.

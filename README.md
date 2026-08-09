# 🎵 V Shots

> A personal, hobby-scale music streaming app (package `com.vshots.live`) — NOT the
> hypothetical "Project Lyra" scale/branding described in the rest of this document.

**⚠️ STATUS CORRECTION (real, current state — see `docs/CURRENT_BASELINE.md` and
`V_SHOTS_CURRENT_STATE_AUDIT.md` for the full, verified picture):** this document was
originally written for an earlier, much larger hypothetical "Project Lyra" (100M+ users,
Spotify/Apple Music/YouTube Music multi-provider) concept. The REAL, actually-built app is
smaller and different in scope, but IS a real, working, substantially-featured app — the
line that used to say "No features are implemented yet" was false and has been corrected:

- ✅ Real YouTube-backed search, playback (`just_audio` + `audio_service` background
  playback), a Provider Architecture (`lib/core/providers/` — `MusicRepository` ->
  `ProviderManager` -> `YouTubeMusicProvider`, see below), Home (7–9 real, auto-refreshing
  categories), a Resso-style Discover/For You swipe feed with a real recency-weighted
  recommendation engine, Search (debounced, cached, deduplicated), Library (Liked Songs /
  Playlists / Recently Played / local file import), Lyrics (LRCLIB), a Sleep Timer,
  Shuffle/Repeat, Google Sign-In (via Supabase — see Known Gaps below), and CI/CD
  (GitHub Actions -> BrowserStack).
- ❌ NOT implemented (and not currently planned): multi-provider content (Spotify/Apple
  Music), podcasts/audiobooks, a 100M-user backend, Clean-Architecture layering, or
  Riverpod state management (the app uses `StatefulWidget`/`setState` in one primary
  `lib/main.dart`, plus focused feature files under `lib/features/` and `lib/core/`).
- ⚠️ Known real gap: Google Sign-In requires a Supabase Dashboard Client Secret that has
  not yet been configured (see `lib/core/backend/auth_service.dart`'s file header for the
  exact steps) — not a code bug.
- ⚠️ This app streams audio via an unofficial YouTube client
  (`youtube_explode_dart`) for personal/learning use. This is explicitly **not** a
  legally safe foundation for a commercial/Play-Store launch — see this repo's commit
  history and `docs/legal/terms_of_service.md` for the full disclosure.

Everything below this point in the document describes the ORIGINAL, larger "Project
Lyra" architecture concept/aspiration — treat it as historical/aspirational design
notes, not a description of the current codebase, unless cross-referenced against
`docs/CURRENT_BASELINE.md`.

---

## 📋 Table of Contents

- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Build Flavors](#build-flavors)
- [Design System](#design-system)
- [State Management](#state-management)
- [Navigation](#navigation)
- [Networking](#networking)
- [Storage](#storage)
- [Error Handling](#error-handling)
- [Testing](#testing)
- [Best Practices](#best-practices)
- [Roadmap](#roadmap)

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                    │
│   Screens · Widgets · Providers (Riverpod) · State      │
├─────────────────────────────────────────────────────────┤
│                      DOMAIN LAYER                        │
│   Use Cases · Entities · Repository Interfaces           │
├─────────────────────────────────────────────────────────┤
│                      DATA LAYER                          │
│   Repository Implementations · Models · Data Sources     │
├─────────────────────────────────────────────────────────┤
│                   CORE / INFRASTRUCTURE                  │
│   Network · Storage · Analytics · Audio · Logging        │
└─────────────────────────────────────────────────────────┘
```

**Clean Architecture** with **Feature-First** organization:

- Each feature owns its `data`, `domain`, and `presentation` layers
- Shared code lives in `core/` and `shared/`
- Dependencies flow inward: Presentation → Domain ← Data
- Repository pattern abstracts data sources
- Use cases encapsulate single business actions

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **UI** | Flutter Stable · Material 3 · Dart 3 |
| **State** | Riverpod (with code generation) |
| **Navigation** | GoRouter |
| **Backend** | Supabase |
| **Analytics** | Firebase Analytics |
| **Crash Reporting** | Firebase Crashlytics |
| **Push Notifications** | Firebase Cloud Messaging |
| **Auth** | Google Sign-In · Supabase Auth |
| **Monetization** | Google AdMob |
| **Local Storage** | Hive · SharedPreferences |
| **Networking** | Dio |
| **Serialization** | Freezed · json_serializable |
| **Audio** | just_audio · audio_session (Media3-ready) |
| **Utilities** | Logger · Connectivity Plus · Package Info Plus · Permission Handler |

---

## Project Structure

```
project_lyra/
├── lib/
│   ├── app/                          # App entry & lifecycle
│   │   ├── app.dart                  # Root MaterialApp
│   │   ├── app_startup.dart          # Cold-start initialization
│   │   └── observers/                # Riverpod & Router observers
│   │
│   ├── config/                       # App configuration
│   │   ├── environment/              # Flavors, env configs
│   │   ├── theme/                    # Material 3 themes
│   │   │   ├── color_schemes/        # Dark & Light color tokens
│   │   │   ├── typography/           # Type scale
│   │   │   └── extensions/           # Custom theme extensions
│   │   ├── constants/                # App, API, storage, asset constants
│   │   └── assets/                   # Asset path definitions
│   │
│   ├── core/                         # Shared infrastructure
│   │   ├── ai/                       # AI client, prompt builder, embeddings
│   │   ├── analytics/                # Analytics batching, events, properties
│   │   ├── audio/                    # Audio handler, Media3 bridge
│   │   ├── background/               # Background jobs, scheduler, queue
│   │   ├── cache/                    # 3-tier cache (Memory → Disk → Network)
│   │   ├── connectivity/             # Connectivity monitor, quality estimation
│   │   ├── design_system/            # Design tokens, motion, foundations
│   │   ├── di/                       # Riverpod providers & scopes
│   │   ├── downloads/                # Download manager, queue, workers
│   │   ├── enums/                    # App-wide enums
│   │   ├── errors/                   # Failure hierarchy, Result type, mapper
│   │   ├── events/                   # Typed event bus system
│   │   ├── feature_flags/            # Feature flags, A/B tests, kill switches
│   │   ├── images/                   # Image pipeline, cache, placeholders
│   │   ├── logging/                  # Structured logger
│   │   ├── media/                    # Playback queue, state, sleep timer, casting
│   │   ├── navigation/               # Guards, deep links, transitions
│   │   ├── network/                  # Dio, circuit breaker, deduplication
│   │   ├── notifications/            # FCM service
│   │   ├── permissions/              # Permission service
│   │   ├── performance/              # Startup optimizer
│   │   ├── recommendation/           # Recommendation engine interfaces
│   │   ├── remote_config/            # Remote config, experiment overrides
│   │   ├── router/                   # GoRouter config, guards
│   │   ├── security/                 # Secure storage, encryption, biometric
│   │   ├── storage/                  # Hive, SharedPreferences abstractions
│   │   ├── sync/                     # Offline sync, conflict resolution
│   │   ├── telemetry/                # Performance monitor, FPS, memory
│   │   ├── usecase/                  # Base use case contracts
│   │   └── utils/                    # Extensions, helpers, mixins
│   │
│   ├── features/                     # Feature modules
│   │   ├── splash/                   # Splash screen
│   │   ├── onboarding/               # Onboarding flow
│   │   ├── auth/                     # Authentication
│   │   ├── home/                     # Home feed
│   │   ├── search/                   # Search & AI Search
│   │   ├── player/                   # Music player
│   │   ├── library/                  # User library
│   │   ├── playlist/                 # Playlists
│   │   ├── artist/                   # Artist pages
│   │   ├── album/                    # Album pages
│   │   ├── podcast/                  # Podcasts
│   │   ├── audiobook/                # Audiobooks
│   │   ├── profile/                  # User profile
│   │   ├── settings/                 # App settings
│   │   ├── premium/                  # Premium subscription
│   │   └── discover/                 # Discover & recommendations
│   │
│   ├── shared/                       # Shared UI components
│   │   ├── widgets/                  # Reusable widgets
│   │   │   ├── buttons/              # Primary, secondary buttons
│   │   │   ├── cards/                # Glass, gradient, media cards
│   │   │   ├── inputs/               # Search input, text fields
│   │   │   ├── loading/              # Loaders, indicators
│   │   │   ├── error/                # Error views
│   │   │   ├── glass/                # Glassmorphism container
│   │   │   ├── gradients/            # Dynamic gradient backgrounds
│   │   │   ├── shimmer/              # Shimmer loading skeletons
│   │   │   ├── badges/               # Premium badge, etc.
│   │   │   ├── bottom_sheets/        # Styled bottom sheets
│   │   │   ├── dialogs/              # Styled dialogs
│   │   │   ├── app_bars/             # Custom app bars
│   │   │   ├── tab_bars/             # Pill-style tabs
│   │   │   ├── images/               # Artwork, cached images
│   │   │   └── shell/                # App shell (bottom nav)
│   │   └── mixins/                   # Shared mixins
│   │
│   └── l10n/                         # Localization ARB files
│
├── assets/                           # Static assets
│   ├── images/
│   ├── animations/
│   ├── lottie/
│   └── fonts/
│
├── test/                             # Tests
│   ├── unit/
│   ├── widget/
│   ├── integration/
│   ├── mocks/
│   └── fixtures/
│
├── pubspec.yaml                      # Dependencies
├── analysis_options.yaml             # Lint rules
├── Makefile                          # Dev commands
├── .env.development                  # Dev environment
├── .env.staging                      # Staging environment
└── .env.production                   # Production environment
```

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.16.0
- Dart SDK ≥ 3.2.0
- Android Studio / VS Code
- Supabase account
- Firebase project

### Setup

```bash
# 1. Clone and enter the project
cd project_lyra

# 2. Install dependencies
flutter pub get

# 3. Generate code (Freezed, JSON, Riverpod)
make codegen

# 4. Generate localization
make l10n

# 5. Run in development
make dev
```

---

## Build Flavors

| Flavor | Command | Purpose |
|--------|---------|---------|
| Development | `make dev` | Local dev, test ads, verbose logging |
| Staging | `make stg` | QA, staging backend, analytics on |
| Production | `make prod` | Release, real ads, crashlytics on |

Flavors are configured via `--dart-define=FLAVOR=...` and the `Env` class.

---

## Design System

### Visual Identity

**Apple Music-inspired** — minimal, premium, elegant. Not a Spotify clone.

- **Dark theme**: Deep blacks (#0A0A0F), vibrant coral-red accent (#FF4D6A)
- **Light theme**: Clean whites (#FFFFFBFF), refined accent (#B02E45)
- **Typography**: SF Pro Display/Text (system), 15-step type scale
- **Shapes**: Large rounded corners (16px default), pill buttons
- **Effects**: Glassmorphism, dynamic gradients, shimmer loading
- **Motion**: Smooth 300ms transitions, micro-interactions

### Theme Extensions

Access custom tokens via `Theme.of(context).extension<LyraThemeExtension>()!`:

```dart
final lyra = context.lyra;

// Gradients
lyra.gradientPrimary
lyra.gradientCool

// Glass
lyra.glassColor
lyra.glassBlur

// Spacing
lyra.spacingMd  // 16
lyra.spacingLg  // 24

// Radius
lyra.radiusLarge  // 16
lyra.radiusXLarge  // 24
```

### Shorthand Accessors

```dart
context.colors          // ColorScheme
context.textStyles      // TextTheme
context.isDarkMode      // bool
context.screenWidth     // double
context.lyra            // LyraThemeExtension
```

---

## State Management

**Riverpod** with code generation:

```dart
// Provider definition
@riverpod
Future<List<Track>> trendingTracks(TrendingTracksRef ref) async {
  final repo = ref.watch(trackRepositoryProvider);
  final result = await repo.getTrending();
  return result.fold((failure) => throw failure, (tracks) => tracks);
}

// Usage in widget
class TrendingSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(trendingTracksProvider);

    return tracksAsync.when(
      data: (tracks) => TrackList(tracks: tracks),
      loading: () => const ShimmerCardList(),
      error: (error, _) => ErrorView(message: error.toString()),
    );
  }
}
```

### Provider Organization

| Scope | File | Purpose |
|-------|------|---------|
| Core | `core/di/injection.dart` | Dio, storage, network |
| Core | `core/di/providers/storage_providers.dart` | Hive, SharedPrefs |
| Core | `core/di/providers/network_providers.dart` | HTTP clients |
| Feature | `features/X/presentation/providers/` | Feature-specific |

---

## Navigation

**GoRouter** with shell route for bottom navigation:

```
/splash → /onboarding → /login → /home (Shell)
                                  ├── /home
                                  ├── /explore
                                  └── /library

/track/:id    (detail)
/album/:id    (detail)
/artist/:id   (detail)
/playlist/:id (detail)
/player       (full-screen, slide-up)
/search       (search)
/settings     (settings)
/premium      (subscription)
```

### Route Guards

- **AuthGuard**: Redirects unauthenticated users to `/login`
- **OnboardingGuard**: Redirects new users to `/onboarding`

---

## Networking

**Dio** with interceptor chain:

```
Request → AuthInterceptor → RetryInterceptor → LogInterceptor → Server
Response ← AuthInterceptor ← RetryInterceptor ← LogInterceptor ← Server
```

- **Auth**: Auto-injects Bearer token, handles 401 with token refresh
- **Retry**: Exponential backoff with jitter, respects Retry-After headers
- **Logging**: Pretty-printed in dev, sanitized (no auth tokens)

---

## Storage

| Type | Use Case | Implementation |
|------|----------|----------------|
| **SharedPreferences** | Settings, flags, auth tokens | `SharedPrefsStorage` |
| **Hive** | Offline cache, playback queue, downloads | `HiveStorage` |

Both implement `LocalStorage` interface for testability.

---

## Error Handling

### Layer Boundaries

```
Data Layer → throws AppException (ServerException, NetworkException, ...)
Domain Layer ← receives Failure (ServerFailure, NetworkFailure, ...)
Presentation Layer ← reads Failure to show UI
```

### Error Types

| Exception | Failure | UI Behavior |
|-----------|---------|-------------|
| `ServerException` | `ServerFailure` | Error view + retry |
| `NetworkException` | `NetworkFailure` | Offline banner |
| `AuthException` | `AuthFailure` | Redirect to login |
| `CacheException` | `CacheFailure` | Silent, fetch fresh |
| `RateLimitException` | `RateLimitFailure` | Backoff + message |

---

## Testing

```bash
# Unit tests
make test-unit

# Widget tests
make test-widget

# Integration tests
make test-integration

# Coverage report
make test-coverage
```

### Test Structure

```
test/
├── unit/           # Business logic, use cases, repositories
├── widget/         # Widget tests, golden tests
├── integration/    # End-to-end flows
├── helpers/        # Test utilities (pumpAndSettle, createTestApp)
├── fakes/          # Fake implementations (FakeRepository)
├── builders/       # Test data builders (DownloadTaskBuilder)
├── mocks/          # Mock classes
└── fixtures/       # Test data, JSON fixtures
```

---

## Core Modules

### 1. Offline-First Cache (`core/cache/`)

3-tier caching: Memory → Disk → Network.

- **MemoryCache**: LRU in-memory cache (~200 entries, ~50MB)
- **DiskCache**: Hive-backed persistent cache (~1000 entries, ~200MB)
- **CacheManager**: Orchestrates data flow between layers
- **CachePolicy**: Configurable strategies (cacheFirst, networkFirst, staleWhileRevalidate)
- **CacheRepository**: Base class for offline-first repositories

### 2. Security (`core/security/`)

- **SecureStorageService**: Android Keystore-backed encrypted storage
- **TokenManager**: Access/refresh token lifecycle management
- **BiometricService**: Fingerprint/face authentication hooks
- **CertificatePinning**: SSL pinning for API security
- **EncryptionService**: SHA-256, HMAC, data integrity
- **DeviceIntegrity**: Root/emulator/debug detection

### 3. Image Pipeline (`core/images/`)

- **ImageCacheService**: Two-tier image cache (memory + disk)
- **ImagePipeline**: Full loading lifecycle (cache → download → compress → cache)
- **PlaceholderGenerator**: Content-type-based color placeholders

### 4. Download System (`core/downloads/`)

- **DownloadManager**: Priority queue with concurrent downloads
- **DownloadTask**: Immutable task model with progress tracking
- **DownloadStatus/DownloadPriority**: Status and priority enums

### 5. Event Bus (`core/events/`)

- **AppEventBus**: Type-safe, decoupled event system
- **Typed Events**: Auth, playback, library, connectivity, download, sync, lifecycle

### 6. Sync Engine (`core/sync/`)

- **SyncManager**: Offline queue with connectivity-aware replay
- **SyncOperation**: Pending operation model with retry
- **ConflictResolver**: Interface for data conflict resolution

### 7. Feature Flags (`core/feature_flags/`)

- **FeatureFlagService**: Boolean, percentage, experiment, kill switch
- **FeatureFlag**: Typed flag model with A/B test variants
- **FeatureFlagKeys**: Well-known flag constants

### 8. Telemetry (`core/telemetry/`)

- **PerformanceMonitor**: Operation timing, metric aggregation

### 9. AI Core (`core/ai/`)

- **AIClient**: Abstract interface for LLM services
- **AI Types**: AIResponse, TokenUsage, AIError, ConversationMessage, PromptTemplate
- **EmbeddingService**: Vector embeddings for semantic search

### 10. Recommendation Engine (`core/recommendation/`)

- **RecommendationService**: Interface for personalized recommendations
- **FeedRankingEngine**: Interface for feed ranking
- **RecommendationContext/Result**: Data models

### 11. Background Tasks (`core/background/`)

- **BackgroundJob**: Periodic, connectivity-triggered, on-demand jobs
- **BackgroundJobRunner**: Job execution interface

### 12. Performance (`core/performance/`)

- **StartupOptimizer**: Phase-based startup with parallel task execution

### 13. Advanced Network (`core/network/`)

- **CircuitBreaker**: Prevents cascading failures (closed → open → half-open)
- **RequestDeduplicator**: Shares identical in-flight GET requests
- **CacheInterceptor**: ETag and Cache-Control header support
- **ConnectivityInterceptor**: Blocks requests when offline
- **RetryPolicy**: Configurable exponential backoff with jitter
- **ApiResponse**: Standardized response envelope with pagination

### 14. Connectivity (`core/connectivity/`)

- **ConnectivityMonitor**: Real-time status, quality estimation, auto-reconnect
- **NetworkQuality**: none, poor, moderate, good, excellent

### 15. Error Framework (`core/errors/`)

- **Failure hierarchy**: 20+ typed failures (Network, Server, Timeout, Auth, etc.)
- **Result<T>**: Either<Failure, T> with ergonomic extensions
- **FailureMapper**: Exception → Failure translation

### 16. Routing (`core/navigation/`)

- **PremiumGuard**: Restricts premium-only routes
- **DeepLinkHandler**: Universal links, custom scheme, notification taps
- **PageTransitions**: slideUp, fade, scaleFade, slideRight, none

### 17. Analytics (`core/analytics/`)

- **AnalyticsBatcher**: Buffered event delivery (50 events / 30s)
- **LyraAnalyticsEvents**: Typed event definitions (playback, auth, search, etc.)

### 18. Remote Config (`core/remote_config/`)

- **RemoteConfigService**: Server-controlled config with local cache
- Integrates with FeatureFlagService for runtime evaluation

### 19. Design System (`core/design_system/`)

- **DesignTokens**: Spacing, radius, elevation, motion, breakpoints, component sizes
- **MotionTokens**: fadeIn, slideUp, scaleIn, shimmer, staggeredList, bounce, pulse
- **ResponsiveSpacing**: Screen-size-aware spacing

### 20. Media Foundation (`core/media/`)

- **PlaybackQueue**: Next/prev, shuffle, repeat, add/remove/reorder
- **PlaybackStateModel**: Freezed state with position, duration, status
- **QueueItem**: Track model for the queue
- **SleepTimerService**: Countdown with fade-out and end-of-track
- **CrossfadeConfig / EqualizerPreset**: Audio configuration models
- **LyricsData / LyricsLine**: Synced lyrics support
- **CastingService**: Chromecast, AirPlay, DLNA abstraction
- **BluetoothAudioService**: Bluetooth device management
- **MediaNotificationService**: Android media notification
- **AndroidAutoService / CarPlayService**: Car platform abstractions

---

## Best Practices

### Code Quality

- ✅ All public APIs have doc comments
- ✅ Strict analyzer rules (`strict-casts`, `strict-inference`, `strict-raw-types`)
- ✅ No `print()` statements (use `AppLogger`)
- ✅ No hardcoded strings (use constants or ARB files)
- ✅ No hardcoded colors (use theme tokens)
- ✅ SOLID principles enforced
- ✅ Single Responsibility per class/file

### Performance

- ✅ Lazy provider initialization
- ✅ `const` constructors where possible
- ✅ Cached network images
- ✅ Shimmer loading (no blank screens)
- ✅ Pagination-ready architecture

### Scalability

- ✅ Feature-first folder structure
- ✅ Repository pattern for data abstraction
- ✅ Use cases for business logic isolation
- ✅ Environment-specific configuration
- ✅ Code generation for boilerplate

---

## Roadmap

### Phase 1: Foundation ✅
- [x] Project architecture
- [x] Theme system
- [x] Navigation
- [x] Network layer
- [x] Storage layer
- [x] Error handling
- [x] Shared widgets

### Phase 1.1: Production Infrastructure ✅
- [x] Offline-first cache (Memory → Disk → Network)
- [x] Secure storage (Android Keystore, encrypted tokens)
- [x] Image pipeline (cache, prefetch, placeholders)
- [x] Download system (manager, queue, priority)
- [x] Event bus (typed, decoupled)
- [x] Sync engine (offline queue, conflict resolution)
- [x] Feature flags (A/B tests, kill switches, rollout)
- [x] Telemetry (performance monitor)
- [x] AI core (client interfaces, types)
- [x] Recommendation engine (interfaces)
- [x] Background tasks (jobs, scheduler)
- [x] DI improvements (scoped providers)
- [x] Testing infrastructure (helpers, fakes, builders)
- [x] Performance (startup optimizer)
- [x] Architecture documentation

### Phase 1.2: Core Platform Services ✅
- [x] Advanced network layer (circuit breaker, deduplication, cache interceptor)
- [x] Connectivity service (monitor, quality estimation, events)
- [x] Error framework (Result type, 20+ failures, FailureMapper)
- [x] Routing system (premium guard, deep links, transitions)
- [x] Analytics platform (batching, typed events, user properties)
- [x] Remote config (server-controlled flags, local cache)
- [x] Design system (tokens, motion, responsive spacing)
- [x] Media foundation (queue, state, sleep timer, casting, bluetooth)
- [x] DI registration for all new services
- [x] Unit tests for all new modules

### Phase 2.0: Domain & Data Layer ✅
- [x] Auth feature (entities, repository, use cases, data sources, models)
- [x] Home feature (entities, repository, use cases)
- [x] Library feature (entities, repository, use cases)
- [x] Search feature (entities, repository, use cases)
- [x] Player feature (entities, repository, use cases)
- [x] Playlist feature (entities, repository, use cases)
- [x] Downloads feature (entities, repository, use cases)
- [x] Recommendation feature (entities, repository, use cases)
- [x] Notifications feature (entities, repository, use cases)
- [x] Settings feature (entities, repository, use cases)
- [x] Subscription feature (entities, repository, use cases)
- [x] History feature (entities, repository, use cases)
- [x] Profile feature (entities, repository, use cases)
- [x] Auth data sources (remote + local)
- [x] Auth repository implementation
- [x] DI registration for all features
- [x] Unit tests for entities and use cases

### Phase 2.1: Complete Feature Implementations ✅
- [x] All remote data sources (Supabase stubs)
- [x] All local data sources (Hive/SharedPreferences)
- [x] All repository implementations
- [x] Cache integration
- [x] EventBus integration
- [x] Telemetry integration

### Phase 3.0: Presentation Layer ✅
- [x] 16 production screens
- [x] 25+ shared widgets
- [x] App shell with bottom navigation
- [x] Mini player
- [x] Full player (Apple Music quality)
- [x] GoRouter navigation
- [x] Shimmer loading
- [x] Empty/error states
- [x] Animations (fade, scale, slide, hero)

### Phase 4.0: Production Hardening ✅
- [x] Supabase client integration
- [x] Audio engine (just_audio)
- [x] Download engine
- [x] FCM push notifications
- [x] Security hardening
- [x] CI/CD pipeline
- [x] Privacy policy template
- [x] Terms of service template
- [x] CHANGELOG
- [x] CONTRIBUTING guide
- [x] Release preparation

### Phase 5.0: Provider Abstraction Layer ✅
- [x] IMusicProvider interface
- [x] Provider Registry (simple, under 200 lines)
- [x] Provider Manager (unified API, failover, caching, under 300 lines)
- [x] Simple configuration (ProviderConfig)
- [x] Development Provider (mock data)
- [x] Unified models (Track, Album, Artist, Playlist, Lyrics, Stream)
- [x] Unit tests

### Phase 2: Core Features
- [ ] Authentication (Google Sign-In)
- [ ] Home feed
- [ ] Search
- [ ] Music player
- [ ] Library

### Phase 3: Advanced Features
- [ ] AI Search
- [ ] AI DJ
- [ ] AI Recommendations
- [ ] Podcasts
- [ ] Audiobooks

### Phase 4: Monetization & Scale
- [ ] Premium subscriptions
- [ ] AdMob integration
- [ ] Offline downloads
- [ ] Push notifications
- [ ] Analytics dashboard

---

## Feature Architecture

Each feature follows Clean Architecture with 3 layers:

```
features/auth/
├── data/
│   ├── datasources/
│   │   ├── local/        # Secure storage, Hive
│   │   └── remote/       # Supabase, API calls
│   ├── models/           # Freezed data models
│   └── repositories/     # Repository implementations
├── domain/
│   ├── entities/         # Freezed domain entities
│   ├── repositories/     # Abstract interfaces
│   └── usecases/         # Single-responsibility business actions
└── presentation/
    └── providers/        # Riverpod providers
```

### Implemented Features

| Feature | Entities | Repository | Use Cases | Data Sources |
|---------|----------|------------|-----------|--------------|
| Auth | LyraUser, AuthSession, AuthToken | AuthRepository | 12 | Remote + Local |
| Home | HomeFeed, HomeSection, BannerItem | HomeRepository | 3 | — |
| Library | Library, SavedTrack, SavedAlbum | LibraryRepository | 8 | — |
| Search | SearchResult, SearchSuggestion | SearchRepository | 6 | — |
| Player | Track, Album, PlaybackSession, Lyrics | PlayerRepository | 7 | — |
| Playlist | Playlist, PlaylistItem, Collaborator | PlaylistRepository | 7 | — |
| Downloads | Download, DownloadGroup | DownloadRepository | 7 | — |
| Recommendation | Recommendation, RecommendationFeed | RecommendationRepository | 5 | — |
| Notifications | AppNotification, NotificationSettings | NotificationRepository | 5 | — |
| Settings | AppSettings, ThemeMode, AudioQuality | SettingsRepository | 5 | — |
| Subscription | SubscriptionPlan, Subscription, Receipt | SubscriptionRepository | 6 | — |
| History | HistoryEntry, HistoryGroup | HistoryRepository | 5 | — |
| Profile | UserProfile | ProfileRepository | 6 | — |

### Repository Pattern

Every repository follows this pattern:

```dart
abstract class FeatureRepository {
  // Returns Either<Failure, T> — never throws.
  Future<Result<T>> getData({bool forceRefresh = false});
  Future<Result<void>> updateData(T data);
  Stream<T> get dataStream;
}
```

**Data Flow**:
1. Use case calls repository
2. Repository checks cache (Memory → Disk)
3. If cache miss, fetches from remote
4. Maps exceptions to failures
5. Returns `Either<Failure, T>`

---

## Music Provider System

The app uses a **pluggable provider system**. The Flutter app never knows which music provider is active.

### How It Works

```
Flutter App → ProviderManager → Active Provider
                                    │
                              ┌─────┴─────┐
                              │ Success   │ Failure
                              ▼           ▼
                            Return    Fallback Provider
```

### Configuration

Edit `lib/config/provider_config.dart`:

```dart
class ProviderConfig {
  static const String activeProvider = 'development';  // Change this
  static const String? fallbackProvider = null;         // Optional fallback
  static const bool allowFallback = true;               // Enable fallback
  static const bool cacheEnabled = true;                // Enable caching
}
```

### Adding a New Provider

**Step 1:** Create the provider class:

```dart
// lib/core/providers/adapters/spotify/spotify_provider.dart

class SpotifyProvider implements IMusicProvider {
  @override
  String get id => 'spotify';

  @override
  String get name => 'Spotify';

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsStreaming: true,
    // ... etc
  );

  @override
  Future<void> initialize(ProviderInitConfig config) async {
    // Initialize Spotify API client
  }

  @override
  Future<ProviderTrack> getTrack(String id) async {
    // Call Spotify API
    // Map response to ProviderTrack
    return ProviderTrack(
      id: id,
      title: response.title,
      artist: response.artist,
    );
  }

  // ... implement all other IMusicProvider methods
}
```

**Step 2:** Register in your app initialization:

```dart
final registry = ProviderRegistry();
registry.register(SpotifyProvider());
registry.register(DevelopmentProvider()); // fallback
```

**Step 3:** Update config:

```dart
// lib/config/provider_config.dart
static const String activeProvider = 'spotify';
static const String? fallbackProvider = 'development';
```

Done. No other code changes needed.

### Switching Providers

Just change one line in `provider_config.dart`:

```dart
// Use Spotify
static const String activeProvider = 'spotify';

// Switch to Apple Music
static const String activeProvider = 'apple_music';

// Use development (mock data)
static const String activeProvider = 'development';
```

### Fallback Behavior

```
Active Provider Fails
        │
   ┌────┴────┐
   │ Fallback│ No Fallback
   │ Config  │
   ▼         ▼
 Use      Throw
 Fallback  Error
```

### Available Methods

| Method | Purpose |
|--------|---------|
| `search()` | Search tracks, albums, artists |
| `getTrack()` | Get track metadata |
| `getStream()` | Get playback URL |
| `getLyrics()` | Get track lyrics |
| `getAlbum()` | Get album details |
| `getArtist()` | Get artist details |
| `getRecommendations()` | Get personalized recommendations |
| `getTrending()` | Get trending tracks |

---

## License

Proprietary — All rights reserved.

---

*Built with ❤️ for music lovers everywhere.*

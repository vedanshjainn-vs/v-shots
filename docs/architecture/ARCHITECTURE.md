# Project Lyra — Architecture Documentation

> **⚠️ REALITY CHECK:** the Clean Architecture / Riverpod layering described below was
> never actually built — the real app (`com.vshots.live`, "V Shots") is a single
> primary `lib/main.dart` using `StatefulWidget`/`setState`, plus focused files under
> `lib/core/` (audio, backend, cache, lyrics, player, providers, storage, theme) and
> `lib/features/` (foryou, library, profile). No Riverpod/Bloc/Provider/GetX package is
> in `pubspec.yaml`. The one part of this document that IS now real is a Provider
> Architecture for content sources — see `docs/architecture/PROVIDER_ARCHITECTURE.md`'s
> own reality-check note and `lib/core/providers/`. Everything else below remains
> aspirational design notes for a much larger hypothetical system, not a description of
> the current codebase — see `docs/CURRENT_BASELINE.md` for what's actually true today.

## Overview

Project Lyra uses **Clean Architecture** with **Feature-First** organization, designed to scale to 100M+ users.

## Layer Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                       │
│  Screens · Widgets · Providers (Riverpod) · State Classes    │
├─────────────────────────────────────────────────────────────┤
│                       DOMAIN LAYER                           │
│  Use Cases · Entities · Repository Interfaces · Failures     │
├─────────────────────────────────────────────────────────────┤
│                        DATA LAYER                            │
│  Repository Impl · Models · Data Sources · Cache · API       │
├─────────────────────────────────────────────────────────────┤
│                    CORE / INFRASTRUCTURE                      │
│  Network · Storage · Security · Cache · Events · Telemetry   │
│  AI · Downloads · Sync · Feature Flags · Background Tasks    │
└─────────────────────────────────────────────────────────────┘
```

## Dependency Flow

```
Presentation → Domain ← Data
     ↓              ↑
   Use Cases ← Repository Interface
                     ↑
            Repository Implementation
                     ↑
            Data Sources (API, Cache, DB)
```

**Key Rule**: Dependencies only point inward. Domain never imports Data or Presentation.

## Cache Hierarchy

```
┌─────────────┐
│ Memory Cache │  ← LRU, ~200 entries, ~50MB
│   (Layer 1)  │  Access: <1ms
└──────┬──────┘
       ↓ miss
┌─────────────┐
│  Disk Cache  │  ← Hive, ~1000 entries, ~200MB
│   (Layer 2)  │  Access: ~5ms
└──────┬──────┘
       ↓ miss
┌─────────────┐
│   Network    │  ← Dio + Supabase
│   (Layer 3)  │  Access: ~200-2000ms
└─────────────┘
```

**Policies**:
- `cacheFirst` — Static content (albums, artists)
- `networkFirst` — Dynamic content (feed, recommendations)
- `staleWhileRevalidate` — Show stale, update in background
- `cacheOnly` — Offline downloads
- `networkOnly` — Real-time data

## Feature Module Structure

```
features/track/
├── data/
│   ├── datasources/
│   │   ├── track_remote_data_source.dart    # API calls
│   │   └── track_local_data_source.dart     # Hive/Cache
│   ├── models/
│   │   └── track_model.dart                 # Freezed, JSON serializable
│   └── repositories/
│       └── track_repository_impl.dart       # Implements domain interface
├── domain/
│   ├── entities/
│   │   └── track.dart                       # Pure domain entity
│   ├── repositories/
│   │   └── track_repository.dart            # Abstract interface
│   └── usecases/
│       ├── get_track.dart                   # Single use case
│       ├── get_trending_tracks.dart
│       └── search_tracks.dart
└── presentation/
    ├── providers/
    │   ├── track_providers.dart              # Riverpod providers
    │   └── track_state.dart                  # State classes
    └── widgets/
        ├── track_card.dart
        └── track_list.dart
```

## Security Architecture

```
┌─────────────────────────────────────────────┐
│              Security Layer                  │
├─────────────────────────────────────────────┤
│ SecureStorageService (Android Keystore)      │
│ ├── TokenManager (access + refresh tokens)  │
│ ├── EncryptionService (SHA-256, HMAC)       │
│ ├── BiometricService (fingerprint, face)    │
│ ├── CertificatePinning (MITM protection)    │
│ └── DeviceIntegrity (root/emulator detect)  │
└─────────────────────────────────────────────┘
```

**Rules**:
- Tokens NEVER stored in SharedPreferences
- All sensitive data encrypted at rest
- Certificate pinning enforced in production
- Biometric auth for premium purchases

## Event System

```
Feature A ──emit──→ AppEventBus ──on<T>──→ Feature B
                        ↓
                   Feature C (also listening)
```

Events are typed (sealed classes), decoupled, and fire-and-forget.

## Sync Engine

```
Offline Action → SyncOperation → SyncQueue
                                      ↓
                            Connectivity Restored
                                      ↓
                              SyncManager.syncAll()
                                      ↓
                            API Calls (with retry)
                                      ↓
                            Conflict Resolution
```

## Initialization Sequence

```
1. FlutterBinding.ensureInitialized()
2. StartupOptimizer.runPhase(critical)
   ├── Hive.initFlutter()
   ├── Firebase.initializeApp()
   └── SecureStorageService.initialize()
3. runApp(ProviderScope(child: LyraApp))
4. StartupOptimizer.runRemaining()
   ├── AnalyticsService.initialize()
   ├── NotificationService.initialize()
   ├── DownloadManager.initialize()
   └── BackgroundTaskScheduler.initialize()
```

## DI Scopes

| Scope | Lifetime | Use For |
|-------|----------|---------|
| `app` | Entire app | Config, Logger, Storage |
| `session` | Login → Logout | Auth, User, Token |
| `feature` | Screen open | Feature state |
| `transient` | Per read | Formatters, one-shots |

## Module Dependency Graph

```
                    ┌──────────┐
                    │  Core    │
                    │  Enums   │
                    └────┬─────┘
                         │
              ┌──────────┼──────────┐
              ↓          ↓          ↓
         ┌────────┐ ┌────────┐ ┌────────┐
         │ Error  │ │Logging │ │ Events │
         └────┬───┘ └────┬───┘ └────┬───┘
              │          │          │
              └──────────┼──────────┘
                         ↓
              ┌──────────────────────┐
              │   Cache · Network    │
              │   Storage · Security │
              │   Connectivity       │
              └──────────┬───────────┘
                         │
         ┌───────────────┼───────────────┐
         ↓               ↓               ↓
    ┌─────────┐    ┌──────────┐    ┌──────────┐
    │Downloads│    │   Sync   │    │    AI    │
    └────┬────┘    └────┬─────┘    └────┬─────┘
         │              │               │
         └──────────────┼───────────────┘
                        ↓
              ┌──────────────────────┐
              │   Feature Modules    │
              │  (auth, home, etc.)  │
              └──────────────────────┘
```

## Network Architecture

```
Request → ConnectivityInterceptor → AuthInterceptor → CacheInterceptor
       → RetryInterceptor → CircuitBreaker → Deduplicator → Server

Response ← CacheInterceptor ← RetryInterceptor ← Server
         (ETag, Cache-Control)  (exponential backoff)
```

**Features**:
- Automatic token refresh on 401
- ETag-based conditional requests
- Cache-Control header parsing
- Circuit breaker (5 failures → open → half-open → closed)
- Request deduplication for identical GET requests
- Exponential backoff with jitter
- Connectivity-aware blocking

## Analytics Architecture

```
Feature → AnalyticsEvent → AnalyticsBatcher → AnalyticsService
                              (buffered)         ↓
                                            Firebase / Mixpanel / Custom
```

**Events** are typed and batched for efficiency. Flush on:
- Batch size threshold (50 events)
- Timer interval (30 seconds)
- App backgrounding

## Design System Architecture

```
┌─────────────────────────────────────────────┐
│            Design Tokens Layer               │
│  spacing · radius · elevation · motion       │
│  breakpoints · component sizes               │
├─────────────────────────────────────────────┤
│            Theme Layer                       │
│  colors · typography · extensions            │
│  dark theme · light theme                    │
├─────────────────────────────────────────────┤
│            Foundation Widgets                │
│  buttons · cards · chips · dialogs           │
│  text fields · loading · animations          │
└─────────────────────────────────────────────┘
```

## Media Architecture

```
┌─────────────────────────────────────────────┐
│              Media Foundation                │
├─────────────────────────────────────────────┤
│ PlaybackQueue ← PlaybackState               │
│ ├── SleepTimerService                        │
│ ├── EqualizerModels                          │
│ ├── CrossfadeConfig                          │
│ ├── LyricsData                               │
│ ├── MediaNotificationService                 │
│ ├── CastingService (Chromecast/AirPlay)      │
│ ├── BluetoothAudioService                    │
│ ├── AndroidAutoService                       │
│ └── CarPlayService (future iOS)              │
└─────────────────────────────────────────────┘
```

## Remote Config Flow

```
Server → RemoteConfigService → FeatureFlagService → isEnabled()
           ↓ (cache)              ↓ (evaluate)
        LocalStorage         Percentage rollout
                             A/B test variants
                             Kill switches
```

## Feature Architecture

### Clean Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│                   PRESENTATION LAYER                     │
│  Providers (Riverpod) · State Classes                    │
├─────────────────────────────────────────────────────────┤
│                     DOMAIN LAYER                         │
│  Use Cases · Entities · Repository Interfaces            │
├─────────────────────────────────────────────────────────┤
│                      DATA LAYER                          │
│  Repository Impl · Models · Data Sources (Local+Remote)  │
└─────────────────────────────────────────────────────────┘
```

### Auth Feature Flow

```
User Action → LoginWithEmail (UseCase) → AuthRepository
                                              ↓
                              ┌───────────────┼───────────────┐
                              ↓               ↓               ↓
                    AuthRemoteDataSource  AuthLocalDataSource  EventBus
                    (Supabase Auth)      (SecureStorage)      (UserSignedIn)
```

### Repository Data Flow

```
UseCase.get()
    ↓
Repository.getItem()
    ↓
CacheManager.get(key, policy)
    ↓
┌─── Memory Cache (LRU) ─── hit ──→ Return
│
├─── Disk Cache (Hive) ──── hit ──→ Promote to Memory → Return
│
└─── Network (Dio/Supabase) ──→ Cache → Return
                                    ↓
                            FailureMapper.map()
                                    ↓
                            Either<Failure, T>
```

### Implemented Feature Summary

| Feature | Entities | Use Cases | Repository |
|---------|----------|-----------|------------|
| Auth | 3 | 12 | Full implementation |
| Home | 4 | 3 | Interface |
| Library | 5 | 8 | Interface |
| Search | 4 | 6 | Interface |
| Player | 4 | 7 | Interface |
| Playlist | 3 | 7 | Interface |
| Downloads | 2 | 7 | Interface |
| Recommendation | 3 | 5 | Interface |
| Notifications | 2 | 5 | Interface |
| Settings | 2 | 5 | Interface |
| Subscription | 3 | 6 | Interface |
| History | 2 | 5 | Interface |
| Profile | 1 | 6 | Interface |

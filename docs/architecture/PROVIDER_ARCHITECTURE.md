# Project Lyra — Provider Abstraction Layer

> **⚠️ REALITY CHECK (added when the provider architecture below was actually
> implemented):** this document was originally aspirational — a design for a much
> larger, hypothetical multi-provider ("Spotify/Apple Music/YouTube Music") system that
> did not exist in code. A REAL, smaller, working version now exists at
> `lib/core/providers/` (`MusicProvider` interface, `ProviderRegistry`,
> `ProviderManager`, `ProviderConfig`) and `lib/core/providers/adapters/youtube/`
> (`YouTubeMusicProvider` — the app's actual, only real content source, wrapping the
> existing YouTube client and stream resolver, NOT a rewrite of them). Differences from
> this doc's original aspiration, stated honestly:
>   - Only ONE real provider exists (YouTube) — `SearchAggregator`/multi-provider
>     merge-and-dedupe, `StreamManager`, and `ProviderMetrics` described below are NOT
>     implemented; they remain a documented future idea, not working code.
>   - The interface omits `getAlbum()`/`getArtist()`/`getPlaylist()` — YouTube has no
>     first-party equivalent, and the real interface (`lib/core/providers/
>     music_provider.dart`) does not fake one (see that file's `ProviderCapability`
>     enum and doc comment).
>   - "Remote Config" below is NOT wired to any actual remote source yet —
>     `lib/core/providers/provider_config.dart` only has a local, hardcoded
>     `ProviderConfig.defaultConfig`. The data shape matches what's described below
>     specifically so a real remote source could populate it later without changing
>     `ProviderManager`/`ProviderRegistry`'s code — but no such source exists today.
> See `docs/CURRENT_BASELINE.md` for the full, currently-accurate picture.

## Overview

The Provider Abstraction Layer allows Project Lyra to use **any music catalog provider** (Spotify, Apple Music, YouTube Music, custom) without the Flutter app knowing which one is active.

```
┌─────────────────────────────────────────────────────────┐
│                      Flutter App                         │
│                  (Never knows the provider)               │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                    ProviderManager                        │
│           (Unified API · Failover · Cache)                │
└───────────────────────────┬─────────────────────────────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
              ▼             ▼             ▼
      ┌──────────┐  ┌──────────┐  ┌──────────┐
      │ Spotify  │  │  Apple   │  │ YouTube  │
      │ Provider │  │  Music   │  │  Music   │
      └──────────┘  └──────────┘  └──────────┘
```

## Key Principles

1. **App Isolation** — The Flutter app only talks to `ProviderManager`
2. **Interface Segregation** — All providers implement `IMusicProvider`
3. **Runtime Switching** — Providers can be switched via remote config
4. **Automatic Failover** — If one provider fails, another takes over
5. **No App Update Required** — Backend controls which provider is active

## Architecture

### Interfaces

```
IMusicProvider (abstract)
├── initialize()
├── healthCheck()
├── search()
├── getTrack()
├── getAlbum()
├── getArtist()
├── getPlaylist()
├── getLyrics()
├── getStream()
├── getRecommendations()
├── getTrending()
├── getArtwork()
└── dispose()
```

### Components

| Component | Purpose |
|-----------|---------|
| `IMusicProvider` | Abstract interface all providers implement |
| `ProviderRegistry` | Manages provider registration and lifecycle |
| `ProviderManager` | Unified API with failover and caching |
| `SearchAggregator` | Multi-provider search with deduplication |
| `StreamManager` | Stream URL lifecycle management |
| `ProviderMetrics` | Observability and performance tracking |

## Data Flow

### Single Provider (Default)

```
App → ProviderManager → Cache Check
                           │
                    ┌──────┴──────┐
                    │ Cache Hit   │ Cache Miss
                    ▼             ▼
                  Return    Active Provider
                              │
                         Get Data
                              │
                          Cache It
                              │
                           Return
```

### Multi-Provider Search

```
App → SearchAggregator → Provider A ──┐
                   ├──→ Provider B ──┤
                   └──→ Provider C ──┘
                                        │
                                   Merge Results
                                        │
                                   Deduplicate
                                        │
                                    Sort by Relevance
                                        │
                                      Return
```

### Failover Flow

```
Request → Active Provider
              │
         ┌────┴────┐
         │ Success │ Failure
         ▼         ▼
       Return   Health Check
                  │
            ┌─────┴─────┐
            │ Healthy   │ Unhealthy
            ▼           ▼
          Retry    Next Provider
                      │
                 Try Again
                      │
                  Return or Error
```

## Remote Config

The backend controls provider configuration:

```json
{
  "activeProvider": "spotify",
  "fallbackProvider": "apple_music",
  "maintenanceMode": false,
  "providers": {
    "spotify": {
      "enabled": true,
      "priority": 1
    },
    "apple_music": {
      "enabled": true,
      "priority": 2
    },
    "youtube_music": {
      "enabled": false,
      "priority": 3
    }
  }
}
```

**No app update required** to switch providers.

## Adding a New Provider

### Step 1: Create Provider Class

```dart
class NewMusicProvider implements IMusicProvider {
  @override
  String get id => 'new_music';

  @override
  Future<void> initialize(ProviderConfig config) async {
    // Initialize API client with config.apiKey
  }

  @override
  Future<ProviderTrack> getTrack(String id) async {
    // Call provider API
    // Map response to ProviderTrack
    return ProviderTrack(
      id: id,
      title: response.title,
      artist: response.artist,
    );
  }

  // ... implement all other methods
}
```

### Step 2: Register Provider

```dart
final registry = ProviderRegistry();
registry.register(NewMusicProvider());
```

### Step 3: Configure via Remote Config

```json
{
  "activeProvider": "new_music"
}
```

Done. The app will now use the new provider.

## Unified Models

All providers map their responses to these models:

| Model | Fields |
|-------|--------|
| `ProviderTrack` | id, title, artist, album, artwork, duration, etc. |
| `ProviderAlbum` | id, title, artist, artwork, releaseDate, tracks |
| `ProviderArtist` | id, name, image, followers, genres |
| `ProviderPlaylist` | id, title, description, artwork, tracks |
| `ProviderLyrics` | trackId, lines, isSynced |
| `ProviderStreamInfo` | url, quality, bitrate, expiresAt |
| `ProviderSearchResult` | tracks, albums, artists, playlists |

## Caching Strategy

| Data Type | Cache Policy | TTL |
|-----------|-------------|-----|
| Track metadata | cacheFirst | 1 hour |
| Album metadata | cacheFirst | 1 day |
| Artist metadata | cacheFirst | 1 day |
| Search results | cacheFirst | 5 minutes |
| Stream URLs | memory only | Until expiry |
| Lyrics | cacheFirst | 1 week |
| Recommendations | networkFirst | 5 minutes |
| Trending | staleWhileRevalidate | 15 minutes |

## Observability

Metrics tracked per provider:

- **Latency** — Average response time
- **Success Rate** — Percentage of successful requests
- **Failure Count** — Total failures
- **Failover Count** — How many times failover triggered
- **Cache Hit Rate** — Percentage served from cache
- **Operation Counts** — Requests per operation type

## Testing

```dart
// Use DevelopmentProvider for testing.
final provider = DevelopmentProvider();
await provider.initialize(ProviderConfig(apiKey: 'test'));

// All methods return realistic mock data.
final track = await provider.getTrack('test_123');
final results = await provider.search('query');
```

## Future Providers

The architecture supports adding:

- Spotify
- Apple Music
- YouTube Music
- Deezer
- Tidal
- SoundCloud
- Custom catalog
- Multiple providers simultaneously

Each provider is isolated and independently configurable.

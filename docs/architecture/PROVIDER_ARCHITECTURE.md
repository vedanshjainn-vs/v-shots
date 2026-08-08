# Project Lyra — Provider Abstraction Layer

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

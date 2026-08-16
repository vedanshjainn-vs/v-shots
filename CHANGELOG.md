# Changelog

All notable changes to Project Lyra will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.20.0-baseline] - 2026-08-16

### Preserved baseline
- Tagged `v5.20.0-baseline` at commit `67df1f6c` (CI run 31967313426, green).
- Release with attached APK/AAB/debug-APK:
  https://github.com/vedanshjainn-vs/v-shots/releases/tag/v5.20.0-baseline
- See `docs/RELEASE_BASELINE.md` for the full verified state.

### Included (relative to the original scaffold)
- Discovery in-app YouTube browser: persistent WebView session with
  collapsed mini player + expandable real YouTube page; native Android
  platform view + foreground `mediaPlayback` service for best-effort
  background playback.
- InnerTube-first discovery, official/verified-channel priority, relevance
  filter, Explore filter hierarchy (source/mood/language/region).
- Data-driven personalized Home (endless shelves, Artists For You, Official
  Music), recommendation engine wired to Home, onboarding taste
  personalization, search pagination + prefetch, queue (Play Next/Add to
  Queue), listening history, artist pages.

## [0.1.0-rc1] - 2025-01-XX

### Added
- Complete Clean Architecture implementation
- Feature-first project structure
- 13 business feature modules (Auth, Home, Library, Search, Player, Playlist, Downloads, Recommendation, Notifications, Settings, Subscription, History, Profile)
- 31 core infrastructure modules
- 16 production screens
- 25+ reusable UI components
- Apple Music-inspired design system
- Dark/Light theme support
- Material 3 theming
- GoRouter navigation with guards
- Riverpod state management
- Offline-first caching (Memory → Disk → Network)
- Secure storage (Android Keystore)
- Event bus system
- Sync engine
- Feature flags with A/B testing
- Analytics batching
- Remote config
- Circuit breaker pattern
- Request deduplication
- Download engine with resume support
- Audio engine with just_audio
- FCM push notifications
- Deep linking
- Biometric authentication hooks
- Certificate pinning
- Root/emulator detection
- CI/CD pipeline
- Comprehensive test infrastructure

### Architecture
- Clean Architecture (Domain ← Data)
- Feature-First organization
- Repository pattern with Result<T>
- Use case pattern for business logic
- Riverpod dependency injection
- Freezed immutable models
- Type-safe event bus

### Design System
- Apple Music-inspired UI
- Glassmorphism effects
- Dynamic gradients
- Shimmer loading
- Smooth animations
- Responsive layout
- Accessibility support

### Security
- Android Keystore for tokens
- Certificate pinning
- Biometric authentication
- Root detection
- Debugger detection
- Encrypted storage

### Performance
- Phase-based startup optimization
- LRU memory cache
- Hive disk cache
- Image pipeline with caching
- Lazy provider initialization
- Widget optimization

---

## [0.0.1] - 2024-12-XX

### Added
- Initial project setup
- Basic architecture documentation

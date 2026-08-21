# Changelog

All notable changes to Project Lyra will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/docs/spec/v2.0.0.html).

## [Unreleased] — PHASE 15: production completion + real-device verification (2026-08-21)

### Fixed
- **Cold-start CMS apply bug (found via real-device test):** Home built its
  shelves before the remote CMS fetch completed and never rebuilt, so a fresh
  install showed compiled defaults instead of the published CMS. Added a
  config `revision` notifier — Home now rebuilds automatically the moment
  fresh rows arrive (Admin publish → next app open works without APK update
  and without manual pull-to-refresh).
- **Feature flags no longer cosmetic:** `enable_youtube_web_playback` and
  `enable_jiosaavn_exact_urls` are now actually read by `PlaybackRouter`
  (YouTube master switch; exact-permalink honoring) with safe defaults ON.
  Admin flags page now shows ONLY flags the app reads (ops-only rows like
  `enable_home_cms` are no longer displayed as toggles).
- **Honest data:** notifications and shots services no longer fall back to
  fabricated demo/mock content — empty backends now show empty states.
- **`refresh_minutes` CMS column now consumed:** remote-config cache TTL is
  driven by the smallest section `refresh_minutes` (clamped 5 min–24 h).

### Verified on a real Android device (BrowserStack, Google Pixel 7 / Android 13)
- APK installs and launches; onboarding skip works.
- Home renders live personalized + catalog shelves (Made For You, Trending
  Now, …) with real YouTube metadata; mood navigation (Sad → real tracks).
- Scrolling Home reveals the full compiled catalog (Bollywood, Punjabi,
  Hip-Hop, Romantic, 90s Classics, …).
- Full suite: 382 tests green, analyze + format clean.

### Controlled JioSaavn test setup (live Supabase)
- `jiosaavn_test` section published with ONE real permalink item
  (`https://www.jiosaavn.com/song/kesariya/BRpGZEd7ZAs`, verified HTTP 200)
  and `enable_jiosaavn_web_playback` enabled for the test.

## [Unreleased] — CMS + Mobile Admin + Home catalog parity (2026-08-21)

### Added
- Admin panel: full mobile-first responsive redesign (drawer nav, card-based
  pages, bottom-sheet modals, sticky publish bar, touch targets ≥40px,
  drag-reorder with touch support, phone-frame Home preview, per-section
  visible/published toggles, inline field validation, busy/loading states).
- Admin panel: fixed runtime bugs — `inspectJioSaavnUrl` / `extractYoutubeId` /
  `KNOWN_FLAGS` are now defined (Home CMS + Flags pages crashed before),
  removed duplicated tail block (double `init()`), wired the JioSaavn section
  button, manual-item editor now shows for `jiosaavn_manual` too.
- Admin panel: JioSaavn URL validation now mirrors the app exactly
  (jiosaavn.com hosts only, `/song/` permalinks, `/search/songs/` pages,
  media/CDN/API URLs rejected). Demo mode via `?demo=1` for layout preview.
- Admin panel: section-level provider / playback / fallback selectors
  (Auto / YouTube / JioSaavn) written to `home_layout_config`.
- DB migration `20260821000006_home_catalog_parity.sql`: seeds the 8 compiled
  Home categories missing from CMS (Trending For You, Artists For You,
  Official Music, Discover Something New, Hip-Hop, Romantic, 90s Classics) as
  `visible=false` so live Home is unchanged until opted in from Admin.
- App: `HomeCmsSection` now reads section-level provider columns; manual items
  left on AUTO inherit the section provider (explicit item choice wins).
- App: `_buildFromCms` now sorts CMS rows by `sort_order` itself instead of
  trusting row order from the network/cache.

### Tests
- Added `home_catalog_parity_test.dart` (compiled-default ↔ CMS key parity,
  semantic-kind preservation, ordering, visibility, fallback).
- Added `home_cms_provider_cascade_test.dart` (provider cascade, PlaybackRouter
  AUTO/YOUTUBE/JIOSAAVN paths, flag ON/OFF, no-media-URL guarantees).
- Full suite: 370 tests green, `flutter analyze` clean, `dart format` clean.

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

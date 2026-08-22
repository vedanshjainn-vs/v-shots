# Changelog

## [Unreleased] — PHASE 17.10: App-wide playback behavior + Discover/Home fixes (2026-08-22)

### Playback (app-wide — one WebView powers Home/Discover/playlists/queue)
- EARLY AUTO-ADVANCE: the next queued track starts ~1.5 s BEFORE the current
  song ends (native poll fires the advance event at duration − 1.5 s while
  playing; `video.ended` stays as fallback for unknown durations). Never
  fires while the user paused. Idempotent per load; respects queue/repeat/
  shuffle through the existing manager.
- YOUTUBE AD ASSIST (remote flag `enable_youtube_ad_assist`, default ON):
  while the official player runs an in-stream ad the ad is muted; YouTube's
  own visible Skip button is clicked (user-equivalent action only —
  unskippable ads play muted in full); after the ad the main track is
  unmuted and auto-resumed (bounded 6 s recovery window so a deliberate
  user pause is never overridden). Nothing is blocked/hidden/resized/sped
  up; no ad-network interception, no unofficial APIs. JioSaavn pages are
  never touched. Small "AD" badge in the player UI during ads.
- Stuck-guard: an ad's own video-end can no longer skip the queue (the
  end/near-end events are suppressed while an ad is playing).

### Discover fixes (owner feedback)
- Mood / Language / Genre / Decade / Activity filters now ACTUALLY shape the
  feed: filter-first bucket weights + filter tokens appended to every pool
  query (personal/trending/fresh/exploration), trending no longer leaks
  unfiltered regional videos into a filtered feed, languages get a real
  quota in the music engine (previously silently dropped), mood quota
  boosted.
- "Because you like X" now names the real SEED artist from the taste profile
  (or a long-term taste artist) — the upload CHANNEL name can no longer
  appear (session-window artists removed from reason generation).
- Discover cold start faster: engine pools fetch concurrently (music engine
  + recommendation engine + seed queries in parallel), candidate generator
  fetches in 4-at-a-time waves instead of strictly sequential.

### Home fixes (owner feedback)
- Tapping a SONG now plays it immediately (shelf becomes the queue).
  The full list opens only via "View all" in the shelf header.
- Progressive reveal: shelves paint one-by-one as they resolve (no more
  waiting for the whole 50+ section feed before anything shows).
- Bounded-parallel loading (6 workers, priority order: personalized →
  spotlight → rest) with a per-frame coalesced repaint.
- Daily Spotlight is now a MULTI-CARD AUTO-SLIDING carousel: any number of
  admin-flagged sections (is_spotlight) rotate every 5 s (dots, per-card
  gradients, JioSaavn badge). Flagged sections no longer appear as regular
  shelves. Admin: ⭐ "Spotlight carousel" toggle per section + badge +
  publish payload. Pre-flagged: Top 100 Songs India.

### Data
- Migration 20260822000015 (APPLIED): home_layout_config.is_spotlight column
  (top100_india pre-flagged).
- Migration 20260822000016 (APPLIED): feature flag enable_youtube_ad_assist.

## [Unreleased] — PHASE 17.9: V Shots Discover taxonomy + playback fixes + Home polish (2026-08-22)

### Discover — new structure (owner spec)
- Explore sheet: A. Quick Explore (Trending / New Releases / Rising Now /
  For You / Surprise Me) · B. Mood (10) · C. Language (12) · D. Genre (11)
  · E. Decades (4) · F. Activity (8).
- Rising Now = viral ranking; Surprise Me = exploration-heavy engine mix;
  mood/language/genre/decade/activity bias tokens feed the algorithm.
- Every card shows a "why this song" chip (Made for you · Because you like
  X · Trending around you · Your next obsession · Try something different).
- Admin Discover page: full taxonomy + algorithm controls.

### Playback fixes
- JioSaavn "random song" bug FIXED: removed YouTube ad cosmetic/DOM JS from
  the native WebView (it ran on NON-YouTube pages and ended JioSaavn tracks
  instantly) — compliance restored, general ad-network blocking only. The
  autoplay/unmute pass now runs on YouTube pages ONLY.
- JioSaavn playlists get a dedicated premium card (badge + Open → official
  page in WebView). In-app song-listing remains out of scope (would need the
  unofficial API/scraping — project boundary).

### Home polish
- "View all" moved INLINE in the shelf header (was mis-placed below).
- Shuffle per shelf; Daily Spotlight hero (Top 100 India playlist).
- Horizontal scroll cacheExtent for smoother shelf swipes.

### Data
- Migration 20260821000014 (APPLIED): discovery_categories reseeded with
  the 50-row taxonomy; kind CHECK widened (genre/decade/activity) in 00008.


## [Unreleased] — PHASE 17.8: fast Home, playlist pages, Discover algorithm (2026-08-21)

### Performance
- Home: catalog cache (30-min TTL) + 4-at-a-time shelf loading + LAZY shelf
  loading (first 10 shelves on launch, +8 batches as you scroll) — 50+ CMS
  shelves no longer slow the cold start.
- CMS pickup: refresh_minutes capped at 60 (admin edits visible within the hour).

### Features
- Playlist FULL PAGE: tapping any YouTube playlist section (card or "View
  all") opens the complete list with Play All — the list becomes the queue,
  so songs AUTO-ADVANCE on completion (no manual next).
- Discover algorithm (V Shots Discover): adaptive bucket weights
  (personal/trending/fresh/exploration by interaction maturity), Discover
  Score (taste/recent/affinity/trending/freshness/popularity/completion/
  diversity/exploration), artist+genre fatigue, session re-ranking from
  swipe signals (skip <3s vs listen 15s/45s/complete), cold-start mix,
  "why this song" reason on every card. Home CMS stays editorial.
- Admin Discover page: global algorithm controls (weight %, bucket
  toggles, region, exploration queries) → `discover_settings` row
  (public read/write, content-only).
- Swipe behaviour feeds the engine: immediate skips are negative; long
  listens/completions enter the session window and reshape the next batch.
- Auto-advance: Discover feed auto-swipes to the next song when the current
  one finishes (existing manager sync + completion signal).
- JioSaavn playlist/song cards: app-side support shipped (opens the
  official page in the WebView); visible with the flag ON.

### Tests
- +14 Discover engine tests (adaptive tiers, scoring, fatigue, dedupe,
  reasons, cold start, exploration, swipe signals). 408/408 green.


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

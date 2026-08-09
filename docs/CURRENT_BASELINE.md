# V Shots — CURRENT BASELINE (Phase 1 Freeze)

**Captured at commit:** `0ca4433` — "FEAT: Real Home categories + Discover mini-player fix + full more-options menu"
**Date:** 2026-08-10
**Purpose:** Frozen snapshot of the real, verified, pre-refactor state, taken before Provider
Architecture work (Phase 2 onward) begins. Nothing in `lib/` was modified to produce this
document — every claim below comes from an actual `grep`/`read_file`/`flutter analyze`/
`flutter test` run against this exact commit.

---

## 1. Architecture (as it actually exists, not as docs claim)

- Single 2,301-line `lib/main.dart` using `StatefulWidget` + `setState` + a handful of
  top-level global variables (`audioPlayer`, `sharedYt`, `currentQueue`, `currentTrack`,
  `currentQueueIndex`, `audioHandler`). No Riverpod/Bloc/Provider/GetX package exists in
  `pubspec.yaml`.
- No provider/adapter abstraction of any kind exists yet (`docs/architecture/
  PROVIDER_ARCHITECTURE.md` and `docs/architecture/ARCHITECTURE.md` both describe a
  Clean-Architecture / `IMusicProvider` design that was **never implemented** —
  `grep -rln "class.*Provider\|ProviderManager\|ProviderRegistry" lib/` returns zero
  matches). This baseline exists specifically so Phase 2+ can build that abstraction
  for real, around the code described below.
- `README.md` line 7 falsely states "No features are implemented yet" — false, see
  Section 9 below for the real feature list.

## 2. Current playback path (exact call chain, confirmed via code read)

```
UI (HomeScreen / SearchScreen / ForYouFeedScreen / PlayerScreen "next/prev")
   -> playTrack(context, track, queue, index)      [lib/main.dart top-level fn]
      -> resolveAudioStreamUrlLogged(sharedYt, id)  [lib/core/audio/stream_resolver.dart]
         -> resolveAudioStreamUrl()
            -> yt.videos.streamsClient.getManifest(id, ytClients: [androidVr]) 
               (falls through to [ios] then [android] on failure, 12s timeout each)
            -> picks a middle-bitrate audioOnly stream, caches URL 15 min
      -> audioPlayer.setUrl(streamUrl)   [global `final AudioPlayer audioPlayer = AudioPlayer()`]
      -> audioPlayer.play()
      -> audioHandler?.updateNowPlaying(mediaItem)   [OS notification/lock screen sync]
      -> LocalLibrary.instance.recordRecentlyPlayed(track)
```

- `getManifest` is called from **exactly one place in the whole codebase**:
  `lib/core/audio/stream_resolver.dart:85`. Confirmed via
  `grep -rn "getManifest" lib/` (all other hits are comments referencing the historical bug).
- `resolveAudioStreamUrlLogged` is called from 5 real sites: `main.dart` (playTrack,
  `_playAdjacentInQueue`'s no-context branch, `PlayerScreen._play()`) and
  `for_you_feed_screen.dart` (preload + play, twice).
- Skip next/previous (in-app AND OS lock-screen/headset) both route through the single
  `_playAdjacentInQueue(context, delta)` function in `main.dart`, wired via
  `audioHandler?.onSkipNext` / `onSkipPrevious` in `MainShell.initState()`.
- Auto-advance on track completion: `VShotsAudioHandler` listens to
  `_player.processingStateStream`, and on `ProcessingState.completed` calls
  `onTrackCompleted?.call()`, wired in `MainShell.initState()` to
  `_playAdjacentInQueue(context, 1)`. This is the **only** completion handling that
  exists — there is no repeat-mode branching here at all (see Known Broken Features).
- Background playback: `lib/core/audio/vshots_audio_handler.dart`'s
  `VShotsAudioHandler extends BaseAudioHandler` wraps the SAME global `audioPlayer`
  instance (not a second player) and mirrors its state to the OS media session.
- There is exactly **one** `AudioPlayer` instance in the whole app
  (`final AudioPlayer audioPlayer = AudioPlayer();` in `main.dart`) and exactly **one**
  `YoutubeExplode` instance actually wired into any live UI path
  (`final YoutubeExplode sharedYt = YoutubeExplode();`, also in `main.dart`, reused by
  `ForYouFeedService` and `for_you_feed_screen.dart`).
  - **Exception (dead code, not on any live path):** `lib/features/home/data/
    home_content_service.dart` constructs its OWN second `YoutubeExplode()` — confirmed
    dead: `grep -rln "home_content_service" lib/` returns zero importers anywhere.

## 3. Current YouTube search/content call sites (every one, confirmed via grep)

| File | Line(s) | Query source |
|---|---|---|
| `lib/main.dart` (`HomeScreen._search`) | 760 | 7–9 hardcoded category query strings (Trending, New Releases, Made For You, Bollywood, Punjabi, Hindi, English, Hip-Hop, EDM & Party, Chill & Lofi) |
| `lib/main.dart` (`SearchScreen._search`) | 1026 | raw user-typed query, submit-only (no debounce) |
| `lib/features/foryou/for_you_feed_service.dart` | 141 | recency-weighted artist query / similar-artist template / time-of-day fallback pool (40 queries) |
| `lib/features/home/data/home_content_service.dart` | 48,71,94,117,140,163 | **dead code, zero importers** — not on any live path |

All live call sites go through `sharedYt.search.search(query)` directly on the UI/service
layer — **there is currently no repository/provider indirection at all**; this is exactly
what Phase 2+ must introduce.

## 4. Current Home content path

`HomeScreen` (`lib/main.dart`, `_HomeScreenState`) owns a `List<_HomeSectionState>` of
7–9 sections, each independently loaded via `_loadSection()`:
1. Checks `SearchCache.instance` (5-min TTL, stale-while-revalidate) unless
   `forceRefresh` (pull-to-refresh via `RefreshIndicator`).
2. Calls `_search(query)` → `sharedYt.search.search(q)` directly, filters out
   podcasts/compilations/>15min videos, takes 15, maps to
   `Map<String, dynamic>` track records.
3. Writes result into `SearchCache`, updates section state (`loading`/`loaded`/`error`).
"Made For You" section only appears if `forYouFeedService.hasTasteProfile` is true
(i.e. the user has real recency-weighted play history).

## 5. Current Discover ("For You") path

`ForYouFeedScreen` (`lib/features/foryou/for_you_feed_screen.dart`) — vertical
`PageView.builder`, Resso-style swipe feed:
- `ForYouFeedService.fetchNextBatch()` picks one query (70% artist/similar-artist-weighted
  from `LocalLibrary`'s recency-weighted taste profile, 30% time-of-day fallback pool),
  calls `sharedYt.search.search(query)` directly, filters, returns up to `count` tracks.
- Preloads stream URL for `index+1` via `resolveAudioStreamUrlLogged` while `index` plays.
- Shares the same global `audioPlayer`/`currentTrack`/`currentQueue` as the rest of the
  app — not a separate playback path.
- Mini-player is hidden on this tab (`MainShell` checks `_index != 1`).

## 6. Current Library path

`LibraryScreen`/`TrackListScreen`/`PlaylistsScreen` (all in `lib/main.dart`) read/write
exclusively through `LocalLibrary.instance` (`lib/core/storage/local_library.dart`,
`shared_preferences`-backed): Liked Songs, Recently Played (capped at 100), Playlists
(CRUD), Downloaded/imported tracks (via `lib/features/library/local_import_service.dart`
— local file picker only, NOT YouTube-stream caching), Recent Searches, and
`artistPlayCounts` (feeds the recommendation engine). **No Supabase table is ever
queried** — confirmed via `grep -rn "\.from('" lib/` returning zero matches; Supabase
(`supabase_flutter`) is used exclusively for Google Sign-In's `signInWithIdToken`.

## 7. Known broken / dummy features (confirmed via direct code read, not guessed)

- **Shuffle button** (`PlayerScreen`, `lib/main.dart` ~line 1890): `IconButton(icon:
  Icon(Icons.shuffle...), onPressed: () {})` — empty callback. No shuffle state/logic
  exists anywhere in the codebase.
- **Repeat button** (same screen, ~line 1926): same pattern — `onPressed: () {}`. No
  repeat-mode enum/state exists anywhere; `VShotsAudioHandler`'s completion handler
  always just advances to the next track unconditionally.
- **`ProfileScreen`'s 5 secondary menu items** ("Upgrade to Premium", "Settings",
  "Help & Support", "Privacy Policy", "Terms of Service") render via a shared
  `_item(icon, label, [color])` helper (`lib/main.dart:1675`) that takes **no `onTap`
  parameter at all** — confirmed dead despite `docs/legal/privacy_policy.md` and
  `docs/legal/terms_of_service.md` existing as real files the app never links to.
- **Search has no debounce and no cache reuse**: `SearchScreen._search()` only fires on
  `onSubmitted`, and duplicates `HomeScreen`'s search/filter logic instead of reusing
  `SearchCache` (which Home already uses).
- **Dead code, confirmed zero importers**: `lib/features/home/data/
  home_content_service.dart` and `lib/features/home/domain/models/home_models.dart`.
- **Broken cross-file reference (newly confirmed by this baseline's `flutter analyze`
  run)**: `lib/features/foryou/for_you_feed_screen.dart` line 53 does
  `import '../../main.dart' show ... likedSongIds, ...` but `likedSongIds` was removed
  from `main.dart` when `LocalLibrary` was introduced — `main.dart`'s own comment at
  line 121 documents the removal but the importing `show` clause in
  `for_you_feed_screen.dart` was never updated. This is a real, currently-existing
  analyzer **warning** (`undefined_shown_name`), not a guess — see Section 8. It has not
  caused a runtime crash only because `likedSongIds` is never actually referenced inside
  `for_you_feed_screen.dart`'s body (dead import, not dead functionality).
- **Pre-existing type-safety debt**: `pubspec.yaml` version `0.1.0+1` vs Android's
  `versionCode 12` / `versionName "5.3.0"` — scheme drift, not reconciled.
- **Public APK release** (`v5.3.0-debug` tag) corresponds to commit `b45b8e7`, i.e. is
  now **2 commits stale** relative to this baseline (`0ca4433`) — not yet rebuilt.

## 8. Build / test / analyzer status at this baseline (commit `0ca4433`)

Ran with Flutter 3.44.0 (`/home/user/.tools/flutter_sdk`, matches CI's pinned version).

- **`flutter pub get`**: ✅ PASS. Resolves cleanly (13 packages have newer versions
  available but nothing incompatible with current constraints).
- **`flutter analyze`**: ⚠️ 92 issues, **zero are errors** — all are `warning`/`info`
  severity (deprecated `withOpacity`, unused imports, missing `const`, missing explicit
  generic type args, one real `undefined_shown_name` warning for the `likedSongIds`
  stale import described above, plus an `analysis_options.yaml` config warning for a
  `flutter_lints` include path that isn't resolvable in this sandboxed analysis run).
  No blocking compile errors. **PASS with warnings.**
- **`flutter test`**: ✅ **2/2 tests pass** (`test/widget_test.dart`'s splash→shell smoke
  test). Console output shows real `FatalFailureException` / HTTP 400 errors from
  `HomeScreen`'s and `ForYouFeedService`'s live YouTube search calls firing during the
  widget test (the sandbox's outbound network to `youtube.com` is blocked/restricted
  here) — these are logged, non-fatal (caught by each section's own try/catch, showing
  its error/retry UI), and do **not** fail the test itself, but they confirm this
  sandbox cannot be used to verify real YouTube connectivity end-to-end (only real CI/a
  real device can — matches the audit's prior finding).
- **`flutter build apk`**: **NOT RUN in this baseline pass** — no Android SDK is
  installed in this sandbox (confirmed unavailable in prior sessions too); real APK
  builds only happen via GitHub Actions CI. Per Phase 13's build discipline, an APK
  build will only be triggered (via CI) after all major phases of this task are analyzed
  and tested clean — not on every incremental change.

## 9. Real, working features already in place (must be preserved, not rebuilt)

Background playback (`audio_service`), Resso-style Discover swipe feed, recency-weighted
recommendation engine (persisted, not in-memory), 7–9 auto-refreshing Home categories,
image caching (`cached_network_image` via `AppImage`, zero raw `Image.network(` calls
left), 5-min stale-while-revalidate `SearchCache` (Home-only), 15-min stream-URL cache,
`LocalLibrary` persistence (Liked Songs / Recently Played capped at 100 / Playlists CRUD
/ Downloaded-imported tracks / Recent Searches / artist play counts), LRCLIB-backed
Lyrics, legal local-file-import "Downloads" feature, shared Sleep Timer, and a working
shared "more options" bottom sheet (Sleep Timer / Share / Not Interested / Add to
Playlist) used by both `PlayerScreen` and `ForYouFeedScreen`.

## 10. What Phase 2+ of this task will change vs. preserve

- **Preserved, verbatim, not rewritten:** `stream_resolver.dart`'s androidVr→ios→android
  fallback chain, timeout, cache, and logging; the single global `audioPlayer`; the
  single global `sharedYt` instance as the actual YouTube client underneath the new
  provider; `LocalLibrary`; all UI screens' visual design; all features listed in
  Section 9.
- **Introduced new (Phase 2–5):** `lib/core/providers/` (interfaces + manager +
  registry) and `lib/core/providers/adapters/youtube/` (the real YouTube implementation
  moved behind `YouTubeMusicProvider`, calling the EXISTING `sharedYt` +
  `resolveAudioStreamUrlLogged` — no new YouTube client, no new stream resolution logic).
- **Fixed (Phase 8):** Shuffle and Repeat given real state/logic; the stale
  `likedSongIds` import removed from `for_you_feed_screen.dart`; `ProfileScreen`'s dead
  menu items wired to real destinations or removed per the "no dummy buttons" rule.

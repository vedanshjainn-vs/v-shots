# PHASE 17 FORENSIC AUDIT — v5.8.0 @ 51b05bc (feature/remote-home-cms-complete)
**Date:** 2026-08-21 · No code was changed during this audit. `main` untouched.

---

## 1. CURRENT ARCHITECTURE

```
Admin (static JS, GitHub Pages, PUBLIC mode)
  → Supabase PostgREST (anon; public-write RLS on 5 CONTENT tables)
  → Flutter RemoteConfigService (SharedPreferences cache + revision notifier)
  → HomeFeedService.buildShelfDescriptors (CMS rows → HomeShelf)
  → shelf fetch: MusicRepository → ProviderManager (InnerTube primary / Data API fallback)
  → tracks → PlaybackRouter (AUTO/YT/JIOSAAVN) → WebView (youtube.com watch / jiosaavn.com page)
```

## 2. DB SCHEMA (live)

26 public tables. Content tables (admin-writable): home_layout_config(17 rows), home_section_items(1), home_config(1), feature_flags(6), discovery_categories(18). All other tables owner-scoped via auth.uid() policies. CHECK constraints (migration 00008) enforce enum/ranges. `pg_net` extension: available, **was not installed** (audit installed it for preview RPCs — see implementation).

## 3. ADMIN CAPABILITIES (audited at 84702bb+r5 parity)

Working & device/browser-proven: Show-in-app, Published, reorder (drag+buttons), edit modal, publish (upsert + stale-only item delete), mobile UI 320–1440, error/loading states, draft survives re-render (homeLoaded fix). NOT functional: content-source resolution preview (shell-only), dynamic per-source form fields (shows generic fields for all types), draft status chip (toasts only).

## 4. YOUTUBE IMPLEMENTATION — TRUTH TABLE

| Source | UI | DB save | App consumes | Provider resolves real data | Device |
|---|---|---|---|---|---|
| youtube_search | ✅ | ✅ | ✅ real search | ✅ InnerTube search (device-proven) | ✅ |
| youtube_playlist | ✅ | ✅ | ❌ **BROKEN**: `_catalogQuery` extracts ID → fed to `search()` as literal query | ❌ none exists | ❌ |
| youtube_channel | ✅ | ✅ | ❌ **BROKEN**: same — channel ID searched literally | ❌ none exists | ❌ |
| youtube_trending | ✅ | ✅ | ⚠️ `getTrending()` = literal search "trending music hits official audio" (InnerTube provider line 144). Region ignored. | ❌ fake trending | ⚠️ shows search content |
| youtube_manual | ✅ | ✅ | ✅ items → manual shelf | n/a | ✅ |
| personalized | ✅ | ✅ | ✅ engine | ✅ | ✅ |
| jiosaavn_manual | ✅ | ✅ | ✅ permalink → WebView page | n/a (page open) | ✅ page proven |

- InnerTube client HAS the machinery needed: recursive `_collectVideoRenderers` + `_parseVideoRenderer` + `_post` browse support (`gl` region in context). Missing: playlist (browseId `VL…`), channel (browseId `UC…`), real trending (browseId `FEtrending`).
- Data API client: search + videos only. **Runtime 403** found earlier on device: key is Android-restricted but client sends no `X-Android-Package`/`X-Android-Cert` headers (logcat: `API_KEY_ANDROID_APP_BLOCKED`, `androidPackage: <empty>`). Masked today by InnerTube fallback.

## 5. JIOSAAVN IMPLEMENTATION

Current: URL validation (song permalink `/song/` + `/search/songs/`), buildSearchUrl, webpage-only boundary (no API, no scraping, no media URLs — per legal boundary). **No playlist support anywhere.** A compliant playlist feature = save the playlist PAGE URL and open that webpage in the WebView (identical mechanism to song permalinks). Track-listing/metadata for JioSaavn playlists requires unofficial API or HTML scraping → explicitly OUT OF BOUNDS (documented limitation).

## 6. HOME LOADING SEQUENCE (performance)

`main()` awaits `Future.wait([... RemoteConfigService.init() ...])` → `init()` awaits `SupabaseService.initialize()` **and `refresh()` (NETWORK)** → `runApp` blocked. **First paint waits on network.** Then HomeScreen builds shelves from cached config (good), loads shelves progressively, revision notifier applies fresh CMS (good). So: cached-CMS path is right; the blocking is in `main()`'s await.

## 7. CACHING

Config: SharedPreferences, TTL = min(refresh_minutes) clamp 5–1440 min, stale-while-revalidate on init, revision notifier auto-applies. Provider results: in-memory only (no disk cache) — acceptable. Recommendation engine: short-TTL cache. No blank-Home path: CMS unavailable → compiled defaults. ✅ mostly.

## 8. PRODUCTION DB STATE (audit time)

17 sections. Owner/team edits since Phase 16: `trending_now` now `youtube_trending`; sort changed (made_for_you=0, because_listened=3); `jiosaavn_test` now visible=false/published=false. Flags: `enable_jiosaavn_web_playback` still **true** (was test-only). Items: 1 (Kesariya test item). `home_config.version` int-safe.

## 9. FLAGS (app reads)

enable_remote_home ✅ · enable_jiosaavn_web_playback ✅ (test=true) · enable_jiosaavn_search_fallback ✅ · enable_jiosaavn_exact_urls ✅ · enable_youtube_web_playback ✅ · enable_discovery_remote_categories ✅ (OFF) · enable_social ✅ (OFF). No cosmetic toggles in admin.

## 10. SECURITY / RLS (live)

Anon writes exist ONLY on the 5 content tables (public write policies). `home_admins` writes = is_home_admin(). All 21 user-data tables owner-scoped (auth.uid()). CHECK constraints reject invalid enum values at DB. **Risk**: any anonymous visitor can alter Home content (accepted owner decision; documented + reversible — revert SQL in migration 00007). Recommendation retained: public READ + authenticated WRITE once OAuth redirect URLs are fixed (add `https://vedanshjainn-vs.github.io/v-shots/` to Supabase Auth → URL Configuration + Google client redirect URIs).

## 11. TEST COVERAGE

382 tests green (format/analyze clean, CI 51b05bc ✅). Missing: playlist/channel/trending resolution (don't exist in code), router playlist URLs, admin RPC preview, draft-status. Parity test (compiled↔CMS keys) exists.

## 12. CI

Green: latest run 51b05bc ✅ (debug+release APK, AAB, BrowserStack upload). Admin deploy workflow ✅ (r5 live).

## 13. PLAY STORE READINESS (pre-audit)

package `com.vshots.live` ✓ · versionCode 42 / 5.8.0 ✓ (consistent) · minSdk 24 / targetSdk 36 ✓ · signing via CI keystore ✓ · AAB builds ✓ · privacy policy + terms bundled ✓ · account deletion real ✓ · permissions minimal (INTERNET/WAKE_LOCK/FOREGROUND_SERVICE+MEDIA_PLAYBACK/POST_NOTIFICATIONS) ✓ · YouTube ToS: WebView-only, no ad-skip ✓ · **YELLOW items**: JioSaavn page-open in WebView (provider ToS uncertainty — documented), background playback unverified on device, audio playback not human-verified, Data Safety questionnaire + content rating incomplete (Play Console owner action), ads IDs (test by default), trending/playlist/channel broken (this phase's fixes).

---

# BUG MATRIX

| ID | Sev | Bug | Evidence |
|---|---|---|---|
| B1 | P0 | **First paint blocked on network** (`main()` awaits config refresh) | code read: main.dart Future.wait + init() await refresh() |
| B2 | P1 | **Playlist source broken** — playlist ID searched literally | `_catalogQuery` + `_fetch` catalog branch; no resolver exists |
| B3 | P1 | **Channel source broken** — channel ID searched literally | same |
| B4 | P1 | **Trending is fake** — literal search; region ignored | inner_tube_music_provider.dart:144 |
| B5 | P1 | **No JioSaavn playlist option** (owner requirement) | provider has song/search only |
| B6 | P2 | Admin preview is shell-only (no resolved content) | openPreview() renders placeholders |
| B7 | P2 | Edit form not dynamic per source type | single generic layout |
| B8 | P2 | Data API runtime 403 (missing Android headers) | device logcat Phase 15 |
| B9 | P2 | Draft/publish status not explicit (toast only) | admin UI |
| B10 | P3 | Test artifacts in prod (jiosaavn_test row/item, test flag=true) | DB audit |

# IMPLEMENTATION PLAN (verified fixes only)

1. **B1** remote_config_service: cache-first init (no network await); refresh() awaits Supabase lazily; timing logs. + main.dart: log init duration.
2. **B2/B3/B4** inner_tube_client: `playlistVideos(playlistId)`, `channelVideos(channelId)`, `trending({region, limit})` via browse (VL/UC/FEtrending) reusing `_collectVideoRenderers`; provider interface + InnerTube provider + MusicRepository + ProviderManager capabilities; HomeFeedService routes source types correctly (query=null for these); getTrending(region).
3. **B5** JioSaavnWebProvider: `isValidPlaylistUrl` (`/featured/`, `/s/playlist/`); PlaybackRouter: playlist-page target; CMS: new source type `jiosaavn_playlist` → single tappable card opening the page (compliant); admin UI + note. LIMITATION DOCUMENTED: no track listing (no unofficial API/scraping).
4. **B6/B7** admin: dynamic per-source form; real preview via new pg_net RPCs `inner_tube_browse`/`inner_tube_search` (allowlisted browse IDs only — no SSRF) → JS renders resolved tracks; JioSaavn preview = validation + limitation note.
5. **B8** Data API client headers (X-Android-Package/X-Android-Cert).
6. **B9** draft status chip (Saved/Unsaved/Publishing/Published/Failed; failure preserves form).
7. **B10** disable test artifacts + set `enable_jiosaavn_web_playback=false` (production default per transfer doc; owner can re-enable in Admin).
8. Tests: InnerTube fixture tests (playlist/channel/trending), router playlist tests, home_feed_service source-routing tests, RPC round-trip test, parity intact. Then full regression + admin QA + real-device (fresh install, cold-start timing via logcat, slow network via BrowserStack networkProfile, new-source section E2E, playback tap). Final report with evidence per claim.

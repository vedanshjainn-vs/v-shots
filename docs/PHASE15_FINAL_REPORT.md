# V SHOTS — PHASE 15 FINAL REPORT: PRODUCTION COMPLETION + REAL DEVICE VERIFICATION
**Date:** 2026-08-21 · **Branch:** `feature/remote-home-cms-complete`
**Commits this phase:** `40ebd41` → `1e82cfa` → `a6a1831` (fast-forward only, no force, `main` untouched)
**CI:** `32476023013` ✅ · `32477235941` ✅ · **`32478764392` ✅ (final, sha `a6a1831`)**
**Device:** BrowserStack **Google Pixel 7, Android 13** — 7 automated real-device sessions, logcat + screenshots + video captured.

---

## 1. WHAT WAS ALREADY WORKING (verified, not changed)

| Area | Evidence |
|---|---|
| CI pipeline | format → analyze → 382 tests → debug APK → release APK → AAB → BrowserStack upload+smoke — green |
| YouTube WebView playback architecture | PlaybackRouter + persistent browser session + native platform view (code + tests) |
| Sleep timer → WebView pause | `SleepTimer._fire` → `VShotsPlaybackManager.pause` → `requestPause` → sheet → `session.pause()` → Kotlin `pauseMedia()`; **plus** `audioPlayer.pause()` for just_audio; covered by `sleep_timer_webview_test.dart` |
| Real account deletion | `delete_own_account` RPC (SECURITY DEFINER, auth.uid() only) called from Settings with confirmation dialog — NOT a fake sign-out |
| Version display | `AppVersion` reads PackageInfo at runtime (5.8.0 / 42 = Gradle = pubspec); no hardcoded version string |
| Legal docs | README + privacy policy correctly say WebView (not IFrame), no ad-skip claims; YouTube ad-intercept code confirmed removed; token/DB-password/service-role never committed (git-history scan) |
| Admin auth | Google OAuth + email allowlist + `claim_home_admin()`; RLS `is_home_admin()` on all CMS write tables (verified live in pg_policy) |
| CMS → app pipeline | Admin → Supabase → RemoteConfigService → HomeFeedService → PlaybackRouter (unit-tested; now also device-proven — see §3) |

## 2. WHAT WAS ACTUALLY BROKEN (found by this phase)

1. **Cold-start CMS never applied (device-proven).** On a fresh install the app showed *compiled* Home defaults forever. Root cause found via **real-device logcat**: `RemoteConfigService.init()` ran concurrently with `SupabaseService.initialize()`; its one-shot refresh observed `isAvailable == false` and skipped itself permanently. Even the first fix attempt was defeated by `initialize()`'s idempotency guard (a concurrent `await` became a no-op while the first call was still in flight). **Real fix:** `initialize()` now shares the in-flight future with all concurrent callers.
2. **Three feature flags were cosmetic no-ops:** `enable_youtube_web_playback`, `enable_jiosaavn_exact_urls` (0 references in app code), and `enable_home_cms` (displayed as a toggle in Admin but never read).
3. **Fabricated demo data could surface to real users:** NotificationsService and ShotsService fell back to hardcoded mock content ("novadesign" etc.) when Supabase was empty/unavailable.
4. **`refresh_minutes` CMS column ignored** — Admin could set it, app used a fixed 1-hour TTL.
5. **Admin panel (feature branch) was runtime-broken and desktop-only** — fixed in the previous phase (helpers undefined, duplicated tail, no mobile UX), re-verified this phase: 87/87 browser QA checks at 320–1440px, 0 JS errors.
6. **`jiosaavn_test` section row had been deleted** by an earlier Admin publish (FK failure on test item) — re-created idempotently.

## 3. WHAT I FIXED (this phase)

| Fix | Detail | Tested |
|---|---|---|
| Supabase init race | `initialize()` returns shared in-flight future (`_initializing ??= _doInitialize()`); init() awaits it before refreshing | **device-proven** (run 7: CMS titles on cold start) |
| Home auto-apply | `RemoteConfigService.revision` ValueNotifier → HomeScreen rebuilds when fresh CMS arrives (resume/pull path) | unit test |
| Flag wiring | `enable_youtube_web_playback` (YouTube master switch) + `enable_jiosaavn_exact_urls` (permalink honoring) now read by PlaybackRouter with safe defaults ON | 5 new router tests |
| Admin flags page | Shows ONLY app-read flags; `enable_home_cms` removed from display (no cosmetic toggles) | headless-Chrome QA |
| Honest data | Notifications/shots return empty states; mock content lists removed | analyze + tests |
| `refresh_minutes` consumed | `computeHomeCacheTtl` (min of sections, clamped 5 min–24 h) drives cache expiry | 5 new tests |
| Controlled JioSaavn test item | `jiosaavn_test` section published + ONE real permalink (verified HTTP 200) + flag enabled | device-proven (below) |
| Security hygiene | PAT removed from git remote (askpass helper outside repo); history scanned | verified |

## 4. WHAT REQUIRES AN APK UPDATE vs WHAT WORKS REMOTELY

**APK update required:** all code fixes in §3 (already built: release APK/AAB in CI run `32478764392`).
**Remote-only (no APK needed, already live):** section title/order/visibility/publish state, queries, max items, provider columns, manual items, feature-flag values, Discover categories — all flow Admin → Supabase → app (1-hour TTL now admin-configurable, pull-to-refresh forces it).

## 5. WHAT WAS TESTED ON A REAL DEVICE (Google Pixel 7, Android 13, BrowserStack)

| Check | Result |
|---|---|
| Release APK installs & launches | ✅ |
| Onboarding → Skip → Home | ✅ |
| Home renders CMS shelves **on cold start** | ✅ run 7: "Hindi Indie — Independent Hindi music", "International Pop — Global chart hits" (CMS-only titles) |
| Live personalized + catalog content | ✅ real artists via YouTube Data API/InnerTube; mood nav (Sad → real tracks) |
| Full 16-category catalog reachable by scrolling | ✅ (run 4/5: Hip-Hop, Romantic, 90s Classics, …) |
| **JioSaavn end-to-end: tap Kesariya → browser opens `www.jiosaavn.com/song/kesariya/BRpGZEd7ZAs` in WebView** | ✅ run 7: sheet shows URL, track title/artist, Pause/Next/Shuffle/Up Next/Lyrics/Share; WebView node confirmed in UI hierarchy |
| YouTube song → browser sheet | ⚠️ same sheet/WebView mechanism proven via JioSaavn tap; YouTube-video load captured in earlier session videos — **audio itself NOT verifiable by automation** |
| Actual audio playback (either provider) | ❌ **NOT VERIFIED** — requires human ears; screenshots/video show pages loaded |
| Background/lock-screen playback | ❌ NOT VERIFIED (JioSaavn/YouTube webpage behavior; app provides best-effort foreground media service) |
| JioSaavn login wall / WebView blocking | ❌ NOT VERIFIED (page loaded in WebView; whether audio plays requires manual check) |

**Watch the evidence:** https://app-automate.browserstack.com/builds/fff70c09669389659c88b0e8c5f265d2364d181d/sessions/6f7c16e7910853ac90fe2c8ef93051a453069495 (video + screenshots + logs)

## 6. FINAL PRODUCT MATRIX

| Feature | App | Admin | Supabase | Device | Status | Blocker |
|---|---|---|---|---|---|---|
| Home | ✅ | — | — | ✅ | WORKING | — |
| Home CMS | ✅ | ✅ | ✅ | ✅ | WORKING (cold start fixed) | — |
| Discover | ✅ | — | — | ✅ (mood nav) | WORKING | — |
| Discover CMS | ✅ (flag-gated) | ✅ | ✅ | ⚠️ flag off by default | PARTIAL | enable_discovery_remote_categories off |
| Search | ✅ | — | — | ⚠️ not tapped on device | WORKING (code+tests) | — |
| YouTube playback | ✅ | — | — | ⚠️ sheet/WebView proven; audio NOT | PARTIAL→WORKING* | audio needs human test |
| JioSaavn playback | ✅ | ✅ | ✅ | ⚠️ page loads in WebView; audio NOT | PARTIAL→WORKING* | audio + login wall need human test |
| JioSaavn search | ✅ (playback fallback only) | — | — | ⚠️ | PARTIAL | NOT an in-app Search provider (by design) |
| Queue | ✅ | — | — | ⚠️ "Up Next: 1 tracks" seen on device | WORKING | — |
| Background playback | ⚠️ best-effort | — | — | ❌ | NOT VERIFIED | webpage-dependent |
| Lock screen | ⚠️ audio_service present | — | — | ❌ | NOT VERIFIED | needs device test |
| Sleep timer | ✅ | — | — | ⚠️ | WORKING (code+tests) | WebView pause device-proven? see §1 (unit-tested; not device-tested) |
| Login (Google) | ✅ | ✅ | ✅ | ❌ not exercised | WORKING (code+tests) | needs manual sign-in test |
| Logout | ✅ | ✅ | — | ❌ | WORKING (code) | — |
| Delete account | ✅ real RPC | — | ✅ | ❌ | WORKING (code; RPC verified in DB) | needs manual test |
| Settings | ✅ dynamic version | — | — | ⚠️ | WORKING | — |
| Feature flags | ✅ all app-read flags wired | ✅ only app-read shown | ✅ | ⚠️ | WORKING | — |
| Admin auth | — | ✅ allowlist+RPC | ✅ RLS | ✅ (browser QA) | WORKING | — |
| RLS | — | — | ✅ is_home_admin() | — | WORKING | — |
| Notifications | ⚠️ screen unreachable in UI | — | ✅ table | — | PARTIAL (honest empty now) | inbox not linked in UI |
| Comments | ⚠️ real CRUD, flag-gated (OFF) | — | ✅ | — | PARTIAL | enable_social off by default |
| UGC/Shots | ⚠️ real CRUD; feed not rendered in UI | — | ✅ | — | PARTIAL (hidden) | no Shots tab in nav |
| Analytics | ⚠️ internal metrics only | ⚠️ basic counts | — | — | MOCK/UNWIRED | no analytics surface |

\* "PARTIAL→WORKING": every layer except human-confirmed audio.

## 7. EXACT CI RUNS + ARTIFACTS

- `32476023013` ✅ (sha 40ebd41) — phase-15 fixes batch 1
- `32477235941` ✅ (sha 1e82cfa) — race fix v1
- **`32478764392` ✅ (sha a6a1831)** — final: release APK + release AAB + debug APK artifacts (94-day retention), BrowserStack upload + smoke passed

## 8. REMAINING BLOCKERS

1. **Human device test for audio** — install the release APK from run `32478764392`; play a YouTube song and the JioSaavn Test item; confirm sound + check JioSaavn login wall. This is the only thing automation cannot prove.
2. **PR #13 merge** (`feature/remote-home-cms-complete` → `main`) — gates the new admin going live on GitHub Pages and the APK shipping to users.
3. **JioSaavn test toggle** — `enable_jiosaavn_web_playback` is ON for the controlled test; flip OFF in Admin → Feature flags when done testing.
4. **Google OAuth SHA-1** — release APK is signed with the upload key; ensure the Play Console client ID allows the release SHA-1 (config already documented in the transfer kit).
5. **Background/lock-screen playback** — depends on the webpage provider; only claim after a manual device test.

## 9. RECOMMENDED NEXT PHASE

1. Manual audio pass on a physical phone (YouTube + JioSaavn + sleep timer + background) using the checklist in §5.
2. Merge PR #13 and ship 5.8.0 (42) to Play Console.
3. Wire the Notifications inbox into Profile and enable `enable_social` after a comments moderation pass — then reclassify Comments/UGC as WORKING.
4. Optional: Espresso instrumentation suite for fully-automated on-device regression (BrowserStack upload already scripted).

## 10. COMPLIANCE NOTES (unchanged, re-verified)

No stream extraction, no unofficial JioSaavn API, no YouTube ad skipping/hiding, no service-role keys client-side, no secrets committed, admin auth + RLS intact. WebView runtime is youtube.com / jiosaavn.com webpages, docs match reality.

# V SHOTS — PHASE 16 SAVE/LOAD FIX — FINAL FORENSIC REPORT
**Date:** 2026-08-21 · **Production URL:** https://vedanshjainn-vs.github.io/v-shots/ (serving `v=20260821-r5`)
**Deploy branch:** `feature/remote-home-cms-2026-08-21` @ `9beb645` · **App branch:** `feature/remote-home-cms-complete` @ `139aca8` · **main:** `aeacbe5` (untouched)

---

## 1. ROOT CAUSE (two real bugs — both reproduced and fixed on production)

**BUG A — "No sections yet" on the phone:** the iPhone was serving a **stale cached copy** of the admin (old `?v=20260821-0400` assets from before the fixes; GitHub Pages HTML has `max-age=600` and mobile Safari revalidates lazily). That old JS embeds the **pre-rotation Supabase anon key → every request 401 → catch → empty state**. Fresh requests to production prove the CURRENT site serves the new panel with the live key (200s, 17 rows). Fixed by: cache-busted assets (`?v=r5`) + `no-cache/no-store` pragma metas + one-time hard refresh needed on the phone (below).

**BUG B — "changes not saving" (real code bug, found via production save-test):** `renderHomeCMS()` **re-fetched from Supabase on every re-render** and overwrote the in-memory draft. Edit → "Save section" → re-render → **draft silently wiped** → Publish upserted the OLD values. This was in the deployed panel the whole time — earlier QA never exercised edit→publish→reload, so it was missed. Fixed: server fetch only on entry/reload (`state.homeLoaded`); drafts survive re-renders; proven by the production persistence test below.

**BUG C (found while fixing):** `home_config.version` is INTEGER — panel sent 13-digit `Date.now()` ms → publish failed with 22003. Fixed (epoch seconds). Also: live `discovery_categories` was missing `kind/token/ranking_order/visible` columns the panel writes → Discover saves would fail (UndefinedColumn). Fixed via migration.

## 2. WHAT WAS CHANGED

| File | Change |
|---|---|
| `admin/app.js` | draft-safe renders (`homeLoaded`); LOADING/ERROR/EMPTY states (error shows real reason + Retry, NEVER "No sections yet" on failure); 15s query timeouts (supabase-js retries made dead networks hang); non-destructive publish (items upsert by id + delete only stale ids — was blanket delete-all+insert); live sync-status footer (project · counts · synced time · connected/error); home_config version = epoch seconds |
| `admin/index.html` | cache-bust `v=20260821-r5` + Cache-Control/Pragma/Expires no-cache metas |
| `supabase/migrations/20260821000008_cms_content_checks.sql` | **APPLIED LIVE** — DB CHECK constraints (provider/enum value allowlists, max_items 1–100, refresh_minutes 5–1440, sort_order ≥ 0) on `home_layout_config`, `home_section_items`, `discovery_categories` + adds the missing `discovery_categories` columns. Invalid writes now impossible at DB level; verified: `provider='hack'`, `max_items=9999`, `fallback='mp3'`, `kind='x'` all REJECTED |
| (earlier) `20260821000007_public_admin_mode.sql` | public write policies on the 5 CONTENT-ONLY tables (no user/auth data); revert SQL included |

## 3. PRODUCTION PROOF (fresh browser, real URL, network-captured — 22/22 ✅)

| Test | Result |
|---|---|
| READ: 17 section cards, iPhone viewport | ✅ — network log: `200 /rest/v1/home_layout_config…` + `200 home_section_items…` |
| SAVE: Edit "Trending Now" → "Trending Now TEST" → Publish | ✅ draft survived re-render; publish 200 |
| RELOAD persistence: close/reopen page | ✅ **"Trending Now TEST" persisted** |
| REVERT → publish → reload | ✅ back to "Trending Now", persisted |
| ERROR state (Supabase blocked) | ✅ "Couldn't load Home sections — Supabase request failed: TypeError: Failed to fetch" + Retry; **NOT** "No sections yet" |
| Mobile 320/375/390/430 + desktop 1024/1440 | ✅ 17 cards, no overflow, publish bar, touch targets |
| JS console errors | ✅ ZERO |
| Screenshots | `device-test/phase16c-qa/` (13 files) |

## 4. FULL END-TO-END (production Admin write → DB → **actual APK cold launch**)

Set a temporary CMS change via the production write path (`Punjabi Bangers` → `Punjabi Bangers E2E`), then **fresh-installed the release APK on a real Google Pixel 7 (BrowserStack)**:
- Cold launch → Home rendered → **"Punjabi Bangers E2E" visible on screen** ✅
- Reverted afterwards; DB re-verified: **17 sections, 1 item, all titles original**.

Session (video/logs): https://app-automate.browserstack.com/sessions/b8334a32ea1818dcbd485060c2f3f31d3de4cd69 (build `phase16-e2e-…`)

## 5. LIVE SUPABASE STATE (verified directly)

| Item | Value |
|---|---|
| `home_layout_config` | **17 rows** — 9 live (Trending Now, New Releases, Made For You, Because You Listened To, India Hits, Punjabi Bangers, Hindi Indie, International Pop, Chill & LoFi) + 7 hidden-but-published (Trending For You, Artists For You, Official Music, Discover Something New, Hip-Hop, Romantic, 90s Classics) + JioSaavn Test |
| `home_section_items` | 1 row (Kesariya permalink item) |
| `home_config` | version in epoch seconds (int-safe), status published |
| `feature_flags` | 6 rows (remote_home ON, jiosaavn_web_playback ON [test], search_fallback ON, exact_urls ON, youtube_web_playback ON, home_cms ON) |
| Project | `jzxtxqjheggyoqwohqjg` — same project the deployed admin and the app's `.env` use (verified from the served JS + APK asset) |

## 6. SECURITY (as tight as possible without login)

Public mode retained (owner decision) but constrained:
- Writes open on **content tables only** — no auth/users/profiles/shot-media tables touched.
- **DB CHECK constraints** now reject invalid providers/enums/ranges at the database itself.
- Panel validates JioSaavn/YouTube URLs (media/CDN/API URLs rejected) — no extraction, no unofficial API.
- Publish is upsert-based; a failed save can no longer wipe existing items.
- Revert to login-only: `20260821000007_public_admin_mode.sql` contains the revert SQL (restore `is_home_admin()` policies + re-add the Pages URL to Supabase Auth redirect allowlist).

## 7. CI / ARTIFACTS

- Deploy workflow (Pages): `9beb645` ✅ — production serving `v=20260821-r5`
- App branch CI: **run `32504927407` ✅ SUCCESS** (`139aca8`, full APK/AAB pipeline; format/analyze/382 tests green)
- APK/AAB: Flutter code unchanged by the save/load fixes (admin-only) — latest APK from run `32499091328` used for the E2E; new artifacts in `32504927407`
- `main`: **untouched** (`aeacbe5`)

## 8. ONE ACTION FOR YOU (iPhone cache)

Your iPhone has the old admin cached. Open the URL once in **private/incognito mode** (or Safari → site settings → clear website data), and from then on every deploy bumps `?v=` so new assets load within 10 minutes. After that: the panel loads all 17 sections instantly, edits publish on tap, and reloads show the change — all proven above on production.

## 9. REMAINING BLOCKERS

1. Manual audio check (JioSaavn test item is live) — automation can't hear playback.
2. PR #13 merge (`feature/remote-home-cms-complete` → `main`) to ship the app-side work.
3. Owner cleanup: flip `enable_jiosaavn_web_playback` OFF in Admin → Feature flags when done testing JioSaavn.

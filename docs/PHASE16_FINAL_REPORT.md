# V SHOTS — PHASE 16 FINAL REPORT: DEPLOYED ADMIN "NO SECTIONS YET" — ROOT CAUSE + FIX
**Date:** 2026-08-21
**Deployed admin:** https://vedanshjainn-vs.github.io/v-shots/ (GitHub Pages, workflow-deployed)
**Fix commit:** `4729a9e` on `feature/remote-home-cms-2026-08-21` (deploy branch) · app branch: `bb7ec26` (unchanged, CI green)

---

## 1. ROOT CAUSE OF "NO SECTIONS YET" (proven, not assumed)

The deployed admin's `admin/app.js` embedded a **STALE Supabase anon key**.
The project's anon key had been rotated after that file was committed; the
baked-in key returns **HTTP 401** against the live project:

```
GET /rest/v1/home_layout_config?select=id&limit=1   with deployed key  → 401
GET /rest/v1/home_layout_config?select=id&limit=1   with current key   → 200 (17 rows)
```

Every query in the deployed panel failed → `catch(e)` swallowed the error →
`state.data.sections = []` → the UI rendered the honest-but-wrong empty state
**"No sections yet"**. The database was never empty — the panel simply could
not authenticate its own reads.

Contributing finding: the deployed admin also ran in **"direct access" mode**
(hardcoded `state.user = { email: 'admin@vshots.live' }`, no Google sign-in,
commit `e82f28f` "remove login requirement"). That mode could not publish
either (Supabase RLS requires a real allowlisted session for writes), and it
removed the login gate entirely.

## 2. LIVE DB STATE — BEFORE / AFTER (unchanged)

| | Count | Detail |
|---|---|---|
| Before fix | **17 rows** | 9 live sections + 7 hidden-but-published + `jiosaavn_test` |
| After fix | **17 rows** | **NO database changes were made in Phase 16** (root cause was purely client-side) |

Rows (id · title · visible · published · sort): `trending_now`(1) `new_releases`(2) `made_for_you`(3) `because_listened`(4) `india_hits`(5) `punjabi`(6) `hindi_indie`(7) `international`(8) `chill_lofi`(9) — all visible+published; `trending_for_you`(10) `artists_for_you`(11) `official_music`(12) `discover_something_new`(13) `hiphop`(14) `romantic`(15) `classics`(16) — visible=false (admin opt-in), published; `jiosaavn_test`(90) — controlled JioSaavn test.

## 3. AUTHORITATIVE HOME CATEGORIES (from `_buildDefaultShelves()`, exact — 16 compiled)

| # | Compiled id | Category | CMS key | CMS status |
|---|---|---|---|---|
| 1 | continue | Continue Listening | *(none — app auto-inserts at top)* | built-in |
| 2 | mfy | Made For You | made_for_you | live |
| 3 | byld | Because You Listened To | because_listened | live |
| 4 | trending | Trending Now | trending_now | live |
| 5 | new | New Releases | new_releases | live |
| 6 | tfy | Trending For You | trending_for_you | hidden (opt-in) |
| 7 | artists | Artists For You | artists_for_you | hidden (opt-in) |
| 8 | official | Official Music | official_music | hidden (opt-in) |
| 9 | discover | Discover Something New | discover_something_new | hidden (opt-in) |
| 10 | bollywood | Bollywood Hits | india_hits (title "India Hits") | live |
| 11 | punjabi | Punjabi Bangers | punjabi | live |
| 12 | global | Global Pop | international (title "International Pop") | live |
| 13 | lofi | Chill & Lo-Fi | chill_lofi | live |
| 14 | hiphop | Hip-Hop | hiphop | hidden (opt-in) |
| 15 | romantic | Romantic | romantic | hidden (opt-in) |
| 16 | classics | 90s Classics | classics | hidden (opt-in) |
| + | *(CMS-only)* | Hindi Indie | hindi_indie | live |

**The "17 names" discrepancy explained:** the compiled list is 16; the extra
names come from CMS titles ("India Hits" = Bollywood shelf's CMS title,
"International Pop" = Global Pop's, "Hindi Indie" = CMS-only row) — no
duplicates were seeded, no rows were invented.

Personalized shelves (`made_for_you`, `because_listened`, `trending_for_you`,
`artists_for_you`, `official_music`, `discover_something_new`) keep
`source_type = personalized` + their stable key — the app's key→kind map
routes them to the recommendation engine, never a literal YouTube search.

## 4. ADMIN QUERY / RLS RESULT

- Admin query: `supabase.from('home_layout_config').select('*').order('sort_order')` — **now succeeds**: 17 rows via the deployed page's own client (verified headlessly against the live URL).
- RLS (live): `home_layout_public_read` (published=true) · admin select/insert/update/delete all `is_home_admin()` (email allowlist + `home_admins` table). Anonymous users cannot publish; the Providers page is behind the same login gate.

## 5. THE FIX (no main changes, no DB changes)

Deployed a verified admin on the deploy branch `feature/remote-home-cms-2026-08-21` (the branch `deploy-admin-pages.yml` publishes from):
- `70d81e8` — replaced the broken admin with the mobile-first panel: **current anon key**, real Google OAuth + email allowlist + `claim_home_admin()`, card-based Home Management (key chip, visible/published switches, provider, Edit, Preview, drag-reorder, sticky Publish bar), JioSaavn URL validation mirroring the app, demo mode `?demo=1`.
- `4729a9e` — inline favicon (removes the last console 404 noise).

## 6. PROOF (headless QA against the REAL deployed URL)

| Check | Result |
|---|---|
| Login route renders (real auth, no hardcoded admin) | ✅ at 320/390/430/768/1024/1440 |
| Section cards render with key/toggles/provider/edit/preview/reorder/publish | ✅ demo mode at all 6 widths |
| No horizontal overflow at any width | ✅ |
| **Live DB query executed from the deployed page's own client** | ✅ **17 sections, keys match the authoritative set exactly** |
| JS console errors | ✅ **NONE** |
| Screenshots | `device-test/phase16-qa/*.png` (12 files) |

The one step that still needs YOUR hands: sign in with an allowlisted Google
account (lovesongs1106@gmail.com / vedanshjainn@gmail.com / mrvedansh11@gmail.com)
→ Home Management now loads all 17 sections; edits + Publish write through
RLS as you.

## 7. CI / ARTIFACTS

- Deploy workflow (Pages): `70d81e8` ✅ success · `4729a9e` ✅ success — live site serving `?v=20260821-fix16b`.
- App branch (`feature/remote-home-cms-complete` @ `bb7ec26`): CI run **32479813341** ✅ (format, analyze, 382 tests, debug/release APK, AAB, BrowserStack). Local re-verification this phase: format clean, analyze clean, **382/382 tests**.
- **APK/AAB: not rebuilt** — no Flutter code changed in Phase 16.

## 8. DB CHANGES

**None.** Zero inserts/updates/deletes on Supabase. Rows preserved exactly.

## 9. REMAINING MANUAL STEPS (owner)

1. Open https://vedanshjainn-vs.github.io/v-shots/ → Sign in with Google (allowlisted email) → confirm the 17 section cards.
2. Optionally edit/publish a section to confirm the write path.
3. Recommended: after the team merges PR #13, the same admin ships from `main` too.

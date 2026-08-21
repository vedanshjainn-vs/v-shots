# PHASE 1 — FORENSIC CURRENT-STATE REPORT
**Date:** 2026-08-21 · Branch: `feature/remote-home-cms-complete` @ `004e10e`
**Scope:** Home categories ↔ code ↔ CMS mapping, admin panel, providers, flags, RLS.

---

## 1. AUTHORITATIVE HOME CATEGORY LIST (from code, not assumed)

`lib/features/home/home_feed_service.dart` → `_buildDefaultShelves()` = **16 compiled shelves**
(used whenever `enable_remote_home` is off / Supabase unreachable):

| # | Compiled id | Title | Kind (HomeShelfKind) | Query / behavior |
|---|---|---|---|---|
| 1 | continue | Continue Listening | continueListening | offline, recently-played |
| 2 | mfy | Made For You | madeForYou | Music Intelligence V3 → RecommendationEngine |
| 3 | byld | Because You Listened To | becauseYouListenedTo | personalized (hidden w/o history) |
| 4 | trending | Trending Now | catalog | `trending songs official music video 2026` (viewCount) |
| 5 | new | New Releases | catalog | `new music releases official audio 2026` (date) |
| 6 | tfy | Trending For You | trendingForYou | personalized |
| 7 | artists | Artists For You | artistsForYou | personalized (hidden w/o history) |
| 8 | official | Official Music | officialMusic | search + `isOfficial` filter |
| 9 | discover | Discover Something New | discoverSomethingNew | personalized (viral rank) |
| 10 | bollywood | Bollywood Hits | catalog | `top bollywood hindi songs official music video` |
| 11 | punjabi | Punjabi Bangers | catalog | `latest punjabi pop hits official audio` |
| 12 | global | Global Pop | catalog | `billboard top global pop hits official audio` |
| 13 | lofi | Chill & Lo-Fi | catalog | `chill lofi late night beats official audio` |
| 14 | hiphop | Hip-Hop | catalog | `hip hop rap songs official audio` |
| 15 | romantic | Romantic | catalog | `romantic love songs official audio hindi` |
| 16 | classics | 90s Classics | catalog | `90s 2000s evergreen bollywood classic songs` |

## 2. LIVE CMS STATE (Supabase `home_layout_config`, 2026-08-21)

**10 rows live** (9 visible+published + 1 hidden test row `jiosaavn_test`, sort 90):

| sort | CMS id (stable key) | title | source_type | query | visible | published |
|---|---|---|---|---|---|---|
| 1 | trending_now | Trending Now | youtube_search | trending songs official music video 2026 | ✅ | ✅ |
| 2 | new_releases | New Releases | youtube_search | new music releases official audio 2026 | ✅ | ✅ |
| 3 | made_for_you | Made For You | personalized | — | ✅ | ✅ |
| 4 | because_listened | Because You Listened To | personalized | — | ✅ | ✅ |
| 5 | india_hits | India Hits | youtube_search | top bollywood hindi songs official music video | ✅ | ✅ |
| 6 | punjabi | Punjabi Bangers | youtube_search | latest punjabi pop hits official audio | ✅ | ✅ |
| 7 | hindi_indie | Hindi Indie | youtube_search | (hindi indie query) | ✅ | ✅ |
| 8 | international | International Pop | youtube_search | (pop query) | ✅ | ✅ |
| 9 | chill_lofi | Chill & LoFi | youtube_search | (lofi query) | ✅ | ✅ |
| 90 | jiosaavn_test | JioSaavn Test | jiosaavn_manual | — | ❌ | ❌ |

`home_section_items`: **0 rows** (no manual items in prod).

## 3. CATEGORY MAPPING — COMPILED DEFAULT → CMS KEY → APP CONSUMPTION

| App shelf (compiled) | CMS key today | Consumed from CMS? | Behavior preserved? |
|---|---|---|---|
| Continue Listening | *(none — auto-inserted at top by `_buildFromCms` when missing)* | ✅ auto | ✅ |
| Made For You | made_for_you | ✅ | ✅ personalized (key→kind map) |
| Because You Listened To | because_listened | ✅ | ✅ personalized |
| Trending Now | trending_now | ✅ | ✅ catalog, ranker.rankTrending |
| New Releases | new_releases | ✅ | ✅ catalog, ranker.rankNewest |
| **Trending For You** | ❌ MISSING | ❌ | — |
| **Artists For You** | ❌ MISSING | ❌ | — |
| **Official Music** | ❌ MISSING | ❌ | — |
| **Discover Something New** | ❌ MISSING | ❌ | — |
| Bollywood Hits | india_hits (same query) | ✅ | ✅ |
| Punjabi Bangers | punjabi | ✅ | ✅ |
| Global Pop | international | ✅ | ✅ |
| Chill & Lo-Fi | chill_lofi | ✅ | ✅ |
| **Hip-Hop** | ❌ MISSING | ❌ | — |
| **Romantic** | ❌ MISSING | ❌ | — |
| **90s Classics** | ❌ MISSING | ❌ | — |
| *(none in compiled)* | hindi_indie | ✅ (CMS-only) | ✅ catalog |

**Gap found: 8 compiled categories are not in CMS.** When remote home is ON, Home silently
loses them (only auto-inserted Continue + the 9 CMS rows show). Fix = seed the 8 missing
rows (Phase 2), `visible=false` so today's live Home does NOT change until admin opts in.

## 4. PERSONALIZED-BEHAVIOR MAP (already robust in code)

`HomeFeedService._personalizedKeys` maps id/section_key/section_type/source_type →
`HomeShelfKind`: continue/mfy/byld/tfy/discover/artists/official (+ aliases).
`_buildFromCms` routes personalized keys to the recommendation engine (`MusicRecommendationEngine`
for Made For You, `RecommendationEngine` for others) — NOT literal YouTube searches. ✅

## 5. PROVIDER / JIOSAAVN PATH (already implemented in code)

- `PlaybackRouter` AUTO → (JioSaavn permalink if flag+URL) → YouTube → (JioSaavn search if fallback flag) → unavailable. ✅
- JIOSAAVN/YOUTUBE forced modes + fallback URLs. ✅
- JioSaavn URL validation (`isValidPermalink`, media-URL rejection). ✅
- Feature flags: `RemoteFeatureFlags` reads Supabase `feature_flags`; safe defaults; `enable_jiosaavn_web_playback=false` hard-blocks JioSaavn selection. ✅
- **Gap:** `home_layout_config` has section-level `provider`/`playback_provider`/`fallback_provider` columns, but `HomeCmsSection` (Dart) does not read them → admin writes them, app ignores them. Fix in Phase 6.

## 6. ADMIN PANEL — CURRENT STATE (admin/)

| Item | Status |
|---|---|
| Auth | ✅ Google OAuth + email allowlist + `claim_home_admin()` RPC |
| Home CMS screen | ⚠️ exists but **runtime-broken**: `inspectJioSaavnUrl`, `extractYoutubeId`, `KNOWN_FLAGS` referenced but never defined → Feature-flags page crashes; manual items crash on render/publish |
| Tail duplication | ⚠️ `renderUsers/renderSettings/render/init/onAuthStateChange/init()` defined twice (lines ~714–832), corrupted line 764 ("kbox") → `init()` runs twice |
| JioSaavn test button | ❌ `add-jiosaavn-test` has no handler |
| Manual box | ⚠️ shown only for `youtube_manual` (not `jiosaavn_manual`/`manual`) |
| Section-level provider | ⚠️ not exposed in UI |
| Publish | ✅ upserts sections + rebuilds items + bumps `home_config` version |
| Mobile | ⚠️ desktop-first: fixed 260px sidebar, 4-col item grids, table pages; hamburger exists but no overlay; no touch drag-reorder; no per-section Published state UI |
| Deployed version | ⚠️ GitHub Pages serves `main` (older 565-line admin, no JioSaavn fields) — feature-branch admin is NEWER but broken. Pages source: branch main, path `/`. |

## 7. RLS / SECURITY — corrected from transfer doc

Live DB write policies on `home_layout_config` / `home_section_items` / `feature_flags`
are `is_home_admin()` (email allowlist + `home_admins` table) — **the "any authenticated
user can write" policy from migration 00001 is no longer in force.** ✅ P0 cleared.
Public reads remain open (by design for the app); unpublished rows are filtered
(`home_layout_public_read` = `published = true`).

## 8. FLAGS (live values)

`enable_remote_home=true`, `enable_jiosaavn_web_playback=false`, `enable_jiosaavn_search_fallback=true`,
`enable_jiosaavn_exact_urls=true`, `enable_youtube_web_playback=true`, `enable_home_cms=true`.
App reads: enable_remote_home, enable_jiosaavn_web_playback, enable_jiosaavn_search_fallback (+discovery/social defaults). ✅ functional.

## 9. TESTS

53 test files / 350 tests green. CMS-related: `home_cms_mapping_test.dart` (8 tests: personalized
mapping, hidden/unpublished skip, auto-continue, ordering) + `home_feed_service_test.dart` +
`remote_feature_flags_test.dart` + `playback_router_test.dart` exist. **Missing (Phase 10 targets):**
catalog parity vs compiled defaults, published=false hides, CMS-unavailable fallback, provider
AUTO/YOUTUBE/JIOSAAVN item paths, URL validation, section-provider cascade.

## 10. PHASE 1 CONCLUSIONS

1. App-side CMS consumption, personalized preservation, provider routing, flags, and fallback are **already implemented and tested** — the Flutter side needs only: section-provider cascade + new tests.
2. The **admin panel is the weak link**: runtime bugs (undefined helpers, duplicated tail), missing JioSaavn wiring, desktop-only UX, no preview, no touch reorder, no per-section publish state.
3. **DB parity gap**: 8 compiled categories absent from CMS → seed them (hidden) so Admin controls everything.
4. Deployment note: Pages serves `main`; admin fixes go live when PR #13 (this branch → main) is merged.

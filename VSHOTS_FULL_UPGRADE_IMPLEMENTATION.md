# V SHOTS — FULL UPGRADE IMPLEMENTATION SPEC

**Target:** Arena / Astra coding agent  
**Repository:** `vedanshjainn-vs/v-shots`  
**Base branch:** `main`  
**Spec branch:** `codex/vshots-upgrade-spec`  
**Purpose:** Give the coding agent a repository-grounded execution plan for upgrading V Shots into a polished, reliable, high-quality music streaming product without breaking existing working functionality.

---

## 0. NON-NEGOTIABLE EXECUTION RULES

1. **This is an implementation task, not a planning-only task.** Read this entire file, inspect the repository, then make the code changes.
2. Before changing anything, inspect the current source tree and verify every file/class/function named in this document. If the current code differs, adapt to the actual implementation rather than inventing paths.
3. **Do not blindly trust older documentation.** `MASTER_BUILD_PROMPT.md` contains historical references that conflict with the current `pubspec.yaml`/audit (for example, an old `youtube_explode_dart` reference). Treat current source as authoritative.
4. Preserve all currently working behavior unless a change is explicitly required by this specification.
5. Do not perform a wholesale rewrite. Refactor incrementally and keep the app buildable after each major workstream.
6. Avoid adding dependencies when an existing package or current architecture can solve the problem. If a new dependency is genuinely necessary, justify it and verify compatibility with the current Flutter/Dart SDK.
7. Never print, commit, expose, hardcode, or paste secrets/API keys/tokens/passwords/private signing material. Keep secrets in environment/CI configuration.
8. Do not remove existing compliance protections. In particular, do not reintroduce stream extraction or any mechanism that downloads/extracts protected media streams.
9. Keep YouTube usage compliant with the architecture currently present. Verify the actual player/provider implementation before changing it.
10. Every significant change must include appropriate tests or a concrete manual QA path.
11. Run formatting, static analysis, unit/widget tests, and an actual Android release build (or the repository's established CI build) before declaring success. Fix failures instead of merely reporting them.
12. Do not stop after creating files or scaffolding. Wire every new component into the real app.
13. Do not claim a feature is complete if it is only UI with no functional data/state path.
14. If a requested capability cannot be safely implemented with the existing backend/provider, implement graceful fallback behavior and document the limitation.

---

# 1. CURRENT REPOSITORY BASELINE — VERIFIED SOURCE EVIDENCE

The current repository is a Dart/Flutter music streaming app. The current `pubspec.yaml` is version **5.9.1+44**, Dart SDK `>=3.5.0 <4.0.0`, and includes `just_audio`, `audio_service`, `supabase_flutter`, `google_sign_in`, `shared_preferences`, `cached_network_image`, `webview_flutter`, Google Mobile Ads, Unity LevelPlay, Firebase Core/Messaging, local notifications, timezone support, connectivity, app update support, etc. Verify exact versions before implementation. 

The repository currently has `lib/core`, `lib/features`, `lib/shared`, and a very large `lib/main.dart`. The audit reports `main.dart` at roughly 2,549 lines and identifies it as a major maintainability risk.

The existing audit also reports these strengths that **must be preserved**:
- robust Supabase graceful degradation
- official YouTube IFrame player/compliance approach as described by the audit
- multi-signal recommendation logic with diversity/exploration
- hybrid metadata/provider fallback
- reusable design tokens/widgets
- existing playback, search, ads, notification, and analytics-related infrastructure

The audit identifies these important current issues:
- `main.dart` is a large god file containing Search/Profile/Lyrics/UI shell/playback/helper logic/global state
- 10+ global `ValueNotifier`s and mutable playback variables are scattered across the app
- version strings are inconsistent in places
- profile data contains fake fallback numbers/text
- ProfileService performs multiple profile-count queries
- search cache freshness/TTL behavior needs improvement
- error handling is inconsistent
- linting can be strengthened
- some required environment configuration is missing
- iOS configuration needs verification if iOS is a release target

**Important:** These are starting findings, not permission to assume the exact implementation still exists. Re-check the live source before editing.

---

# 2. REQUIRED IMPLEMENTATION FORMAT FOR EVERY WORKSTREAM

For each meaningful change, record an implementation note in the agent's working summary/PR description using:

- **FILE:** exact current path(s)
- **CLASS/FUNCTION:** exact symbol(s)
- **CURRENT IMPLEMENTATION:** what exists now
- **PROBLEM:** concrete technical/product issue
- **WHY IT MATTERS:** user/business/performance/reliability impact
- **EXACT CHANGE:** what will be changed
- **IMPLEMENTATION DETAILS:** state/data/error/loading behavior
- **DEPENDENCIES:** existing services/packages only where possible
- **REGRESSION RISKS:** what could break
- **TESTS:** exact unit/widget/manual/build checks
- **PRIORITY:** P0/P1/P2

Do not invent a class or path just to fill this template. If the actual source uses a different symbol, use the real symbol.

---

# 3. ARCHITECTURE & STATE MANAGEMENT

## P0 — Split the god file safely

Primary known file: `lib/main.dart`.

Refactor the large file into feature/core/shared files while preserving behavior. At minimum investigate and extract the responsibilities identified by the audit:
- Search screen
- Profile screen
- Lyrics screen
- playback helpers
- more-options sheet
- add-to-playlist sheet
- sleep timer dialog
- creator upload/gating UI
- splash/main shell
- global playback/navigation state

Use the existing project structure (`lib/core`, `lib/features`, `lib/shared`) instead of inventing a parallel architecture.

Do not change behavior during the extraction. First make a mechanical refactor, then improve individual features.

## P1 — Centralize playback state

The audit identifies global mutable state such as current track, queue, queue index, repeat/shuffle state, player-expanded state, tab state and multiple `ValueNotifier`s.

Create one coherent playback state owner using the project's actual current patterns. Riverpod is acceptable only if the migration is justified and can be done incrementally; it is **not mandatory**. Do not introduce a large state-management migration just for style.

Required properties:
- one source of truth for current track
- queue + index always consistent
- repeat/shuffle state always consistent
- player state observable by UI
- safe async transitions
- no duplicate competing playback controllers
- state survives widget rebuilds
- predictable disposal/lifecycle behavior

Add regression tests for play/pause/next/previous/queue/repeat/shuffle.

## P1 — Error/loading architecture

Standardize user-facing loading, empty, retry and error states. Keep logs useful for debugging but never expose technical secrets/errors directly to users.

---

# 4. HOME — PERSONALIZED MUSIC FEED

The Home screen should feel like a real music service, not a static catalog.

First locate and inspect the existing Home screen/feed service implementation. Improve it rather than replacing it blindly.

Required sections, ordered dynamically based on user state:

1. Personalized greeting/context
2. Continue Listening
3. Recently Played
4. Made For You / Recommended For You
5. Because You Played...
6. New Releases / Fresh Picks
7. Trending
8. Hidden Gems / Explore Beyond Your Usual Taste
9. Mood/context collections where useful
10. Personalized playlists/collections
11. Creator/community content where supported

Rules:
- Do not show empty sections.
- New users receive a useful cold-start experience from broad popularity + language/region/context + explicit choices.
- Returning users get behavior-driven personalization.
- Avoid showing the same songs/artists repeatedly in one session.
- Keep recommendation diversity: artist, genre, language, era and popularity tiers.
- Give exploration a controlled share so the feed can learn.
- Refresh recommendations without destroying the user's current scroll context.
- Cache useful feed data and support stale-while-refresh behavior where appropriate.
- Handle offline/degraded backend mode gracefully.

Home ranking should consider, where signals exist:
- completed plays
- skips
- replays
- likes/favorites
- saves/add-to-playlist
- search intent
- recent listening
- artist affinity
- genre affinity
- language affinity
- mood/context affinity
- freshness
- novelty
- popularity
- session context

Do not overfit to any single signal.

---

# 5. DISCOVERY & RECOMMENDATION ENGINE

The audit indicates the project already has advanced recommendation concepts. **Improve and verify the existing engine rather than replacing it.**

Target ranking formula conceptually:

**score = relevance + intent + freshness + novelty + diversity + exploration - repetition - negative feedback**

Actual weights must be derived from current code/data model and made configurable where practical.

Required behavior:
- personalized recommendations
- session-level deduplication
- artist/genre diversity
- exploration/exploitation balance
- seen-item penalties
- recent behavior weighted more heavily than stale behavior
- skip signals reduce similar recommendations
- completion/replay/like/save signals increase related recommendations
- avoid popularity-only feeds
- avoid artist loops
- avoid filter bubbles
- avoid recommending the exact same track across many sections in one screen/session

Create deterministic tests for ranking and diversity constraints.

Add a safe cold-start path and fallback catalog path if personalization data is unavailable.

---

# 6. SEARCH — FAST, SMART, FORGIVING

Inspect the current Search implementation in `main.dart` and any extracted/search-related files before modifying it.

Required UX:
- instant search field
- debounce input
- cancel/deduplicate stale requests
- recent searches
- suggestions/autocomplete where provider data allows
- categories/filters already supported by the app should remain functional
- pagination/infinite loading
- cached results with a real TTL/freshness policy
- graceful no-result state with alternatives
- retry state
- loading skeleton/shimmer
- fast result rendering

Ranking should prioritize:
1. exact/near-exact title
2. exact/near-exact artist
3. strong token match
4. user intent/context
5. popularity/freshness as tie-breakers

Support mixed Hindi/English and common transliteration patterns where feasible with the current provider/search stack. Do not claim semantic natural-language search unless it is genuinely implemented.

Examples the implementation should aim to handle gracefully:
- partial titles
- misspellings
- artist + song queries
- Hindi title typed in Roman characters
- common transliteration differences
- empty/whitespace input

Search cache must not serve stale data indefinitely. Implement TTL/invalidation consistent with the existing cache API.

---

# 7. PLAYER & PLAYBACK — HIGHEST RELIABILITY

Inspect the actual playback stack first. The current dependencies include `just_audio`, `audio_service`, and WebView support. The audit describes a playback manager/handler architecture; verify exact current symbols.

Required:
- play/pause reliability
- next/previous
- queue management
- shuffle
- repeat off/all/one
- seek
- buffering indicator
- recoverable playback errors
- safe rapid track changes
- stale async request protection
- queue persistence where currently supported/appropriate
- mini-player + full player consistency
- lyrics integration if currently present
- sleep timer
- add to playlist
- share
- like/favorite
- clear "now playing" state

Shuffle must use a proper unbiased algorithm such as Fisher-Yates and must not depend on time-based ordering.

Never create multiple uncontrolled `AudioPlayer` instances for the same global playback session.

If background playback is intentionally unsupported by the current YouTube/IFrame architecture, do not fake it or bypass platform/provider rules. Preserve compliant behavior and make the UI accurately communicate limitations.

Add tests for queue mutation during playback, repeated next/previous, shuffle, repeat-one, track-load failure, and rapid user taps.

---

# 8. LIBRARY & PLAYLISTS

Audit existing Library and playlist functionality and wire all visible actions to real persistence.

Required:
- liked/saved songs
- recently played
- playlists
- create/rename/delete playlist
- add/remove/reorder tracks
- playlist playback
- empty states
- optimistic UI with rollback on failure where safe
- offline/local persistence where architecture already supports it
- Supabase sync for authenticated users where supported
- no fake/mock content presented as user data

If current storage is not Hive despite historical documentation mentioning Hive, use the actual current storage stack instead of introducing Hive merely because the old prompt says so.

---

# 9. ADS & MONETIZATION

Current dependencies include Google Mobile Ads and Unity LevelPlay. Inspect the real ad manager/config/consent implementation.

Goal: monetize without making the app feel hostile.

Required:
- sensible ad placements
- clear ad labeling
- frequency caps
- avoid ads during critical interaction moments
- no repeated interstitial spam
- graceful ad-load failure
- consent/privacy handling preserved
- remote/configurable frequency where architecture allows
- premium entitlement must reliably suppress ads when appropriate
- never block core navigation because an ad failed

Prioritize native/relevant placements over disruptive interruptions.

Test:
- ad available
- ad unavailable
- frequency cap reached
- premium/ad-free user
- consent not yet granted
- network offline

---

# 10. PREMIUM

Inspect current premium/ad-free state and billing/entitlement implementation.

Required:
- single source of truth for entitlement
- correct ad suppression
- premium UI reflects actual state
- restore-purchase path if billing exists
- graceful state while entitlement is loading
- no false premium claims
- no client-only security assumption for server-controlled entitlements

If billing is not actually end-to-end implemented, do not pretend it is. Mark the missing backend/store integration clearly and implement the surrounding architecture safely.

---

# 11. NOTIFICATIONS

Current dependencies include Firebase Messaging, local notifications and timezone support. Inspect existing notification services and wiring.

Required:
- permission handling
- FCM token lifecycle where applicable
- local notification scheduling
- timezone-safe scheduling
- deep links to the correct screen/content
- duplicate notification prevention
- preference-aware notifications
- graceful failure when notifications are unavailable

Notification categories should be useful rather than spammy:
- new release from followed/liked artist
- personalized recommendation
- playlist/update
- important account/system event

Do not create notification spam loops.

---

# 12. ANALYTICS & LEARNING SIGNALS

There may be signal tracking already even if no standalone analytics SDK is declared. Inspect the real implementation first.

Track only useful product signals and respect privacy/consent requirements.

Recommended events:
- search_submitted
- search_result_clicked
- play_started
- play_25 / play_50 / play_75 / play_completed where technically meaningful
- skip
- replay
- like
- unlike
- save
- playlist_add
- recommendation_impression
- recommendation_click
- recommendation_skip
- ad_impression/click where permitted
- premium_state_change
- notification_open

Do not log raw secrets, auth tokens, private URLs, or unnecessary personal data.

Use these signals to improve ranking rather than collecting analytics with no product effect.

---

# 13. SUPABASE / BACKEND

Inspect all current Supabase services, migrations and SQL before changing schema.

Required principles:
- indexes for high-frequency query columns
- avoid N+1 patterns
- pagination for large lists
- server-side aggregation/RPC where it materially reduces repeated queries
- RLS remains correct and restrictive
- anonymous users receive only permitted public data
- authenticated users can only mutate their own data
- failures degrade gracefully

Known audit issue: ProfileService performs separate count queries for shots/followers/following. Replace with an efficient query/RPC only after verifying the current schema and RLS behavior.

Do not expose service-role credentials in the Flutter client.

Any schema migration must include:
- migration file
- indexes/constraints as needed
- RLS policy review
- rollback consideration
- tests/query verification

---

# 14. PERFORMANCE

Prioritize measurable wins:

- remove unnecessary rebuilds
- use `const` where appropriate
- lazy-load long lists
- paginate network data
- cache images/results with sensible limits
- avoid duplicate requests
- cancel stale searches
- avoid blocking the UI isolate with heavy work
- avoid repeated Supabase initialization/queries
- use skeletons instead of blank waits
- reduce unnecessary WebView/player churn
- preserve scroll state where useful
- prefetch only when it improves perceived speed

Do not optimize by making behavior fragile. Reliability beats micro-optimization.

---

# 15. UI/UX PREMIUM POLISH

Use the existing design system (`AppColors`, typography, reusable buttons/cards/images and motion system) if those symbols still exist.

Required visual quality:
- consistent spacing/radii
- strong hierarchy
- readable typography
- predictable iconography
- premium but restrained motion
- polished skeleton/loading states
- meaningful empty states
- retry actions
- accessible touch targets
- dark/light theme consistency if both are supported
- no layout overflow
- no text clipping
- responsive behavior across common phone sizes

The UI should feel intentional, not like a collection of independent screens.

Do not redesign every screen merely for novelty. Fix hierarchy, consistency and usability first.

---

# 16. ACCESSIBILITY

Verify:
- semantic labels for icon-only buttons
- adequate touch targets
- text scaling behavior
- contrast
- focus/keyboard behavior where applicable
- meaningful accessibility names for player controls
- no information conveyed by color alone

---

# 17. SECURITY & CONFIGURATION

Inspect `.env.example`, `.env` usage, Android/iOS config and CI configuration.

Rules:
- no secrets in source
- no secrets in logs
- no service-role Supabase key in mobile app
- validate deep links and externally supplied URLs
- sanitize/display user-generated text safely
- review auth/session lifecycle
- review RLS before exposing new data
- use least-privilege credentials
- keep signing material out of git

The audit reported missing configuration for some services. Add **placeholders/documentation**, not real secrets. If a feature requires a user-provided key, fail clearly and safely rather than embedding one.

Historical documentation also contains conflicting statements about old YouTube dependencies. Do not reintroduce obsolete dependencies without source-level justification.

---

# 18. VERSIONING & RELEASE HYGIENE

Current `pubspec.yaml` says `5.9.1+44`. Any settings/about screen showing another version should read the canonical app version rather than hardcoding a stale string.

Verify:
- Android release build
- package/application ID
- signing configuration uses CI/environment secrets only
- ProGuard/R8/minification if enabled does not break playback/ads/auth
- app links/deep links
- notification configuration
- release assets/config

If iOS is intended for release, audit and complete the required iOS configuration separately; do not claim iOS release readiness without an actual build/validation path.

---

# 19. TEST STRATEGY

At minimum add/maintain tests for:

### Search
- debounce
- stale request cancellation/deduplication
- exact/partial matching
- cache TTL
- pagination
- no results

### Recommendations
- deterministic ranking
- deduplication
- diversity
- seen-item penalty
- exploration
- cold start

### Playback
- queue
- next/previous
- shuffle
- repeat
- rapid track changes
- playback error recovery

### Library
- playlist CRUD
- add/remove/reorder
- liked state

### Ads/Premium
- entitlement suppression
- frequency cap
- unavailable ad

### Notifications
- deep link routing
- duplicate prevention
- timezone conversion where applicable

### UI
- main navigation
- player controls
- loading/error/empty states
- accessibility semantics for key controls

Run `flutter analyze` and `flutter test` and resolve failures. Use the repository's existing scripts/Makefile/CI commands where present.

---

# 20. IMPLEMENTATION PHASES — DO IN THIS ORDER

## Phase 1 — Baseline + Security
- inspect repository
- establish clean baseline
- fix dangerous configuration/security issues
- confirm no secrets are introduced
- record current build/test state

## Phase 2 — Architecture
- split `main.dart`
- centralize state carefully
- preserve behavior

## Phase 3 — Playback
- stabilize queue/player lifecycle
- fix shuffle/repeat
- error recovery
- player UI consistency

## Phase 4 — Performance
- request deduplication
- cache TTL
- pagination
- rebuild/network optimization

## Phase 5 — Home
- personalized sections
- cold start
- session deduplication
- stale-while-refresh/fallback behavior

## Phase 6 — Search
- fast suggestions
- ranking
- mixed-language/transliteration improvements where feasible
- caching/pagination/error states

## Phase 7 — Discovery
- recommendation ranking
- diversity/novelty/freshness
- learning signals

## Phase 8 — Library + Playlists
- real persistence
- sync
- CRUD and playback

## Phase 9 — Ads + Premium
- frequency caps
- entitlement handling
- graceful failures

## Phase 10 — Notifications + Analytics
- notification reliability
- useful product signals
- privacy-safe event handling

## Phase 11 — UI/UX + Accessibility
- visual consistency
- motion
- empty/error/loading states
- accessibility

## Phase 12 — Full QA / Release
- analyze
- test
- build release
- smoke test core flows
- fix regressions
- only then declare completion

---

# 21. TOP 20 HIGHEST-IMPACT CHANGES

1. Split `lib/main.dart` without behavior regressions.
2. Establish a single reliable playback state source.
3. Make queue/next/previous/shuffle/repeat deterministic and race-safe.
4. Make search fast, cancellable, cached and paginated.
5. Add real search-cache TTL/invalidation.
6. Improve Home personalization using existing recommendation infrastructure.
7. Enforce recommendation diversity and session deduplication.
8. Improve cold-start recommendations.
9. Strengthen recommendation freshness/novelty/exploration.
10. Make Continue Listening/Recently Played genuinely persistent and useful.
11. Wire Library/playlists to real persistence and sync.
12. Eliminate ProfileService N+1 query behavior after schema verification.
13. Make ads frequency-controlled and premium-aware.
14. Make premium entitlement state consistent and trustworthy.
15. Harden notification deep links/deduplication/timezone behavior.
16. Standardize loading/empty/error/retry UX.
17. Reduce unnecessary rebuilds/network/player churn.
18. Remove hardcoded fake profile/version data.
19. Tighten security/configuration/RLS/secret handling.
20. Finish with real tests + Android release build verification.

---

# 22. DEFINITION OF DONE

The upgrade is complete only when all of the following are true:

- app compiles successfully
- `flutter analyze` is clean or only has explicitly justified pre-existing warnings
- tests pass
- Android release build succeeds
- no secrets were added to git
- existing core playback/navigation/auth functionality still works
- Home is meaningfully personalized and has graceful cold-start/fallback behavior
- Discovery is diverse, fresh and not repetitive
- Search is fast, forgiving and resilient
- Player/queue behavior is stable under rapid interaction and failures
- Library/playlists use real persistence
- Ads are monetization-friendly without excessive disruption
- premium/ad-free state is reliable
- notifications work without spam/duplicates
- analytics/signals are privacy-safe and actually feed product improvements where appropriate
- major screens have polished loading/empty/error states
- key controls are accessible
- no feature is falsely represented as complete when its backend/store integration is missing

---

# 23. FINAL INSTRUCTION TO ASTRA / ARENA

**Do not just explain this plan back to the user. Execute it.**

Start by auditing the live repository and mapping every requirement above to the actual current files/classes/functions. Then implement the workstream in phases, building/testing after each major phase. When a change reveals a conflict with an old document, prefer current source and explain the conflict in the implementation summary. Preserve working functionality, keep changes incremental, and fix regressions before moving on.

At the end, provide:
1. concise summary of implemented changes
2. exact files changed
3. tests run + results
4. build command + result
5. any genuinely blocked items and why
6. any required manual configuration that cannot safely be committed

**Never report success without a successful verification path.**

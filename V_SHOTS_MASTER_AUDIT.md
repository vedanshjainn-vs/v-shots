# V Shots — Master Audit (Phase 0)

**Audit date:** 2026-08-12
**Audited commit:** `7714739` (branch `main`) — "FEAT: master fix — unified Discovery
filter config, remote-config layout, fresh rotating content, global mini-player verified,
Discovery native ads, auto-refresh; version 5.8.0 (build 20)"
**Method:** Read-only. Repository cloned via `git clone` and inspected with `grep`/`cat`/
`find` only. **No file in `lib/`, `android/`, `pubspec.yaml`, `.github/`, or `supabase/`
was modified to produce this document.** Every claim below cites the exact file/line
evidence found. Where something could not be verified without a Flutter/Android toolchain
or a running emulator/device (neither is available in the auditing sandbox — confirmed:
no `flutter`, `dart`, `java`, or `gradle` binaries are installed there), it is explicitly
marked **UNVERIFIED (no toolchain available in this session)** rather than assumed to
pass or fail.

> **Auditor's tooling disclosure:** This audit was produced from a sandbox that has git
> and network access but no Flutter SDK, Android SDK, Java, or Gradle installed. I could
> read every file and reconstruct call graphs via `grep`, but I could **not** run
> `flutter pub get`, `flutter analyze`, `flutter test`, or any Gradle build myself in this
> session. The repository's own `.github/workflows/build-apk.yml` already runs exactly
> those steps on GitHub's infrastructure on every push — that CI run (not this sandbox)
> is the authoritative source for analyzer/test/build pass-fail status going forward.
> Historical internal docs (`docs/CURRENT_BASELINE.md`, `docs/UI_PERFORMANCE_AUDIT.md`)
> indicate prior sessions *did* have a Flutter SDK available and ran these commands for
> real at older commits — those results are cited below as history, not re-verified now.

---

## A. Current architecture (as it actually exists)

This is **not a greenfield project**. It is a substantial, already-iterated Flutter app
(20 commits of feature/fix work visible in `git log`, version `5.8.0+20`) that has
already gone through several of the exact problems this task describes and, per commit
messages and code, already fixed a number of them:

- **UI shell:** `lib/main.dart` is a single **3,990-line** file containing most screens
  (`HomeScreen`, `SearchScreen`, `PlayerScreen`, `LibraryScreen`, `ProfileScreen`,
  `MainShell`) as `StatefulWidget`s with `setState`, plus several **global top-level
  variables**: `audioPlayer` (`just_audio.AudioPlayer`), `globalYtController`
  (`YoutubePlayerController`), `currentQueue`, `currentTrack`, `currentQueueIndex`,
  `audioHandler`, `sharedYt`. No Riverpod/Bloc/Provider(package)/GetX dependency exists.
- **Playback engine:** Confirmed **one** `YoutubePlayerController` instance
  (`lib/main.dart:130` `YoutubePlayerController? globalYtController;`, constructed once in
  `ensureGlobalPlayer()` at line 156) using the **official** `youtube_player_iframe`
  package (pubspec `youtube_player_iframe: ^6.0.2`). This is the single authoritative
  playback engine — no second controller instance was found anywhere in `lib/`.
- **No YouTube stream-extraction code exists today.** `lib/core/audio/stream_resolver.dart`
  was searched specifically for `getManifest`/`streamsClient`/`YoutubeExplode` — zero
  matches in any `.dart`/`.yaml`/`.lock` file in the repo. The file's current content is a
  22-line stub (`AudioStreamResolver.resolveAuthorizedAudioUrl`) explicitly commented
  "YouTube audio extraction is strictly prohibited per official compliance" and only
  passes through a `directUrl` if one is already provided (for non-YouTube, licensed/UGC
  content). `youtube_explode_dart` is **not** a dependency in `pubspec.yaml` or
  `pubspec.lock`. This confirms a **prior migration away from stream extraction has
  already happened** (there is a stale remote branch,
  `origin/youtube-official-player-migration`, and commit `93dfcd4`/`8df8990`/`ca58480`
  document exactly this migration). **Conclusion: Rule 9 ("no YouTube stream extraction")
  is already satisfied by the current `main` branch.**
- **Content/provider layer:** A partial abstraction already exists under
  `lib/core/providers/` — `ProviderManager`, `ProviderRegistry`, `ProviderConfig`,
  `provider_models.dart`, `provider_result.dart`, and a YouTube adapter
  (`adapters/youtube/youtube_data_api_client.dart`, `youtube_music_mapper.dart`,
  `youtube_music_provider.dart`) that wraps the **official YouTube Data API v3** (search,
  video details, channel details) with an explicit test suite
  (`test/core/providers/youtube_*_test.dart`). `provider_config.dart` is explicit and
  honest in its own comments that this is "LOCAL, HARDCODED configuration only" and that
  no remote-config mechanism is actually wired up yet — a real, self-disclosed gap, not a
  fabricated claim.
- **Recommendation engine:** A single, fairly complete pipeline already exists under
  `lib/core/recommendation/`: `candidate_generator.dart` (274 lines),
  `recommendation_scorer.dart` (225 lines, explicitly comments that a placeholder/fake
  score would be wrong and computes a real one), `diversity_filter.dart`,
  `genre_classifier.dart`, `taste_profile.dart`, `signal_recorder.dart`,
  `signal_store.dart`, `recommendation_cache.dart`, `recommendation_config.dart`,
  `recommendation_metrics.dart`, `recommendation_engine.dart` (312 lines, the
  orchestrator), `recommendation_service.dart`. This is **one** engine — no second/
  competing recommendation implementation was found anywhere in `lib/`.
- **Discover ("For You") feed:** `lib/features/foryou/for_you_feed_screen.dart` (1,197
  lines) + `for_you_feed_service.dart` (379 lines) — a vertical `PageView.builder`
  Reels-style feed, sharing the **same** global player/queue as the rest of the app (not
  a second playback path).
- **Local persistence:** `lib/core/storage/local_library.dart`, backed by
  `shared_preferences` — Liked Songs, Recently Played (capped at 100), Playlists, Recent
  Searches, `artistPlayCounts` (feeds the recommendation engine). Confirmed via
  `docs/CURRENT_BASELINE.md`'s own grep that **no Supabase table is queried for any of
  this** — Supabase (`supabase_flutter`) is used only for Google Sign-In today.
- **Ads:** `lib/core/ads/ad_config.dart`, `ad_manager.dart`, `consent_manager.dart`,
  `native_ad_widget.dart` — Google Mobile Ads **native ads only**, official Google test ad
  unit ID hardcoded as a literal fallback, production ID read from `.env`/
  `flutter_dotenv`/`String.fromEnvironment`, never hardcoded. `adsEnabled` is explicitly
  `false` unless a real production ID is present — ads are not shown as test content to
  real users by default. Placement cadence constants exist for Home/Search/Discovery
  (`homeAdEvery = 8`, `searchAdEvery = 8`, `discoveryAdEvery = 9`) — no "ad after every
  song" pattern found.
- **Auth:** `lib/core/backend/auth_service.dart` + `supabase_service.dart` — Google
  Sign-In via Supabase (`signInWithIdToken`), `google_sign_in: ^7.2.0`.
- **Database (Supabase):** `supabase/migrations/20260810000001_vshots_nova_schema.sql` +
  root-level `supabase_setup.sql`/`supabase_remote_config.sql`. Tables:
  `profiles`, `shots`, `likes`, `comments`, `follows`, `bookmarks`, `notifications` — this
  is a **social/UGC video schema** (see Section C — this is a real architectural conflict
  with the music-discovery product vision, not something to blindly delete without
  understanding why it's there — see Section D/E).
- **CI/CD:** `.github/workflows/build-apk.yml` is already a genuinely serious pipeline:
  checkout → Java 17 → Flutter 3.44.9 stable → inject `.env` from GitHub Secrets → inject
  production AdMob App ID into the manifest only if the secret is set → `flutter pub get`
  → `dart format .` → `flutter analyze` → `flutter test` → build **debug APK, signed
  release APK, and release AAB** in one step (so both artifacts share the same keystore)
  → verify all three output files exist and fail (`exit 1`) if any are missing → compute
  SHA256 for all three → upload all three as build artifacts → conditionally create a
  GitHub Release (gated behind an explicit `ENABLE_RELEASE` repo variable — release
  publishing does **not** happen by default) → optional BrowserStack real-device upload +
  smoke test if `BROWSERSTACK_USERNAME`/`BROWSERSTACK_ACCESS_KEY` secrets are present. If
  `ANDROID_KEYSTORE_BASE64` secret is absent, CI generates a **throwaway** keystore with a
  random, non-committed password so the build still succeeds but is explicitly **not**
  the production signing key — this is exactly the correct fail-safe behavior.
- **Android config:** `applicationId "com.vshots.live"`, `minSdk 24`, `compileSdk 36`,
  `targetSdk 36`, `versionCode 20`, `versionName "5.8.0"`, Java 17, v1+v2 signing enabled,
  keystore path/passwords read from `ANDROID_KEYSTORE_PATH`/`_PASSWORD`/`_ALIAS`
  environment variables (CI secrets) with a local `key.properties` fallback for local
  builds — **no keystore password is hardcoded in `build.gradle`.**
- **Tests:** 18 test files under `test/` covering recommendation scoring, diversity,
  genre classification, candidate generation, taste profile, the YouTube provider/mapper/
  client, ad page-index mapping, discovery categories, the queue controller, local
  library, and search cache — i.e. tests already exist for most of the areas Phase 14 of
  the brief asks for. **Pass/fail status at the current `main` HEAD is UNVERIFIED in this
  session** (no Flutter SDK available here); must be confirmed via the next real CI run
  or a session with a Flutter toolchain.

## B. Current problems (confirmed via code read)

1. **`lib/main.dart` is a 3,990-line God file.** Nearly every top-level screen and the
   global player/queue state live in one file. This is a real maintainability and
   testability problem (hard to unit-test a screen embedded in a 4,000-line file;
   merge-conflict magnet), even though the *behavior* inside it is largely correct.
2. **Two unrelated product concepts are merged in the same codebase**, see Section C
   below — a YouTube-music-discovery app and a TikTok-style UGC "Shots" social app
   (upload/comment/follow/like on user-uploaded videos) with its own **mock, in-memory
   data source**. This is a direct conflict with the "no mock data in production" rule
   for whichever of the two is not the real product going forward.
3. **`lib/core/services/notifications_service.dart`** ships **hardcoded, in-memory mock
   notifications** (`_mockNotifications`, `'mock-creator-1'`, `'mock-1'`, etc.) as its
   only data source — no real backing store. `NotificationsScreen` that renders them is
   **not reachable from any navigation path** (confirmed: `grep -rn "NotificationsScreen("
   lib/` only matches the screen's own file) — currently dead, unreachable mock-data UI.
4. **`lib/core/services/shots_service.dart`** ships hardcoded mock "shots" (`'mock-1'`,
   `'mock-creator-1'`, etc.) as an in-memory fallback/seed. Unlike notifications, this one
   **is** reachable — `UploadShotScreen` (which posts into this same system) is wired
   into `main.dart` at line 1160. This means a real, mock-seeded, non-music UGC feed is
   currently live-reachable in the shipped app.
5. **Provider architecture is explicitly partial.** `provider_config.dart`'s own header
   comment is honest that "remote provider switching" does not actually exist yet — this
   is disclosed technical debt, not a hidden defect, but it means Phase 3's target
   architecture (`YouTubeRepository → LiveCandidateGenerator → ... → FeedAssembler`) is
   only partially realized; a lot of Home/Search/Discover call sites still call the
   YouTube search API more directly than the target architecture diagram implies (see
   `docs/CURRENT_BASELINE.md`'s own Section 3 table — current as of that baseline's
   commit, re-verified structurally still true at HEAD: `for_you_feed_service.dart` and
   `main.dart`'s Home/Search screens are the real call sites).
6. **Version-number drift (partially fixed, one instance remains):** `pubspec.yaml`
   documents that it used to say `0.1.0+1` while `build.gradle` actually shipped
   `5.3.0`/`12`; that specific drift is now fixed (`pubspec.yaml` reads `5.8.0+20`,
   matching `build.gradle`'s `versionName "5.8.0"` / `versionCode 20`) but
   `pubspec.yaml`'s own comment confirms **`build.gradle` still hardcodes its own
   version fields independently rather than reading `flutter.versionName`/
   `flutter.versionCode` from `pubspec.yaml`** — future edits must remember to update
   both files, or the drift bug will reoccur.
7. **Historic, now-superseded findings from `docs/CURRENT_BASELINE.md` /
   `docs/UI_PERFORMANCE_AUDIT.md`** (both self-dated 2026-08-10, several commits before
   this audit's HEAD) list: a dead `undefined_shown_name` analyzer warning
   (`likedSongIds` import in `for_you_feed_screen.dart`), a non-functional Shuffle/Repeat
   button, `MainShell` rebuilding the whole `IndexedStack` on every player tick, a
   `PlayerScreen` stream-subscription leak, and missing `AppImage` width/height on Home
   cards. **These were the state of the world 6-8 commits ago — whether they are still
   present at the current HEAD (`7714739`) was NOT re-verified line-by-line in this audit
   pass** (out of scope for a non-destructive Phase 0 read given the volume of file
   changes since); flagged here as **carry-forward items to re-confirm** in Phase 1, not
   as confirmed-still-broken.
8. **No `TODO`/`FIXME`/`HACK` markers exist anywhere in `lib/`** (`grep -rn "TODO\|FIXME\|
   HACK\|XXX" lib/` → zero matches) — either genuinely clean, or prior sessions
   deliberately resolved/removed them rather than leaving markers; either way, no
   outstanding marker-based blockers were found.
9. **`docs/architecture/ARCHITECTURE.md` and `docs/architecture/PROVIDER_ARCHITECTURE.md`**
   describe a Clean-Architecture design that, per `docs/CURRENT_BASELINE.md`'s own
   grep-verified note, was **never fully implemented** as originally written — some of it
   now exists (the `core/providers/` tree), but the docs likely still overstate scope
   relative to actual code. Docs vs. code drift is a recurring pattern in this repo and
   should be treated with skepticism until cross-checked against real code, exactly as
   this audit has done.

## C. Duplicate / conflicting systems (confirmed)

- **Music-discovery app vs. UGC social-video app, in the same codebase:**
  - Music side: Home/Discover/Search/Player/Library screens, YouTube Data API provider,
    recommendation engine, `LocalLibrary`.
  - UGC side: `shots` Supabase table, `ShotsService` (mock-seeded), `UploadShotScreen`
    (reachable), `shot_card.dart`, `comment_sheet.dart`, `follow_button.dart`,
    `NotificationsScreen`/`NotificationsService` (mock-seeded, unreachable),
    `profiles`/`likes`/`comments`/`follows`/`bookmarks`/`notifications` Supabase tables.
  - These two systems do not share a common "content item" model (`ShotModel` vs. the
    YouTube-track record shape used elsewhere) and the UGC side's only real data source
    today is hardcoded mock objects. **This is the single biggest architectural decision
    the product owner needs to make before Phase 1 begins**: is "V Shots" a YouTube-music
    discovery app (per this task's entire brief) with an unrelated, half-built social
    feature bolted on, or was the app named/scoped for short-form UGC video with music
    discovery bolted on? The task brief describes the former; the repository's Supabase
    schema and `shots`/`comments`/`follows` tables describe the latter. **Recommendation
    (Section E): treat the UGC/Shots system as out-of-scope for this rebuild and either
    remove it or clearly gate it behind a separate, clearly-labeled feature area — do NOT
    silently keep shipping mock-seeded social content in a "premium music discovery app."**
- **No duplicate playback engines found** — one `YoutubePlayerController`, one
  `AudioPlayer` (used only for local/UGC playback per `stream_resolver.dart`'s stated
  scope, not YouTube).
- **No duplicate recommendation engines found** — one pipeline under
  `lib/core/recommendation/`.
- **No duplicate mini-player implementations found** as competing classes; historical
  docs describe iterative mini-player fixes across several commits
  (`ca58480`, `db67c49`, `93dfcd4`) converging on a single "always-mounted" player
  pattern — current mini-player implementation lives inline in `main.dart`'s
  `MainShell`/player-adjacent widgets (not a separately named `MiniPlayer` class), so it
  was not separately extracted for this read-only pass; recommend extracting it to its
  own widget file during Phase 2 for testability, not because a duplicate was found.
- **One dead, non-duplicate leftover, already resolved:** `docs/CURRENT_BASELINE.md` (an
  older, still-true historical note) documents a
  `lib/features/home/data/home_content_service.dart` +
  `lib/features/home/domain/models/home_models.dart` pair with **zero importers** — this
  path does not appear in the current file tree at all anymore (confirmed via `find`),
  so it appears to have already been deleted since that baseline was written. Good — no
  action needed.

## D. What should be preserved

- The single global `YoutubePlayerController` / official `youtube_player_iframe`
  playback engine — already compliant with Rule 9, do not reintroduce stream extraction.
- The existing `lib/core/recommendation/` pipeline as the foundation — it already has the
  right shape (candidate generation → scoring → diversity → caching) and real tests; it
  should be extended (freshness windows, country/language scorers, exploration
  percentage per Phase 4/5) rather than replaced wholesale.
- The existing `lib/core/providers/` YouTube Data API adapter (`youtube_data_api_client.dart`,
  `youtube_music_mapper.dart`, `youtube_music_provider.dart`) — this is the correct,
  compliant integration point and already has tests.
- The existing CI pipeline's structure (build debug+release+AAB in one step so signing is
  consistent, SHA256 verification, gated release publishing, optional BrowserStack real-
  device smoke test) — it is already close to what Phase 15 asks for; it needs
  incremental hardening (e.g., explicit production-secret gating for release builds, dev/
  staging/prod separation), not a rewrite.
- `LocalLibrary` (local-first behavior tracking) as the local source of truth, syncing to
  Supabase per Phase 10, rather than replacing it.
- The AdMob native-ad configuration and its "test ID by default, prod ID only from
  secrets" pattern.
- The Android signing/versioning setup in `build.gradle` (env-var-driven, no hardcoded
  secrets).

## E. What should be rewritten / removed

- **Remove or explicitly quarantine the UGC/Shots social system** (`shots_service.dart`'s
  mock data, `UploadShotScreen`'s live wiring, `NotificationsService`'s mock data, and the
  associated Supabase tables) from the primary music-discovery experience, per Section C.
  This is the clearest concrete instance of "mock data as a primary/reachable content
  source" in the repository today.
- **Break up `lib/main.dart`** into per-screen files under `lib/features/...` (Home,
  Search, Player, Library, Profile) so each screen can be unit/widget-tested in isolation
  and so the global mutable state (`audioPlayer`, `globalYtController`, `currentQueue`,
  etc.) can be moved into an explicit, single `PlaybackController`/`QueueController`
  service class instead of top-level global variables.
- **Finish the provider abstraction**: route Home/Search/Discover through
  `ProviderManager`/`MusicRepository` consistently instead of ad hoc direct calls, so
  Phase 3's `YouTubeRepository → LiveCandidateGenerator → MusicContentValidator →
  LanguageDetector → FeatureExtractor → RecommendationEngine → DiversityFilter →
  FeedAssembler` pipeline is real end-to-end, not partially bypassed.
- **Add the country/language scoring layer** (Phase 4/5) — not found as dedicated
  `LanguageDetector`/`CountryScorer`/`LanguageScorer` components today; `genre_classifier.dart`
  exists but a script-detection-based language confidence system does not appear to exist
  yet under this name — needs to be built as new, additive work on top of the existing
  scorer pipeline.
- **Reconcile `docs/architecture/*.md`** against real code so documentation stops
  describing an aspirational design that doesn't fully exist — update or clearly mark
  aspirational sections.

## F. Recommended final architecture

Largely **confirms the architecture this task's brief already specifies** — the good
news from this audit is that the repository is already most of the way toward it:

```
UI (Home / Discover / Search / Player / Library / Profile / Onboarding / Settings)
   -> MusicRepository (existing: lib/core/providers/music_repository.dart)
       -> ProviderManager -> ProviderRegistry -> YouTubeMusicProvider (existing)
           -> YouTubeDataApiClient (existing, official YouTube Data API v3 only)
   -> RecommendationService (existing) -> RecommendationEngine (existing)
       -> CandidateGenerator (existing) -> [NEW] LanguageScorer / CountryScorer
       -> RecommendationScorer (existing) -> DiversityFilter (existing)
       -> RecommendationCache (existing)
   -> Single PlaybackController (to be extracted from main.dart's globals)
       -> YoutubePlayerController (existing, official youtube_player_iframe, singleton)
   -> LocalLibrary (existing, local-first) <-> Supabase sync (to be added per Phase 10)
```

No wholesale rewrite is architecturally justified — Rule 11 ("do not destroy working
architecture without understanding it") directly applies here. The correct plan is
targeted extension (finish the provider indirection, add language/country scoring, split
`main.dart`, remove the UGC mock system) rather than a from-scratch rebuild.

## G. Database requirements

Current Supabase schema (`profiles`, `shots`, `likes`, `comments`, `follows`,
`bookmarks`, `notifications`) is built for the **UGC social system**, not the
music-personalization tables Phase 10 asks for. None of
`user_preferences`, `user_taste_profile`, `recommendation_events`,
`recommendation_memory`, `recently_played`, `user_likes` (on **tracks**, not on `shots`),
`tracks`, `artists`, `playlists`, `playlist_tracks` exist in Supabase today — recommendation
state (`taste_profile.dart`, `signal_store.dart`) is currently **local-only**
(`shared_preferences`), confirmed via `docs/CURRENT_BASELINE.md`'s grep
(`grep -rn "\.from('" lib/` → zero matches, i.e. nothing in `lib/` queries any Supabase
table today). **Action required:** design and migrate the Phase 10 tables with RLS, and
wire `SignalRecorder`/`TasteProfile`/`LocalLibrary` to sync to them when a user is
authenticated, while keeping local-first behavior for responsiveness as specified.

## H. API requirements

- **YouTube Data API v3** — already the sole content source (`YouTubeDataApiClient`);
  needs `YOUTUBE_DATA_API_KEY` present as a GitHub secret (already referenced correctly
  in `.github/workflows/build-apk.yml`, injected into `.env` at build time, never
  hardcoded in source).
- **Supabase** (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) — already wired for auth; needs
  expansion for the Phase 10 tables.
- **Google Sign-In** (`GOOGLE_ANDROID_CLIENT_ID`/`GOOGLE_WEB_CLIENT_ID`) — already wired.
- **AdMob** (`ADMOB_APP_ID`, `ADMOB_NATIVE_AD_ID`) — already wired with a compliant
  test/production ID split.
- **BrowserStack** — already wired as an optional CI step for real-device smoke testing.

## I. CI/CD requirements

The existing `.github/workflows/build-apk.yml` already covers most of Phase 15's list
(format check → analyze → test → debug/release/AAB build → SHA256 → artifact upload →
gated release). Gaps versus the brief:

- No explicit **development/staging/production** environment separation (single job,
  single workflow) — Phase 15 asks for this "where practical."
- Release publishing is already correctly gated behind `ENABLE_RELEASE`, but there is no
  explicit **"fail the build if required production secrets are missing for a production
  release"** hard gate beyond the keystore fallback — currently a missing
  `ANDROID_KEYSTORE_BASE64` silently falls back to a CI throwaway keystore rather than
  failing the production path outright. This should be tightened so a push intended as a
  production release cannot silently ship with a non-production signing key.
- CI status/pass-fail for the **current HEAD** is UNVERIFIED from this sandbox — must be
  confirmed by actually triggering the workflow (e.g. `workflow_dispatch` or a push) and
  reading its real result, not assumed.

## J. Play Store blockers

- `PLAY_STORE_READINESS.md` already exists in the repo (root) — needs to be read in full
  and reconciled against the current build (this audit did not re-verify every claim in
  that file line-by-line; flagged for Phase 16 follow-up).
- The UGC/Shots social system (Section C/E) is a **policy-relevance blocker**: if it ships
  live with mock-seeded content and a working upload path, it changes the app's Play
  Store data-safety/content-moderation obligations (user-generated video content) in ways
  a pure music-discovery app would not have. This must be resolved (remove, gate, or
  properly scope with real moderation/reporting) before a production Play Store
  submission, independent of the music-side work.
- Release APK/AAB signing depends on `ANDROID_KEYSTORE_BASE64` + related secrets being
  configured in GitHub Actions — **not verified as present** in this session (secret
  values are never readable by design; only their configured/absent status could be
  checked, and this audit did not query the GitHub Secrets API to avoid any risk of
  leaking or mishandling credentials). Must be confirmed directly by the repository owner
  in GitHub → Settings → Secrets.

---

## Summary judgment

This repository is **materially further along** than "static catalog with fake data" —
it already has a real recommendation engine, an official-API-only YouTube integration, a
single playback engine, real tests, and a genuinely solid CI pipeline. The most important,
concrete finding of this audit is **Section C**: a second, unrelated, mock-data-backed
UGC/social-video product is merged into the same codebase and is partially reachable in
the live app. That is the highest-priority decision for the product owner before any
further "rebuild" work proceeds, because it determines how much of Phases 1-20 apply to
*this* system versus a system that should be removed first.

**No destructive changes have been made to `lib/`, `android/`, `pubspec.yaml`,
`supabase/`, or `.github/` in this audit pass**, per this phase's explicit instruction.
This document has been committed, by itself, to a new branch (`audit/phase-0-master-audit`)
so `main` remains untouched pending review.

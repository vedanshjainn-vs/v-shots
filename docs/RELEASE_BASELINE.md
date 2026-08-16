# V Shots — Release Baseline v5.20.0

**Tag:** `v5.20.0-baseline`
**Commit:** `67df1f6c` (merge of PR #10)
**CI:** run `31967313426` — success
**Date:** 2026-08-16

This is the **stable baseline for future development**. Any new feature branch
should start from this tag; any regression can be diffed against it.

---

## Verified-green state

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | 212/212 passing |
| `dart format --set-exit-if-changed` | pass |
| Release APK | ✅ 35.7 MB (attached to the release) |
| Release AAB | ✅ 64.3 MB (attached to the release) |
| Debug APK | ✅ 88.7 MB (attached to the release) |

## Release binaries

- `v-shots-v5.20.0-baseline-release.apk`
- `v-shots-v5.20.0-baseline-release.aab`
- `v-shots-v5.20.0-baseline-debug.apk`

Download: https://github.com/vedanshjainn-vs/v-shots/releases/tag/v5.20.0-baseline

## What this baseline includes

### Discovery
- Full-screen immersive discovery: blurred artwork backdrop + sharp center
  artwork + title/artist + right-side actions + bottom mini browser.
- **In-app YouTube browser** — one persistent WebView session:
  - collapsed mini player keeps playing (WebView never resized/detached)
  - drag up → expand (real YouTube watch page), drag down → collapse
  - strong downward fling / X → close + dispose
  - video switching reuses the same session (no duplicate WebViews)
- **Native background playback layer**: custom Android WebView platform view
  (`VShotsBrowserPlatformView.kt`) + foreground `mediaPlayback` service
  (`VShotsBrowserPlaybackService.kt`); best-effort autoplay/unmute on the real
  YouTube page. No fake "playing" state.
- Explore filter hierarchy (source / mood / language / region) → real query
  composition (`buildDiscoveryQuery`) + relevance filter + official-first
  normalization.

### Content engine
- InnerTube-first discovery via `ProviderManager` (fallback: YouTube Data API
  v3 → curated catalog). Official/verified uploads rank first.
- Recommendation engine (signals → taste profile → candidates → scoring →
  diversity) wired into Home/Discovery.
- Onboarding taste personalization seeds cold-start candidates.

### Home / Search / Library
- Endless Home shelves (pagination + replenishment from fallback queries;
  soft cross-shelf dedup).
- "Artists For You" + "Official Music" shelves; official badge on cards.
- Search with debounce, pagination, prefetch at ~75% scroll.
- Queue (Play Next / Add to Queue), listening history (Today/Yesterday/
  Earlier), artist pages, playlists/local library.

## Honest limitations (documented, not faked)

1. **Background/lock-screen audio** via the WebView browser is best-effort:
   in-app continuity (collapse/expand/tab-switch) is guaranteed by the
   persistent session; true OS background audio is the existing `audio_service`
   global player's domain. YouTube policy may still pause a backgrounded
   webview on some devices.
2. **Label names** are not shown — InnerTube exposes the official *channel*,
   not a reliable record-label field; the "✓ Official" badge + channel name is
   the honest representation.

## Rollback

```bash
git fetch origin --tags
git checkout v5.20.0-baseline
```

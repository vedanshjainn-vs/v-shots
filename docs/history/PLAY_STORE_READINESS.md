# V Shots — Google Play Store Readiness

> Status: **NOT READY** — several items require action/config that is outside
> the current repository state (notably the YouTube Data API key and the AdMob
> production app ID). This document is the pre-launch checklist; each item is
> marked with its current status. Nothing here claims readiness that has not
> been verified.

Last updated: 2026-08-12

---

## 1. Target SDK
- **Target:** Android 16 / API 36 ✅ (targetSdk 36 in `android/app/build.gradle`; compileSdk 36).
- AGP 8.12.1, Kotlin 2.2.0, Java 17, Gradle 8.13 — compatible with the pinned Flutter 3.44.9.

## 2. Permissions
Current manifest permissions: INTERNET, WAKE_LOCK, FOREGROUND_SERVICE,
FOREGROUND_SERVICE_MEDIA_PLAYBACK, POST_NOTIFICATIONS.
- ❗ Review: FOREGROUND_SERVICE_MEDIA_PLAYBACK / audio_service are legacy from the
  old background-audio architecture. YouTube playback is official IFrame only and
  does NOT run as a background media service. These should be removed unless a
  licensed background audio provider is added. **ACTION REQUIRED.**
- No storage, microphone, location, contacts, SMS, or phone permissions. ✅

## 3. Data Safety declarations (Play Console)
Must declare:
- App data collection: personal (email/name on account), plus device/advertising
  identifier for ads.
- Data not shared / collected on device (listening signals are local).
- Ads = ads collection (see #6).
- **ACTION:** fill Data Safety form in Play Console.

## 4. Privacy policy URL
- Policy file exists in-repo (`docs/legal/privacy_policy.md`), updated to disclose
  AdMob, advertising identifiers, ad personalization, UMP consent, and YouTube API
  usage. ✅
- **ACTION:** host it at a public URL and provide it in Play Console.

## 5. Content rating
- **ACTION:** complete the Play Console content rating questionnaire (music/video
  discovery; likely "Everyone" but must be answered manually).

## 6. Ads declaration
- AdMob native ads implemented with test IDs; production App ID + ad unit ID must
  be configured via secrets. **ACTION REQUIRED** (`ADMOB_NATIVE_AD_ID`,
  APPLICATION_ID in manifest).
- "Contains ads" must be declared = true.

## 7. App access / login requirements
- App is usable as a guest; optional Supabase/Google sign-in. No forced login. ✅

## 8. YouTube API disclosure / requirements
- Privacy policy discloses YouTube API usage and Terms. ✅
- The app must complete YouTube's API Services Terms of Service confirmation in
  the Play Console (per YouTube API Services requirements). **ACTION.**

## 9. Copyright / UGC considerations
- App plays official YouTube embeds (compliance maintained). Creator UGC upload
  exists; Play Console UGC policy review required if creators publish content.
  **ACTION.**

## 10. Account deletion requirements
- Supabase profiles exist; an in-app account-deletion path must be verified and a
  Play Console data-deletion link provided. **ACTION REQUIRED** (partially
  implemented; must be validated end-to-end).

## 11. Subscription / IAP
- None. Not applicable. ✅

## 12. Screenshots
- **ACTION:** capture device screenshots (Home, Discover, Search, Player) at
  required resolutions.

## 13. Feature graphic
- **ACTION:** create a 1024×500 feature graphic.

## 14. App icon requirements
- Launcher icon is `@mipmap/ic_launcher`. Adaptive icon / monochrome icon should be
  verified or provided. **ACTION.**

## 15. Release signing
- Workflow supports signing from `ANDROID_KEYSTORE_BASE64` + password secrets; a
  CI throwaway keystore is used when not configured. Real release signing must use
  the actual keystore secrets. **ACTION REQUIRED.**

---

## Required secrets to unblock production
- `YOUTUBE_DATA_API_KEY` (live search/metadata + real artist channel avatars)
- `ADMOB_NATIVE_AD_ID` (production native ad unit)
- AdMob production App ID in manifest
- `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
  `ANDROID_KEY_PASSWORD`

Until these are configured, the build is fully functional with the verified
catalog and test ad IDs, but **is NOT Play Store ready** and must not be released.

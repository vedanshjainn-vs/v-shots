# V Shots — Music discovery (YouTube WebView)

[![Flutter](https://img.shields.io/badge/Flutter-3.44.9-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12.2-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![YouTube API](https://img.shields.io/badge/YouTube-WebView%20%2B%20Data%20API-FF0000?logo=youtube&logoColor=white)](https://developers.google.com/youtube/v3)
[![Supabase](https://img.shields.io/badge/Supabase-Backend%20%26%20RLS-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Android](https://img.shields.io/badge/Android-com.vshots.live-3DDC84?logo=android&logoColor=white)](https://android.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

An Android Flutter music discovery app backed by Supabase. YouTube videos play by loading **youtube.com** in a native WebView. Metadata comes from YouTube Data API v3 (when configured) and YouTube's public InnerTube web endpoints.

---

## 📱 App Identity

- **App Name:** `V Shots`
- **Package Name:** `com.vshots.live`
- **Version:** `5.8.0 (Build 20)`
- **Design System:** `V Shots Nova UI` (Dark-first `#070A12` with purple, cyan, and pink accents)

---

## ⚡ Architecture & Compliance Highlights

1. **YouTube playback (native WebView):**
   - Loads `https://www.youtube.com/watch?v=…` in a native Android WebView.
   - Does not use the YouTube IFrame Player API.
   - Does not extract, cache, or download YouTube audio/video files.
   - Does not skip or hide YouTube advertisements.
   - "Powered by YouTube" attribution is shown in the UI.

2. **Discovery metadata:**
   - InnerTube web endpoints (primary) with YouTube Data API v3 fallback when `YOUTUBE_DATA_API_KEY` is set.
   - Curated offline catalog if both are unavailable.

3. **Provider architecture (`ProviderManager`):**
   - InnerTube → YouTube Data API v3 for search/metadata.
   - Playback is always the in-app WebView (YouTube watch page, or a JioSaavn webpage when a permalink is present).

4. **4-Tab Navigation System (`BottomTabBar`):**
   - **Home (0):** Data-driven personalized feed — Continue Listening, Made For You, Because You Listened To, Trending, and catalog shelves (WebView playback).
   - **Discover (1):** Vertical full-screen reels-style swipe feed with autoplay, next-item preloading, and a mood/category chip rail.
   - **Search (2):** 300ms debounced search, category filters, recent searches history, and result pagination.
   - **Profile (3):** Music-first profile with Liked Songs, Playlists, Recently Played, and Creator Studio Hub.

5. **Dynamic Creator Gating:**
   - Dynamic check via `profiles.is_creator` in Supabase.
   - Approved creators access `UploadShotScreen` to publish UGC video/audio shots.
   - Listeners receive a "Creator Upload — Limited Access" bottom sheet with "Request Access".

---

## 🎨 Nova UI Design Tokens

| Token | Hex Value | Usage |
| :--- | :--- | :--- |
| **Background** | `#070A12` | Main scaffold background |
| **Surface** | `#101420` | Cards, navigation bars, bottom sheets |
| **Surface 2** | `#171C2B` | Inputs, secondary button fills |
| **Primary** | `#7C3AED` | Primary brand purple / gradient start |
| **Accent** | `#22D3EE` | Cyan highlights, badges, icons |
| **Hot Pink** | `#EC4899` | Likes, gradients, notification badges |
| **Border** | `#273044` | Card and input borders |

---

## 🚀 Verification & Testing

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Format Dart code
dart format .

# 3. Analyze codebase (0 issues)
flutter analyze

# 4. Run full test suite (100% passing)
flutter test

# 5. Build Debug APK
flutter build apk --debug
```

---

## ⚖️ Legal & Attribution

- **YouTube Terms of Service:** [https://www.youtube.com/t/terms](https://www.youtube.com/t/terms)
- **Google Privacy Policy:** [https://policies.google.com/privacy](https://policies.google.com/privacy)
- V Shots is an independent application and is **not affiliated with, associated with, or endorsed by YouTube or Google LLC**.

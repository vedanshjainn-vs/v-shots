# 🎬 V Shots (Nova Edition) — Official YouTube Player & Hybrid Streaming

[![Flutter](https://img.shields.io/badge/Flutter-3.44.9-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12.2-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![YouTube API](https://img.shields.io/badge/YouTube%20API-v3%20%26%20Official%20IFrame-FF0000?logo=youtube&logoColor=white)](https://developers.google.com/youtube/v3)
[![Supabase](https://img.shields.io/badge/Supabase-Backend%20%26%20RLS-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Android](https://img.shields.io/badge/Android-com.vshots.live-3DDC84?logo=android&logoColor=white)](https://android.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A compliant, high-performance Android Flutter music discovery & social streaming platform backed by Supabase and the **Official YouTube IFrame Player & YouTube Data API v3**.

---

## 📱 App Identity

- **App Name:** `V Shots`
- **Package Name:** `com.vshots.live`
- **Version:** `5.4.0 (Build 13)`
- **Design System:** `V Shots Nova UI` (Dark-first `#070A12` with purple, cyan, and pink accents)

---

## ⚡ Architecture & Compliance Highlights

1. **Official YouTube Playback:**
   - Powered by the **Official YouTube IFrame Player API** (`youtube_player_iframe`).
   - Genuine, visible 16:9 player surface with official branding preserved and no obstructing overlays.
   - Clear "Powered by YouTube" attribution badge and direct links to YouTube Terms.
   - Foreground-only compliant YouTube video playback.

2. **Zero Unofficial Scraping or Stream Extraction:**
   - Completely removed all unofficial stream extractors (`youtube_explode_dart`, `getManifest`, `audioOnly`).
   - No caching or saving of raw YouTube stream URLs.

3. **YouTube Data API v3 & Resilience:**
   - Real-time search, metadata resolution, channel names, thumbnails, and ISO 8601 duration parsing.
   - Curated fallback music catalog providing 100% offline and rate-limit resilience.

4. **Hybrid Provider Architecture (`ProviderManager`):**
   - Clean separation between **YouTubeProvider** (official IFrame foreground player + Data API v3 metadata) and **LicensedMusicProvider / UGC** (authorized media streams via `just_audio` + `audio_service` for background playback, lock-screen controls, and Bluetooth).

5. **5-Tab Navigation System (`BottomTabBar`):**
   - **Home (0):** Hero branding, Creator "+ Create" button, Top Artists Carousel (Arijit Singh, Diljit Dosanjh, Shreya Ghoshal, AP Dhillon, Anuv Jain, Pritam), and trending music sections.
   - **Discover (1):** Centered artwork, interactive vibe/mood selector pill, and YouTube player launch.
   - **Search (2):** 300ms debounced search, category filters, and recent searches history.
   - **Inbox (3):** Activity notifications and community updates.
   - **Profile (4):** Music-first profile with Liked Songs, Playlists, Recently Played, and Creator Studio Hub.

6. **Dynamic Creator Gating:**
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

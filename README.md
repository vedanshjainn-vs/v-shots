# 🎬 V Shots (Nova Edition)

[![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.14+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Backend%20%26%20RLS-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Android](https://img.shields.io/badge/Android-com.vshots.live-3DDC84?logo=android&logoColor=white)](https://android.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A production-ready, dark-first short-video & social music streaming platform for Android, powered by Flutter and Supabase.

---

## 📱 App Identity

- **App Name:** `V Shots`
- **Package Name:** `com.vshots.live`
- **Version:** `5.4.0 (Build 13)`
- **Design System:** `V Shots Nova UI`

---

## ✨ Core Features

1. **Splash & Onboarding:**
   - Animated Nova visual branding with dark gradient aesthetics.
   - Interactive onboarding carousel showcasing trending shots, creator tools, and social discovery.

2. **Supabase Auth & Social Profiles:**
   - Email/Password login & signup with friendly validation.
   - Native Google Sign-In with OAuth token exchange.
   - Public user profiles, customizable avatars (`avatars` storage bucket), bios, and real-time stats (`ProfileStats`).
   - Follow/Unfollow creators with optimistic updates.

3. **Shorts & Social Video Feed:**
   - Full-screen vertical swipe feed (`ForYouFeedScreen`) with preloading and auto-play.
   - Interactive `LikeButton` with heart pop animation.
   - `CommentSheet` modal with instant commenting and timestamps.
   - Native platform sharing (`share_plus`) and bookmarking.

4. **Upload & Create Shot:**
   - Select video/audio media from device (`file_picker`).
   - Caption, hashtags, and visibility controls (Public, Followers, Private).
   - Direct upload to Supabase Storage (`shots` bucket) and database insertion with progress tracking (`UploadProgressCard`).

5. **Discover & Search:**
   - Search with debouncing, cache-first revalidation (`SearchCache`), and search history.
   - Curated category pills (Trending, New Releases, Bollywood, Punjabi, Hip-Hop, Chill & Lofi, EDM).

6. **Activity & Notifications:**
   - Inbox with activity filtering (All, Likes, Comments, Followers).
   - "Mark all as read" support.

7. **Audio & Background Playback:**
   - Lock-screen media notifications and controls via `audio_service`.
   - LRCLIB live-scrolling synced lyrics.
   - Sleep timer and cache management in `SettingsScreen`.

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
| **Success** | `#22C55E` | Positive confirmations |
| **Warning** | `#F59E0B` | Saved bookmarks, caution alerts |
| **Error** | `#EF4444` | Destructive actions, validation errors |
| **Text Main** | `#F8FAFC` | Primary headings and text |
| **Text Muted** | `#94A3B8` | Subtitles, timestamps, placeholders |
| **Border** | `#273044` | Card and input borders |

---

## 🏗️ Architecture & Project Structure

```
v-shots/
├── android/                   # Android native project (com.vshots.live)
│   ├── app/
│   │   ├── build.gradle       # Signing configs, compileSdk 36, versionCode 13
│   │   └── proguard-rules.pro # R8/Proguard optimization rules
│   └── ...
├── docs/                      # Deployment, security, and setup guides
│   ├── DEPLOYMENT.md          # CI/CD & Play Store release guide
│   ├── SECURITY.md            # Security policy and secret guidelines
│   └── SUPABASE_SETUP.md      # Database schema and RLS policies
├── lib/
│   ├── core/
│   │   ├── audio/             # Background AudioService handler & stream resolver
│   │   ├── backend/           # Supabase client & Google Auth service
│   │   ├── models/            # Shot, Profile, Comment, Notification data models
│   │   ├── services/          # Shots, Profiles, Notifications Supabase CRUD
│   │   ├── storage/           # LocalLibrary persistence (shared_preferences)
│   │   ├── theme/             # AppColors & AppTypography tokens
│   │   └── providers/         # Music repository & YouTube music provider
│   ├── features/
│   │   ├── auth/              # AuthModal (Sign in / Sign up)
│   │   ├── foryou/            # Vertical swipe ForYouFeedScreen
│   │   ├── onboarding/        # Onboarding carousel
│   │   ├── profile/           # ProfileScreen & EditProfileScreen
│   │   ├── notifications/     # NotificationsScreen
│   │   └── shots/             # UploadShotScreen & Shot detail
│   ├── shared/
│   │   └── widgets/           # AppButton, AppTextInput, AppCard, AppAvatar,
│   │                          # ShotCard, VideoPlayerCard, BottomTabBar, etc.
│   └── main.dart              # Entry point, SplashScreen, MainShell, Player
├── supabase/
│   └── migrations/            # SQL migration files with RLS & triggers
├── test/                      # 91 unit and widget tests (100% passing)
├── .env.example               # Environment variables template (no secrets)
└── pubspec.yaml               # Dependencies & assets configuration
```

---

## 🚀 Getting Started

### 1. Prerequisites

- Flutter SDK `^3.44.0` or `^3.47.0` (Dart `^3.10.0`)
- JDK 17+
- Android Studio / Android SDK (API 34+)

### 2. Configure Environment

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Fill in your configuration values:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GOOGLE_ANDROID_CLIENT_ID=your-android-client-id.apps.googleusercontent.com
GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

> **Security Rule:** Never commit `.env` or keystores to git. All `.env*` files are strictly gitignored.

### 3. Install Dependencies & Run Tests

```bash
flutter pub get
flutter analyze
flutter test
```

### 4. Run on Device / Emulator

```bash
flutter run
```

---

## 📦 Building Artifacts

### Debug APK
```bash
flutter build apk --debug
```
*Output: `build/app/outputs/flutter-apk/app-debug.apk`*

### Release AAB (Google Play Store)
```bash
export ANDROID_KEYSTORE_PATH="/path/to/release.keystore"
export ANDROID_KEYSTORE_PASSWORD="your-keystore-password"
export ANDROID_KEY_ALIAS="your-key-alias"
export ANDROID_KEY_PASSWORD="your-key-password"

flutter build appbundle --release
```
*Output: `build/app/outputs/bundle/release/app-release.aab`*

---

## 🔒 Security & Supabase Row Level Security (RLS)

Every table has Row Level Security enabled:

- **Profiles:** Publicly readable. Users can insert/update only their own profile (`auth.uid() = id`).
- **Shots:** Public shots viewable by all. Users can insert, update, or delete only their own shots (`auth.uid() = user_id`).
- **Likes:** Users can like/unlike only on their own behalf (`auth.uid() = user_id`).
- **Comments:** Viewable by everyone. Authors can create and delete only their own comments.
- **Bookmarks:** Visible only to the owner (`auth.uid() = user_id`).
- **Storage:** Authenticated users can upload media to `shots/`, `avatars/`, and `thumbnails/` buckets.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

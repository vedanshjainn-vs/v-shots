# 🔍 V Shots — Full Code Audit Report

**Date:** August 18, 2026  
**Version:** 5.8.0+42  
**Total Files:** 119 Dart files  
**Total Lines:** ~25,000+ lines of Dart

---

## 📊 Executive Summary

| Category | Status | Notes |
|----------|--------|-------|
| **Architecture** | ⚠️ Good but needs cleanup | main.dart is a 2549-line god file |
| **Code Quality** | ✅ Generally good | Well-documented, good error handling |
| **YouTube Compliance** | ✅ Excellent | Official IFrame player, no stream extraction |
| **State Management** | ⚠️ Basic | ValueNotifier pattern, no proper state management |
| **Backend (Supabase)** | ✅ Robust | Graceful degradation, never crashes app |
| **Recommendation Engine** | ✅ Advanced | Multi-signal scoring, diversity, exploration |
| **Test Coverage** | ✅ Present | Tests exist for core modules |
| **Security** | ⚠️ Needs attention | Some hardcoded values, missing .env keys |

---

## 🔴 Critical Issues

### 1. **main.dart is a God File (2549 lines)**
**File:** `lib/main.dart`

The main.dart file contains:
- `SearchScreen` widget (~400 lines)
- `ProfileScreen` widget (~600 lines)
- `LyricsScreen` widget (~80 lines)
- `playTrack()` function
- `addToQueueEnd()`, `playNextInQueue()` functions
- `showMoreOptionsSheet()`, `showAddToPlaylistSheet()` functions
- `_showSleepTimerDialog()` function
- `_handleCreatorUpload()` function
- `_CreatorGatingSheet` widget
- Global state variables (10+ ValueNotifiers)
- `SplashScreen`, `MainShell` widgets

**Impact:** Hard to maintain, test, and debug. Violates Single Responsibility Principle.

**Recommendation:** Split into:
- `lib/features/search/search_screen.dart`
- `lib/features/profile/profile_screen.dart`
- `lib/features/lyrics/lyrics_screen.dart`
- `lib/core/playback/playback_helpers.dart`
- `lib/shared/widgets/sheets/more_options_sheet.dart`
- `lib/shared/widgets/sheets/add_to_playlist_sheet.dart`

---

### 2. **Missing Critical API Keys**
**File:** `.env`

The following keys are **NOT configured** and will cause features to fail silently:

| Key | Status | Impact |
|-----|--------|--------|
| `YOUTUBE_DATA_API_KEY` | ❌ Missing | YouTube Data API v3 search/metadata disabled |
| `GOOGLE_WEB_CLIENT_ID` | ❌ Missing | Google Sign-In will fail |

**Current .env only has:**
- Supabase URL + Anon Key ✅
- Google Android Client ID ✅
- BrowserStack credentials ✅
- Android Keystore credentials ✅

**Action Required:** Get YouTube Data API key from Google Cloud Console and Google Web Client ID.

---

### 3. **Global Mutable State Scattered**
**Files:** `lib/main.dart`, various

There are **10+ global ValueNotifiers** at the top level:
```dart
final ValueNotifier<Map<String, dynamic>?> currentTrackNotifier
final ValueNotifier<bool> isPlayerExpandedNotifier
final ValueNotifier<int> currentTabIndexNotifier
final ValueNotifier<int> queueVersionNotifier
```

Plus global variables:
```dart
List<Map<String, dynamic>> currentQueue = []
int currentQueueIndex = 0
Map<String, dynamic>? currentTrack
bool isCurrentlyPlaying = false
RepeatMode repeatMode = RepeatMode.off
bool isShuffleOn = false
List<int> shuffleOrder = []
```

**Impact:** 
- Hard to track state changes
- Potential race conditions
- Difficult to test
- No single source of truth

**Recommendation:** Migrate to a proper state management solution (Riverpod recommended for this codebase).

---

## 🟡 Medium Issues

### 4. **Version Number Inconsistency**
| Location | Version |
|----------|---------|
| `pubspec.yaml` | 5.8.0+42 |
| `settings_screen.dart` | "Version 5.4.0 (Nova Release)" |
| `README.md` | 5.8.0 (Build 20) |

**Recommendation:** Update settings_screen.dart to read from pubspec or use a constant.

---

### 5. **Hardcoded Profile Data**
**File:** `lib/core/services/profile_service.dart` (lines 12-22)

```dart
ProfileModel _currentLocalProfile = const ProfileModel(
  id: 'self',
  username: 'vshots_creator',
  fullName: 'V Shots Creator',
  avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&q=80',
  bio: 'Creating short visual vibes & synth wave music on V Shots 🎬✨',
  followersCount: 1420,
  followingCount: 280,
  shotsCount: 12,
);
```

**Impact:** Shows fake data when user is not signed in. Misleading.

**Recommendation:** Use generic placeholder without fake numbers.

---

### 6. **ProfileService N+1 Query Problem**
**File:** `lib/core/services/profile_service.dart` (lines 50-70)

```dart
final shotsCount = await SupabaseService.client
    .from('shots').select('id').eq('user_id', user.id);
final followersCount = await SupabaseService.client
    .from('follows').select('follower_id').eq('following_id', user.id);
final followingCount = await SupabaseService.client
    .from('follows').select('following_id').eq('follower_id', user.id);
```

**Impact:** 3 separate queries when 1 could work. Slow on poor networks.

**Recommendation:** Use a Supabase RPC function or a single query with joins.

---

### 7. **No iOS Configuration**
Only Android configuration was provided:
- Package Name: `com.vshots.live`
- Keystore details
- SHA-1 fingerprints

**Impact:** App cannot be built for iOS without additional setup.

---

## 🟢 Minor Issues

### 8. **SearchCache No TTL Expiration**
**File:** `lib/core/cache/search_cache.dart`

The cache has `isFresh()` method but no automatic expiration. Old results may persist indefinitely.

---

### 9. **Inconsistent Error Handling**
Some places use `SnackBar`, others use `debugPrint`, some swallow errors silently.

---

### 10. **Missing `analysis_options.yaml` Strict Rules**
**File:** `analysis_options.yaml` exists but could be stricter with:
- `prefer_const_constructors`
- `avoid_print`
- `prefer_single_quotes`

---

## ✅ Strengths

### 1. **YouTube Compliance — Excellent**
- Official YouTube IFrame Player API
- No stream extraction (`youtube_explode_dart` removed)
- Clear "Powered by YouTube" attribution
- Foreground-only playback
- InnerTube for metadata only (never streams)

### 2. **Robust Error Handling**
```dart
// SupabaseService never crashes the app
try {
  await Supabase.initialize(url: url, anonKey: anonKey);
  _available = true;
} catch (e, st) {
  // Deliberately swallow — see file header
  _available = false;
}
```

### 3. **Well-Documented Code**
Every major file has:
- Purpose explanation
- Compliance notes
- Architecture decisions
- Known limitations

### 4. **Advanced Recommendation Engine**
- Multi-signal scoring (artist, song, genre, language, mood affinity)
- Diversity filtering
- Exploration/exploitation balance
- Session-level deduplication
- Seen-song penalties

### 5. **Hybrid Provider Architecture**
- InnerTube (primary metadata)
- YouTube Data API v3 (fallback)
- Curated catalog (offline resilience)
- Clean failover between providers

### 6. **Good Widget Structure**
- `AppColors` design tokens
- `AppTypography` text styles
- Reusable widgets (`AppButton`, `AppCard`, `AppImage`)
- Motion/animation system

---

## 📋 Recommendations (Priority Order)

| Priority | Task | Effort |
|----------|------|--------|
| 🔴 High | Split main.dart into feature files | 2-3 hours |
| 🔴 High | Add missing API keys (.env) | 30 mins |
| 🟡 Medium | Migrate to Riverpod for state management | 1-2 days |
| 🟡 Medium | Fix version inconsistency | 15 mins |
| 🟡 Medium | Fix ProfileService N+1 queries | 30 mins |
| 🟢 Low | Add stricter linting rules | 15 mins |
| 🟢 Low | Remove hardcoded profile mock data | 15 mins |

---

## 🎯 Quick Wins (Can do without asking)

1. Fix version in settings_screen.dart
2. Add YouTube Data API key placeholder in .env
3. Fix hardcoded profile placeholder

---

**Audit Complete** ✅

No changes were made to your codebase. This is a read-only report.

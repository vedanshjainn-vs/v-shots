# V SHOTS — MASTER DEVELOPMENT PROMPT

**For: Arena AI Agent / any dev agent continuing this build**

## QUICK REFERENCE

- **Package name:** `com.vshots.live`
- **YouTube backend:** `youtube_explode_dart ^3.1.0`
- **Audio:** `just_audio ^0.9.39`
- **Critical fix:** Multi-client fallback in `_resolveStream()` (androidVr → ios → android)

## WHAT WAS BROKEN (FIXED)

1. `youtube_explode_dart` was pinned to `^2.2.2` — the 403 fix only ships in 3.x
2. `getManifest()` had no explicit `ytClients` — now tries 3 clients with fallback

## NEXT PRIORITIES

1. **audio_service** background playback wrapper
2. **Extract AppColors/AppTextStyles** from magic literals in main.dart
3. **Split main.dart** into feature files
4. **Fix shuffle** (use Fisher-Yates, not DateTime-based random)
5. **Wire Library** to real Hive data
6. **Add lyrics** via LRCLIB (free, no API key)

## LEGAL NOTE

This uses unofficial YouTube APIs. Acceptable for personal/learning use only.
For commercial release, migrate to licensed music aggregator (7digital, Jamendo).

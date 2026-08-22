# V Shots — Privacy Policy

**Last Updated: August 2026**

## Introduction

V Shots ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how our mobile application (`com.vshots.live`) collects, uses, and safeguards information when you use our services.

## YouTube API Services & Embedded Playback

V Shots uses **YouTube API Services** (including YouTube Data API v3 where configured) and YouTube's public InnerTube web endpoints for music discovery and metadata (titles, channel names, thumbnails, durations).

**Playback:** YouTube videos are played by loading the official YouTube website (`youtube.com/watch`) inside a native Android WebView. V Shots does **not** use the YouTube IFrame Player API, does **not** extract or cache raw YouTube audio/video files, and does **not** skip, hide, speed up, or otherwise manipulate YouTube advertisements.

By using V Shots, you also agree to:
- **YouTube Terms of Service**: [https://www.youtube.com/t/terms](https://www.youtube.com/t/terms)
- **Google Privacy Policy**: [https://policies.google.com/privacy](https://policies.google.com/privacy)

V Shots is not affiliated with, endorsed by, or sponsored by YouTube or Google LLC.

## JioSaavn webpage playback

When a track is configured with a JioSaavn song permalink, V Shots may open that official `jiosaavn.com` webpage in the same WebView. We do not extract JioSaavn audio streams or media CDN URLs.

## Information We Collect

### 1. User-Provided Information
- **Account Data**: When you sign in with Supabase Authentication or Google OAuth, we receive your email address, full name, and avatar picture.
- **Library & Preferences**: Liked tracks, created playlists, and onboarding taste choices stored **on this device**.

### 2. Automatically Collected Information
- **Listening Signals & Taste Profile**: Play duration, completions, and skips stored locally on your device to personalize Home and Discover.
- **Device & Network Data**: Operating system version and connection status for playback.

## How We Use Information

We use collected information to:
- Deliver personalized music discovery.
- Enable playlist management and liked tracks on this device.
- Operate sign-in and (when you request it) account deletion.

## Data Retention & Storage

- Account identity is stored in Supabase with Row Level Security.
- Listening history and taste-profile metrics are stored locally via device storage.
- YouTube metadata is held ephemerally in memory/cache for discovery.

## Your Data Rights & Controls

- **Clear cache**: Settings → Clear Media & Search Cache.
- **Sign out**: ends the cloud session; local library data remains on the device unless you delete the account.
- **Delete Account**: if you are signed in, Delete Account calls a server-side function that removes your Auth user and associated cloud profile rows, then clears this device's library, history, signals, and session. This cannot be undone.
- **Google permissions**: [https://myaccount.google.com/permissions](https://myaccount.google.com/permissions)

## Advertising & Google AdMob

V Shots may display **in-app** native advertisements served by Google AdMob (separate from YouTube's own ads on youtube.com). YouTube ads inside the WebView are shown by YouTube and are not blocked or skipped by V Shots.

- **Advertising SDK**: Google Mobile Ads SDK for native ads inside V Shots UI when a production ad unit is configured.
- **Google UMP**: consent where required (EEA/UK).
- We do not sell your personal data.

## Contact Us

- **Email**: support@vshots.live
- **Repository**: [https://github.com/vedanshjainn-vs/v-shots](https://github.com/vedanshjainn-vs/v-shots)

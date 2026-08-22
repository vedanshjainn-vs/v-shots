-- ═════════════════════════════════════════════════════════════════════════════
-- V Shots — 00016 YouTube ad-assist feature flag
-- ═════════════════════════════════════════════════════════════════════════════
-- App-wide YouTube playback assist (owner request, 2026-08-22):
--   1. Early auto-advance: the next queued track starts ~1.5 s before the
--      current one ends (Home / Discover / playlists / queue — one WebView).
--   2. Ad assist: while the official YouTube player runs an in-stream ad the
--      ad is muted and YouTube's own "Skip" button is clicked when shown
--      (user-equivalent action only — nothing is blocked/hidden/sped up;
--      unskippable ads play muted in full). The main track is always
--      unmuted and auto-resumed after the ad.
-- Kill switch: set value=false to disable only the ad assist (auto-advance
-- stays on).
-- ═════════════════════════════════════════════════════════════════════════════

INSERT INTO feature_flags (key, value, description)
VALUES (
  'enable_youtube_ad_assist',
  true,
  'YouTube ad assist: mute in-stream ads + click the official Skip button + auto-resume the main track (player controls only, no blocking).'
)
ON CONFLICT (key) DO NOTHING;

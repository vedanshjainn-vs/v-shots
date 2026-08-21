-- V Shots — Phase 17.7: JioSaavn featured playlists (owner-provided URLs)
-- ---------------------------------------------------------------------------
-- Owner request: add these official JioSaavn featured playlist pages so they
-- show on Home WITHOUT any app update. The app's jiosaavn_playlist source
-- opens the official page in the WebView (no API, no scraping) — the page's
-- own player handles the whole playlist.
--
-- URLs verified HTTP 200 on 2026-08-21 (real jiosaavn.com featured pages).
-- Placement: a small JioSaavn block right after the YouTube Music groups
-- (sort 74-76), before the legacy search shelves (80+).
--
-- Also enables enable_jiosaavn_web_playback — WITHOUT it the app hides
-- JioSaavn sections entirely (safe production default). This is a remote
-- flag change only; the currently-shipped APK (Phase 17+ build) already
-- supports jiosaavn_playlist, so NO app update is needed.
--
-- Idempotent. No rows deleted.
-- ---------------------------------------------------------------------------

-- 1) The three featured playlists
insert into public.home_layout_config
  (id, section_key, title, subtitle, section_type, source_type,
   source_value, query, sort_order, visible, published, max_items,
   provider, playback_provider, fallback_provider, refresh_minutes)
values
  ('jsv_most_searched_hindi', 'jsv_most_searched_hindi',
   'Most Searched Songs - Hindi', 'JioSaavn · Featured Playlist',
   'home_section', 'jiosaavn_playlist',
   'https://www.jiosaavn.com/featured/most-searched-songs-hindi/csv-SfcHUmHc1EngHtQQ2g__',
   null, 74, true, true, 1, 'jiosaavn', 'jiosaavn', 'youtube', 360),
  ('jsv_best_of_90s', 'jsv_best_of_90s',
   'Best Of 90s - Hindi', 'JioSaavn · Featured Playlist',
   'home_section', 'jiosaavn_playlist',
   'https://www.jiosaavn.com/featured/best-of-90s-hindi/j44dgfQrkXY_',
   null, 75, true, true, 1, 'jiosaavn', 'jiosaavn', 'youtube', 360),
  ('jsv_arijit_sad', 'jsv_arijit_sad',
   'Arijit Singh - Sad Songs - Hindi', 'JioSaavn · Featured Playlist',
   'home_section', 'jiosaavn_playlist',
   'https://www.jiosaavn.com/featured/arijit-singh-sad-songs-hindi/8RkefqkCO1huOxiEGmm6lQ__',
   null, 76, true, true, 1, 'jiosaavn', 'jiosaavn', 'youtube', 360)
on conflict (id) do update set
  title = excluded.title,
  subtitle = excluded.subtitle,
  source_type = excluded.source_type,
  source_value = excluded.source_value,
  query = excluded.query,
  sort_order = excluded.sort_order,
  visible = excluded.visible,
  published = excluded.published,
  provider = excluded.provider,
  playback_provider = excluded.playback_provider,
  fallback_provider = excluded.fallback_provider;

-- 2) Enable JioSaavn webpage playback (remote flag — no app update)
update public.feature_flags
set value = true,
    updated_at = now()
where key = 'enable_jiosaavn_web_playback';

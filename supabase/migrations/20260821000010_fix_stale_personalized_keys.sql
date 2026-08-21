-- V Shots — Phase 17.5: repair stale personalized section_keys
-- ---------------------------------------------------------------------------
-- Root cause of the reported bug ("har section Continue Listening ban jata
-- hai"): the Admin panel preserved the personalized engine picker's
-- section_key when an editor switched the section to another type, and the
-- app used that key to decide the shelf kind. Production rows got corrupted:
--   trending_now    → key 'continue_listening' (was renamed to
--                     'Continue Listening 💖' by accident)
--   india_hits      → key 'continue_listening' (user intended a YT playlist)
--   jiosaavn_test   → key 'continue_listening' (test row, hidden)
--   e2e_playlist_test → key 'continue_listening' (temp test row, hidden)
--
-- This migration repairs the keys idempotently and preserves the editor's
-- actual content configuration (queries, URLs, max_items, visibility):
--   * trending_now is restored to its canonical catalog form.
--   * india_hits keeps the user's playlist URL; only the key is fixed.
--   * the two test rows keep their hidden state and get correct keys.
-- Safe to re-run. No rows are deleted.
-- ---------------------------------------------------------------------------

-- 1) Restore the canonical Trending Now shelf (was accidentally converted
--    into a Continue Listening duplicate).
update public.home_layout_config
set section_key = 'trending_now',
    title = 'Trending Now',
    subtitle = 'What the world is playing',
    section_type = 'home_section',
    source_type = 'youtube_search',
    source_value = 'trending songs official music video 2026',
    query = 'trending songs official music video 2026',
    region_code = null,
    max_items = 15
where id = 'trending_now';

-- 2) India Hits: keep the editor's playlist configuration, fix the key.
update public.home_layout_config
set section_key = 'india_hits'
where id = 'india_hits' and section_key <> 'india_hits';

-- 3) Hidden test rows: correct keys only (state untouched).
update public.home_layout_config
set section_key = 'jiosaavn_test'
where id = 'jiosaavn_test' and section_key <> 'jiosaavn_test';

update public.home_layout_config
set section_key = 'e2e_playlist_test'
where id = 'e2e_playlist_test' and section_key <> 'e2e_playlist_test';

-- 4) Guard: no visible/published non-personalized row may carry a
--    personalized key (safety net for any other corrupted rows).
update public.home_layout_config
set section_key = 'home_' || substr(md5(id || now()::text), 1, 8)
where source_type <> 'personalized'
  and section_type <> 'personalized'
  and section_key in (
    'continue', 'continue_listening', 'mfy', 'made_for_you', 'byld',
    'because_listened', 'because_you_listened', 'because_you_listened_to',
    'tfy', 'trending_for_you', 'discover', 'discover_something_new',
    'artists', 'artists_for_you', 'official', 'official_music'
  );

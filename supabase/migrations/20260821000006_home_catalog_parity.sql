-- V Shots — Home catalog parity seed (PHASE 2)
-- Purpose: every category that exists in the app's COMPILED default Home
-- (lib/features/home/home_feed_service.dart -> _buildDefaultShelves()) must
-- also exist as a CMS row so the Admin panel can manage it.
--
-- Behavior preservation rules (PHASE 3):
--   * Personalized categories (Trending For You, Artists For You, Official
--     Music, Discover Something New) are seeded with source_type
--     'personalized' + their stable section_key, so the app's key->kind map
--     routes them to the recommendation engine — NOT literal YouTube search.
--   * Continue Listening is intentionally NOT seeded: the app auto-inserts it
--     at the top of Home when no CMS row claims it (hasContinue logic).
--   * All new rows are seeded visible = false so today's live Home does NOT
--     change until an admin opts each category in via the Admin panel.
--   * on conflict do nothing: never clobbers admin edits.
-- Safe to re-run. Does not store secrets. Does not invent content.
-- Applied to live DB 2026-08-21.

insert into public.home_layout_config (
  id, section_key, title, subtitle, section_type, source_type,
  source_value, query, sort_order, visible, published, max_items, region_code
) values
  ('trending_for_you', 'trending_for_you', 'Trending For You',
   'Trending, ranked by your taste', 'personalized', 'personalized',
   'trending_for_you', null, 10, false, true, 12, null),
  ('artists_for_you', 'artists_for_you', 'Artists For You',
   'From your listening taste', 'personalized', 'personalized',
   'artists_for_you', null, 11, false, true, 10, null),
  ('official_music', 'official_music', 'Official Music',
   'Verified artist & label uploads', 'personalized', 'personalized',
   'official_music', null, 12, false, true, 12, null),
  ('discover_something_new', 'discover_something_new', 'Discover Something New',
   'Step outside your usual mix', 'personalized', 'personalized',
   'discover_something_new', null, 13, false, true, 12, null),
  ('hiphop', 'hiphop', 'Hip-Hop',
   'Rap & beats', 'home_section', 'youtube_search',
   'hip hop rap songs official audio', 'hip hop rap songs official audio',
   14, false, true, 12, null),
  ('romantic', 'romantic', 'Romantic',
   'Love songs', 'home_section', 'youtube_search',
   'romantic love songs official audio hindi', 'romantic love songs official audio hindi',
   15, false, true, 12, null),
  ('classics', 'classics', '90s Classics',
   'Evergreen hits', 'home_section', 'youtube_search',
   '90s 2000s evergreen bollywood classic songs', '90s 2000s evergreen bollywood classic songs',
   16, false, true, 12, null)
on conflict (id) do nothing;

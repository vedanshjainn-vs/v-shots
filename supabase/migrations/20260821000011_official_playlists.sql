-- V Shots — Phase 17.6: official YouTube Music playlist catalog
-- ---------------------------------------------------------------------------
-- Owner request: add the 37 official YouTube Music curated playlists as Home
-- sections, systematically arranged, and remove ALL test categories.
--
-- Arrangement (sort_order):
--   1-2    Core (personalized + trending)
--   10-15  Hits & Charts (6)
--   20-26  Top Charts weekly/top100 (7)
--   30-36  Bollywood (7 — #30 reuses the existing india_hits row whose URL
--          IS the Bollywood Hitlist playlist; no duplicate)
--   40-43  Baarish / Monsoon (4)
--   50-55  Regional — Punjabi/Haryanvi/Bhojpuri (6)
--   60-63  South Indian (4)
--   70-72  Other (3)
--   80-83  Legacy search shelves (International/Punjabi/Hindi Indie/LoFi)
--   91-97  Hidden opt-in shelves (unchanged visibility)
--
-- Test-category cleanup (DELETE — rows are dev/test artifacts only):
--   jiosaavn_test, e2e_playlist_test, the 'User Flow Test' rows.
--
-- Idempotent: playlists upsert on conflict (id) do update; deletes target
-- exact ids only. No user data touched.
-- ---------------------------------------------------------------------------

-- ── 1. Remove test categories ───────────────────────────────────────────────
delete from public.home_layout_config
where id = 'jiosaavn_test'
   or id = 'e2e_playlist_test'
   or lower(coalesce(title, '')) like '%user flow test%'
   or lower(coalesce(title, '')) like '%flow test%';

-- ── 2. Official playlists (idempotent upsert) ───────────────────────────────
insert into public.home_layout_config
  (id, section_key, title, subtitle, section_type, source_type,
   source_value, query, sort_order, visible, published, max_items,
   provider, playback_provider, fallback_provider, refresh_minutes)
values
  -- Hits & Charts
  ('hits_2026', 'hits_2026', 'Hits of 2026 (So Far)', 'YouTube Music · Hits & Charts',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_kCicKSTh7ylcZSwvrN0vV4dI3eqEpXR4A', null, 10, true, true, 20, 'auto', 'auto', 'none', 360),
  ('the_hit_list', 'the_hit_list', 'The Hit List', 'YouTube Music · Hits & Charts',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_kmPRjHDECIcuVwnKsx2Ng7fyNgFKWNJFs', null, 11, true, true, 20, 'auto', 'auto', 'none', 360),
  ('released', 'released', 'RELEASED', 'YouTube Music · Hits & Charts',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_ksEjgm3H_7zOJ_RHzRjN1wY-_FFcs7aAU', null, 12, true, true, 20, 'auto', 'auto', 'none', 360),
  ('pop_before_it_breaks', 'pop_before_it_breaks', 'Pop Before It Breaks', 'YouTube Music · Hits & Charts',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_kkkZR6KAV5kBSqDCeaBb_pDDhA83VGFwg', null, 13, true, true, 20, 'auto', 'auto', 'none', 360),
  ('ipop_hits', 'ipop_hits', 'I-Pop Hits!', 'YouTube Music · Hits & Charts',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_lj-zBExVYl7YN_NxXboDIh4A-wKGfgzNY', null, 14, true, true, 20, 'auto', 'auto', 'none', 360),
  ('new_music_videos', 'new_music_videos', 'New Music Videos', 'YouTube Music · Hits & Charts',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=OLZy5IP9FKwvoxKpxGYLUO7ErQdOxKYL1tg', null, 15, true, true, 20, 'auto', 'auto', 'none', 360),

  -- Top Charts
  ('top_weekly_hindi', 'top_weekly_hindi', 'Top Weekly Videos Hindi', 'YouTube Top Charts · Weekly',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=PL4fGSI1pDJn5RgLW0Sb_zECecWdH_4zOX', null, 20, true, true, 20, 'auto', 'auto', 'none', 360),
  ('top_weekly_punjabi', 'top_weekly_punjabi', 'Top Weekly Videos Punjabi', 'YouTube Top Charts · Weekly',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=PL4fGSI1pDJn5JXkyIohg2RstsbL2SnRew', null, 21, true, true, 20, 'auto', 'auto', 'none', 360),
  ('top_weekly_bhojpuri', 'top_weekly_bhojpuri', 'Top Weekly Videos Bhojpuri', 'YouTube Top Charts · Weekly',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=PL4fGSI1pDJn4ivDqrsepD3tvHsp0KTDRM', null, 22, true, true, 20, 'auto', 'auto', 'none', 360),
  ('top_weekly_haryanvi', 'top_weekly_haryanvi', 'Top Weekly Videos Haryanvi', 'YouTube Top Charts · Weekly',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=PL4fGSI1pDJn4tiNLMZVGGt2Kghgw__2u0', null, 23, true, true, 20, 'auto', 'auto', 'none', 360),
  ('top100_india', 'top100_india', 'Top 100 Songs India', 'YouTube Top Charts · Top 100',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=PL4fGSI1pDJn4pTWyM3t61lOyZ6_4jcNOw', null, 24, true, true, 20, 'auto', 'auto', 'none', 360),
  ('top100_global', 'top100_global', 'Top 100 Songs Global', 'YouTube Top Charts · Top 100',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i', null, 25, true, true, 20, 'auto', 'auto', 'none', 360),
  ('trending20_india', 'trending20_india', 'Trending 20 India', 'YouTube Top Charts · Trending',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=OLAK5uy_lSTp1DIuzZBUyee3kDsXwPgP25WdfwB40', null, 26, true, true, 20, 'auto', 'auto', 'none', 360),

  -- Bollywood (india_hits = Bollywood Hitlist is updated separately below)
  ('bollywood_romance', 'bollywood_romance', 'Bollywood Romance Hitlist', 'YouTube Music · Bollywood',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_mypHeJ-B5f7-OgrxJcXeiHSotjIJ_UDhQ', null, 31, true, true, 20, 'auto', 'auto', 'none', 360),
  ('bollywood_party', 'bollywood_party', 'Bollywood Party', 'YouTube Music · Bollywood',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_l_Bj8rMsjkhFMMs-eLrA17_zjr9r6g_Eg', null, 32, true, true, 20, 'auto', 'auto', 'none', 360),
  ('uncut_bollywood', 'uncut_bollywood', 'Uncut Bollywood', 'YouTube Music · Bollywood',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_krbBs7P2iEb30IODyVbiOXWyhZtAIX9Uk', null, 33, true, true, 20, 'auto', 'auto', 'none', 360),
  ('bollywood_retro', 'bollywood_retro', 'Bollywood Retro Essentials', 'YouTube Music · Bollywood',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_mLJf8i5vYsqR7oTk6CNO4Ge49J3OU4sRs', null, 34, true, true, 20, 'auto', 'auto', 'none', 360),
  ('make_out_jams', 'make_out_jams', 'Make Out Jams: Bollywood', 'YouTube Music · Bollywood',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_lbfDqlFOiRJekoTwNgiES65gcham4ZelA', null, 35, true, true, 20, 'auto', 'auto', 'none', 360),
  ('new_music_hindi', 'new_music_hindi', 'New Music Hindi', 'YouTube Music · Bollywood',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_nNhhgRET3NcJ4SJBvqhAIJ6t7vjsQYowc', null, 36, true, true, 20, 'auto', 'auto', 'none', 360),

  -- Baarish / Monsoon
  ('chai_baarish_90s', 'chai_baarish_90s', 'Chai, Baarish aur 90s', 'YouTube Music · Monsoon',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_lycab9oGCf-Wrf032tl6Lxn2W68QjdXls', null, 40, true, true, 20, 'auto', 'auto', 'none', 360),
  ('baarish_chill', 'baarish_chill', 'Baarish aur Chill', 'YouTube Music · Monsoon',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_nlKphX00YtBNjlGZcmPifGNAPXUSjezNM', null, 41, true, true, 20, 'auto', 'auto', 'none', 360),
  ('romancing_rains', 'romancing_rains', 'Romancing the Rains', 'YouTube Music · Monsoon',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_lPzT2bIPNJ_6II2vlgcE_-Mw1fMTfPheA', null, 42, true, true, 20, 'auto', 'auto', 'none', 360),
  ('retro_baarish', 'retro_baarish', 'Retro Baarish', 'YouTube Music · Monsoon',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_lBa7h-v-su4TAsDNvyelrswt9YYYU7x4g', null, 43, true, true, 20, 'auto', 'auto', 'none', 360),

  -- Regional — Punjabi / Haryanvi / Bhojpuri
  ('punjab_fire', 'punjab_fire', 'Punjab Fire', 'YouTube Music · Punjabi',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_kuo_NioExeUmw07dFf8BzQ64DFFTlgE7Q', null, 50, true, true, 20, 'auto', 'auto', 'none', 360),
  ('punjabi_party', 'punjabi_party', 'Punjabi Party', 'YouTube Music · Punjabi',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_nlOMew8qv8HGXb9HbshuU1OgH3aL_JMKA', null, 51, true, true, 20, 'auto', 'auto', 'none', 360),
  ('punjabi_romance', 'punjabi_romance', 'Punjabi Romance Hitlist', 'YouTube Music · Punjabi',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_mUvTtdERIHEiVAHIkV3GRndrY-H4M2nnA', null, 52, true, true, 20, 'auto', 'auto', 'none', 360),
  ('new_music_punjabi', 'new_music_punjabi', 'New Music Punjabi', 'YouTube Music · Punjabi',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_mk3xwsayv9PxawuXS-U6ao9eMeNmSwYAM', null, 53, true, true, 20, 'auto', 'auto', 'none', 360),
  ('haryanvi_party', 'haryanvi_party', 'Haryanvi Party', 'YouTube Music · Regional',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_mN9vO_dypsJubNdWlO5JSTtCA0SI3o-88', null, 54, true, true, 20, 'auto', 'auto', 'none', 360),
  ('bhojpuri_party', 'bhojpuri_party', 'Bhojpuri Party', 'YouTube Music · Regional',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_n7VIYx-oWOJQanlpBG6GRyLZxpWYMltB8', null, 55, true, true, 20, 'auto', 'auto', 'none', 360),

  -- South Indian
  ('tollywood_hitlist', 'tollywood_hitlist', 'Tollywood Hitlist', 'YouTube Music · Telugu',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_lyVnWI5JnuwKJiuE-n1x-Un0mj9WlEyZw', null, 60, true, true, 20, 'auto', 'auto', 'none', 360),
  ('kollywood_hitlist', 'kollywood_hitlist', 'Kollywood Hitlist', 'YouTube Music · Tamil',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_nTbyVypdXPQd00z15bTWjZr7pG-26yyQ4', null, 61, true, true, 20, 'auto', 'auto', 'none', 360),
  ('tollywood_party', 'tollywood_party', 'Tollywood Party', 'YouTube Music · Telugu',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_nGC5IUV3lYF-P_wGb-LzMPFydA-RkPblc', null, 62, true, true, 20, 'auto', 'auto', 'none', 360),
  ('new_music_telugu', 'new_music_telugu', 'New Music Telugu', 'YouTube Music · Telugu',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_l8CaYQvBQWVT2st1VsW9JjODWisR_vd3U', null, 63, true, true, 20, 'auto', 'auto', 'none', 360),

  -- Other
  ('desi_pop_party', 'desi_pop_party', 'Desi Pop Party', 'YouTube Music · Desi Pop',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_m_cn307EUnwiDOgAsOMM27CHhuJCX2ygk', null, 70, true, true, 20, 'auto', 'auto', 'none', 360),
  ('90s_bollywood_dance', '90s_bollywood_dance', '90s Bollywood Dance', 'YouTube Music · Retro',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_kiDNaS5nAXxdzsqFElFKKKs0GUEFJE26w', null, 71, true, true, 20, 'auto', 'auto', 'none', 360),
  ('hiphop_hits', 'hiphop_hits', 'All-Time Hip Hop Hits', 'YouTube Music · Hip-Hop',
   'home_section', 'youtube_playlist',
   'https://youtube.com/playlist?list=RDCLAK5uy_kw2wIlEv9llILhO0qoMTLsBBhmjzuibAc', null, 72, true, true, 20, 'auto', 'auto', 'none', 360)
on conflict (id) do update set
  title = excluded.title,
  subtitle = excluded.subtitle,
  source_type = excluded.source_type,
  source_value = excluded.source_value,
  query = excluded.query,
  sort_order = excluded.sort_order,
  visible = excluded.visible,
  published = excluded.published,
  max_items = excluded.max_items;

-- ── 3. Reuse india_hits as the Bollywood Hitlist entry (same URL, no dup) ───
update public.home_layout_config
set title = 'Bollywood Hitlist',
    subtitle = 'YouTube Music · Bollywood',
    section_type = 'home_section',
    source_type = 'youtube_playlist',
    source_value = 'https://youtube.com/playlist?list=RDCLAK5uy_n9Fbdw7e6ap-98_A-8JYBmPv64v-Uaq1g',
    query = null,
    sort_order = 30,
    visible = true,
    published = true,
    max_items = 20,
    provider = 'auto',
    playback_provider = 'auto',
    fallback_provider = 'none'
where id = 'india_hits';

-- ── 4. Core + legacy arrangement ────────────────────────────────────────────
update public.home_layout_config set sort_order = 1 where id = 'made_for_you';
update public.home_layout_config set sort_order = 2 where id = 'trending_now';
update public.home_layout_config set sort_order = 3 where id = 'because_listened';
update public.home_layout_config set sort_order = 80 where id = 'international';
update public.home_layout_config set sort_order = 81 where id = 'punjabi';
update public.home_layout_config set sort_order = 82 where id = 'hindi_indie';
update public.home_layout_config set sort_order = 83 where id = 'chill_lofi';
update public.home_layout_config set sort_order = 91 where id = 'trending_for_you';
update public.home_layout_config set sort_order = 92 where id = 'artists_for_you';
update public.home_layout_config set sort_order = 93 where id = 'official_music';
update public.home_layout_config set sort_order = 94 where id = 'discover_something_new';
update public.home_layout_config set sort_order = 95 where id = 'hiphop';
update public.home_layout_config set sort_order = 96 where id = 'romantic';
update public.home_layout_config set sort_order = 97 where id = 'classics';

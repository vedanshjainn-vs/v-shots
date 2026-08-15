-- ═════════════════════════════════════════════════════════════════════════
-- V Shots — Runtime-Editable Playlists (Supabase `configured_playlists`)
--
-- Run this ONCE in the Supabase SQL editor. It creates the table that lets
-- you add / remove / rename V Shots' Home playlist sections WITHOUT an app
-- update:
--     • add a row    -> the playlist appears on Home on the next refresh
--     • edit title   -> the section is renamed (no app update)
--     • set active=0 -> the section disappears
--
-- The app also resolves the REAL YouTube playlist title/artwork whenever a
-- live API key is present, so the row `title` is only the offline fallback.
-- ═════════════════════════════════════════════════════════════════════════

create table if not exists public.configured_playlists (
  id text primary key,
  playlist_id text not null,
  title text not null default 'YouTube Music Playlist',
  category text not null default 'More From YouTube Music',
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.configured_playlists enable row level security;

drop policy if exists "public read configured_playlists" on public.configured_playlists;
create policy "public read configured_playlists" on public.configured_playlists
  for select using (true);

-- Seed with the user's real, verified playlist ids. Edit rows anytime.
insert into public.configured_playlists
  (id, playlist_id, title, category, sort_order) values
    ('p01','RDCLAK5uy_kCicKSTh7ylcZSwvrN0vV4dI3eqEpXR4A','Trending Now Mix','More From YouTube Music',1),
    ('p02','RDCLAK5uy_n9Fbdw7e6ap-98_A-8JYBmPv64v-Uaq1g','New Music Mix','More From YouTube Music',2),
    ('p03','PL4fGSI1pDJn4tiNLMZVGGt2Kghgw__2u0','Top Hits','More From YouTube Music',3),
    ('p04','RDCLAK5uy_kuo_NioExeUmw07dFf8BzQ64DFFTlgE7Q','Global Pop Mix','More From YouTube Music',4),
    ('p05','RDCLAK5uy_lj-zBExVYl7YN_NxXboDIh4A-wKGfgzNY','Bollywood Mix','More From YouTube Music',5),
    ('p06','RDCLAK5uy_lyVnWI5JnuwKJiuE-n1x-Un0mj9WlEyZw','Hindi Hits Mix','More From YouTube Music',6),
    ('p07','RDCLAK5uy_nTbyVypdXPQd00z15bTWjZr7pG-26yyQ4','Punjabi Mix','More From YouTube Music',7),
    ('p08','PL4fGSI1pDJn5RgLW0Sb_zECecWdH_4zOX','Romantic Hits','More From YouTube Music',8),
    ('p09','PL4fGSI1pDJn5JXkyIohg2RstsbL2SnRew','Chill & Lo-Fi','More From YouTube Music',9),
    ('p10','PL4fGSI1pDJn4ivDqrsepD3tvHsp0KTDRM','Workout Energy','More From YouTube Music',10),
    ('p11','RDCLAK5uy_ksEjgm3H_7zOJ_RHzRjN1wY-_FFcs7aAU','Party Mix','More From YouTube Music',11),
    ('p12','RDCLAK5uy_nNhhgRET3NcJ4SJBvqhAIJ6t7vjsQYowc','Sad Songs Mix','More From YouTube Music',12),
    ('p13','RDCLAK5uy_kkkZR6KAV5kBSqDCeaBb_pDDhA83VGFwg','Devotional Mix','More From YouTube Music',13),
    ('p14','RDCLAK5uy_mk3xwsayv9PxawuXS-U6ao9eMeNmSwYAM','EDM Mix','More From YouTube Music',14),
    ('p15','RDCLAK5uy_l8CaYQvBQWVT2st1VsW9JjODWisR_vd3U','Indie Mix','More From YouTube Music',15),
    ('p16','RDCLAK5uy_kmPRjHDECIcuVwnKsx2Ng7fyNgFKWNJFs','Hip-Hop Mix','More From YouTube Music',16),
    ('p17','RDCLAK5uy_lPzT2bIPNJ_6II2vlgcE_-Mw1fMTfPheA','English Pop Mix','More From YouTube Music',17),
    ('p18','RDCLAK5uy_lycab9oGCf-Wrf032tl6Lxn2W68QjdXls','Road Trip Mix','More From YouTube Music',18),
    ('p19','RDCLAK5uy_nlKphX00YtBNjlGZcmPifGNAPXUSjezNM','Focus & Study','More From YouTube Music',19),
    ('p20','RDCLAK5uy_lBa7h-v-su4TAsDNvyelrswt9YYYU7x4g','Acoustic Mix','More From YouTube Music',20),
    ('p21','RDCLAK5uy_krbBs7P2iEb30IODyVbiOXWyhZtAIX9Uk','90s Hits','More From YouTube Music',21),
    ('p22','PL4fGSI1pDJn4pTWyM3t61lOyZ6_4jcNOw','Sufi & Ghazals','More From YouTube Music',22),
    ('p23','OLAK5uy_lSTp1DIuzZBUyee3kDsXwPgP25WdfwB40','Featured Album','More From YouTube Music',23),
    ('p24','PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i','Party Bangers','More From YouTube Music',24),
    ('p25','RDCLAK5uy_l_Bj8rMsjkhFMMs-eLrA17_zjr9r6g_Eg','Trending Mix 2','More From YouTube Music',25),
    ('p26','RDCLAK5uy_nlOMew8qv8HGXb9HbshuU1OgH3aL_JMKA','Fresh Mix','More From YouTube Music',26),
    ('p27','RDCLAK5uy_nGC5IUV3lYF-P_wGb-LzMPFydA-RkPblc','New Music Mix 2','More From YouTube Music',27),
    ('p28','RDCLAK5uy_m_cn307EUnwiDOgAsOMM27CHhuJCX2ygk','Top 40 Mix','More From YouTube Music',28),
    ('p29','RDCLAK5uy_n7VIYx-oWOJQanlpBG6GRyLZxpWYMltB8','Morning Mix','More From YouTube Music',29),
    ('p30','RDCLAK5uy_mN9vO_dypsJubNdWlO5JSTtCA0SI3o-88','Night Mix','More From YouTube Music',30),
    ('p31','RDCLAK5uy_mypHeJ-B5f7-OgrxJcXeiHSotjIJ_UDhQ','Chill Mix','More From YouTube Music',31),
    ('p32','RDCLAK5uy_lbfDqlFOiRJekoTwNgiES65gcham4ZelA','Love Mix','More From YouTube Music',32),
    ('p33','RDCLAK5uy_mUvTtdERIHEiVAHIkV3GRndrY-H4M2nnA','Energy Mix','More From YouTube Music',33),
    ('p34','RDCLAK5uy_mLJf8i5vYsqR7oTk6CNO4Ge49J3OU4sRs','Indie & Acoustic','More From YouTube Music',34),
    ('p35','RDCLAK5uy_kw2wIlEv9llILhO0qoMTLsBBhmjzuibAc','Global Mix','More From YouTube Music',35),
    ('p36','OLZy5IP9FKwvoxKpxGYLUO7ErQdOxKYL1tg','YouTube Music','More From YouTube Music',36),
    ('p37','RDCLAK5uy_kiDNaS5nAXxdzsqFElFKKKs0GUEFJE26w','Fresh Picks','More From YouTube Music',37),
on conflict (id) do update set
  playlist_id = excluded.playlist_id,
  title = excluded.title,
  category = excluded.category,
  sort_order = excluded.sort_order,
  updated_at = now();

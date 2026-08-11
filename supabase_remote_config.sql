-- ═════════════════════════════════════════════════════════════════════════
-- V Shots — Remote Config Tables (Section 3)
--
-- Run this in the Supabase SQL editor ONCE. These tables let Home layout and
-- the Discovery category list be changed WITHOUT an app update. Both tables
-- are read via the anon key (RLS: SELECT enabled so the client can fetch the
-- config). Content/layout changes are just row edits in the dashboard.
-- ═════════════════════════════════════════════════════════════════════════

-- 1. Discovery categories (drives Section 1's filter list + queries).
create table if not exists public.discovery_categories (
  id text primary key,
  name text not null,
  emoji text not null default '🎵',
  query text not null,
  fallback_category text not null default 'global',
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. Home layout config (drives which Home sections appear, their order,
--    title, query, and how many items each shows).
create table if not exists public.home_layout_config (
  id text primary key,
  section_key text not null,
  title text not null,
  section_type text not null default 'category', -- category | curated
  query text,
  sort_order integer not null default 0,
  visible boolean not null default true,
  max_items integer not null default 15,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- RLS: allow anyone (anon) to read these config tables so the app can fetch
-- them without auth. Writes are restricted to authenticated/owners only.
alter table public.discovery_categories enable row level security;
alter table public.home_layout_config enable row level security;

drop policy if exists "public read discovery_categories" on public.discovery_categories;
create policy "public read discovery_categories" on public.discovery_categories
  for select using (true);

drop policy if exists "public read home_layout_config" on public.home_layout_config;
create policy "public read home_layout_config" on public.home_layout_config
  for select using (true);

-- Seed the discovery categories to match the compiled defaults (so remote
-- config == local default on first run). Insert-on-conflict keeps edits.
insert into public.discovery_categories (id, name, emoji, query, fallback_category, sort_order)
values
  ('trending','Trending Hits','🌟','trending songs 2026 official video','global',1),
  ('latenight','Late Night Chill','🌙','chill late night songs official','ambient',2),
  ('romantic','Romantic & Love','💖','romantic love songs hindi punjabi official','bollywood',3),
  ('party','Party & Dance','🔥','party dance songs bollywood punjabi official','punjabi',4),
  ('workout','Gym & Hype','⚡','gym workout hype songs official','workout',5),
  ('sad','Heartbroken & Sad','🌧️','sad heartbreak songs hindi official','nostalgia',6),
  ('focus','Focus & Study','🧘','lofi focus study instrumental','ambient',7),
  ('roadtrip','Road Trip Drive','🚗','road trip driving songs playlist official','workout',8),
  ('bollywood','Bollywood Hits','🎬','bollywood hit songs official video','bollywood',9),
  ('punjabi','Punjabi Bangers','🎸','punjabi songs official video 2026','punjabi',10),
  ('indie','Hindi Indie','🎧','hindi indie music official','indie',11),
  ('global','Global Pop 100','🌍','global pop hits official video','global',12),
  ('devotional','Devotional & Bhajans','🙏','bhajan devotional songs official','devotional',13),
  ('sufi','Sufi & Ghazals','✨','sufi ghazal songs official','sufi',14),
  ('nostalgia','90s Nostalgia','📻','90s hindi songs official','nostalgia',15),
  ('wedding','Wedding & Sangeet','💍','wedding sangeet songs bollywood official','bollywood',16),
  ('monsoon','Monsoon Vibes','☔','monsoon rain songs hindi official','bollywood',17),
  ('motivational','Motivational','🏆','motivational songs hindi official','global',18)
on conflict (id) do update set
  name = excluded.name,
  emoji = excluded.emoji,
  query = excluded.query,
  fallback_category = excluded.fallback_category,
  sort_order = excluded.sort_order,
  updated_at = now();

-- Seed the default Home layout (matches the app's current sections).
insert into public.home_layout_config (id, section_key, title, section_type, query, sort_order, visible, max_items)
values
  ('trending_now','trending_now','Trending Now','category','trending songs 2026 official video',1,true,15),
  ('new_releases','new_releases','New Releases','category','new music releases official audio 2026',2,true,15),
  ('made_for_you','made_for_you','Made For You','category','made for you personalized',3,true,12),
  ('because_listened','because_listened','Because You Listened To','category','because you listened to',4,true,12),
  ('india_hits','india_hits','India Hits','category','top bollywood hindi songs official',5,true,15),
  ('punjabi','punjabi','Punjabi Bangers','category','latest punjabi pop hits official audio',6,true,15),
  ('hindi_indie','hindi_indie','Hindi Indie','category','hindi indie acoustic songs official audio',7,true,15),
  ('international','international','International Pop','category','billboard top global pop hits official audio',8,true,15),
  ('chill_lofi','chill_lofi','Chill & LoFi','category','chill lofi late night beats official audio',9,true,15)
on conflict (id) do update set
  title = excluded.title,
  section_type = excluded.section_type,
  query = excluded.query,
  sort_order = excluded.sort_order,
  visible = excluded.visible,
  max_items = excluded.max_items,
  updated_at = now();

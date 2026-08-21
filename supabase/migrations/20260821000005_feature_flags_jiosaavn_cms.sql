-- V Shots — feature flags, Discover category kinds, unpublished JioSaavn test
-- section. Safe to re-run. Does not store secrets. Does NOT invent a
-- JioSaavn song permalink.

insert into public.feature_flags (key, value, description) values
  ('enable_remote_home', true, 'Fetch Home config from Supabase'),
  ('enable_jiosaavn_web_playback', false, 'Enable JioSaavn webpage playback in the native WebView'),
  ('enable_jiosaavn_search_fallback', false, 'If no exact JioSaavn permalink, open JioSaavn search'),
  ('enable_discovery_remote_categories', false, 'Discover uses published Supabase categories'),
  ('enable_social', false, 'Show comments / creator / UGC surfaces')
on conflict (key) do nothing;

create table if not exists public.discovery_categories (
  id text primary key,
  name text not null,
  emoji text,
  query text,
  fallback_category text default 'global',
  sort_order integer not null default 0,
  active boolean not null default true,
  kind text not null default 'source',
  token text,
  ranking_order text default 'relevance',
  visible boolean not null default true,
  updated_at timestamptz default now()
);

alter table public.discovery_categories
  add column if not exists kind text default 'source',
  add column if not exists token text,
  add column if not exists ranking_order text default 'relevance',
  add column if not exists visible boolean not null default true;

alter table public.discovery_categories enable row level security;

drop policy if exists "public read discovery_categories" on public.discovery_categories;
create policy "public read discovery_categories" on public.discovery_categories
  for select using (true);

-- Unpublished placeholder. Admin must paste a real https://www.jiosaavn.com/song/...
-- permalink before publishing. No opaque id is generated here.
insert into public.home_layout_config (
  id, section_key, title, subtitle, section_type, source_type,
  source_value, query, sort_order, visible, max_items, published
) values (
  'jiosaavn_test',
  'jiosaavn_test',
  'JioSaavn Test',
  'Paste an exact JioSaavn song permalink in Admin, then publish.',
  'home_section',
  'jiosaavn_manual',
  '',
  '',
  90,
  false,
  8,
  false
) on conflict (id) do nothing;

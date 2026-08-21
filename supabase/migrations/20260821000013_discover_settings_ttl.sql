-- V Shots — Phase 17.8: Discover algorithm settings + faster CMS pickup
-- ---------------------------------------------------------------------------
-- 1. discover_settings: ONE jsonb config row the Admin Discover page edits
--    and the app's DiscoverFeedEngine reads (defaults merge client-side).
--    Content-only table (no user data) → public read/write like the other
--    CMS tables in public mode.
-- 2. Home pickup speed: cap refresh_minutes at 60 for all CMS rows so the
--    app's config TTL (min over sections) stays ≤ 1 hour after admin edits.
-- Idempotent. No data rows deleted.
-- ---------------------------------------------------------------------------

create table if not exists public.discover_settings (
  id text primary key default 'current',
  config jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.discover_settings enable row level security;
drop policy if exists "public read discover_settings" on public.discover_settings;
create policy "public read discover_settings" on public.discover_settings
  for select using (true);
drop policy if exists "public write discover_settings" on public.discover_settings;
create policy "public write discover_settings" on public.discover_settings
  for all to anon, authenticated using (true) with check (true);

insert into public.discover_settings (id, config)
values (
  'current',
  '{
    "weights": {"personal": 50, "trending": 25, "fresh": 15, "exploration": 10},
    "enabled": {
      "personalization": true,
      "trending": true,
      "fresh": true,
      "exploration": true
    },
    "region": "IN",
    "explore_queries": [
      "punjabi hit songs official audio",
      "telugu hit songs official audio",
      "english indie songs official audio",
      "lofi chill beats official audio",
      "hip hop rap official audio"
    ]
  }'::jsonb
)
on conflict (id) do nothing;

-- Faster pickup after admin edits: every section ≤ 60 min refresh.
update public.home_layout_config
set refresh_minutes = 60
where refresh_minutes is null or refresh_minutes > 60;

-- ═════════════════════════════════════════════════════════════════════════
-- V Shots — Music Data Migrations (Phase 8, Youtify architecture refinement)
--
-- ADDS new tables for the music product WITHOUT breaking existing social/creator
-- tables (profiles, shots, likes, comments, follows, bookmarks, notifications)
-- or the remote-config tables (discovery_categories, home_layout_config).
--
-- Run this in the Supabase SQL editor ONCE, after supabase_setup.sql.
--
-- New tables:
--   tracks, artists, playlists, playlist_tracks,
--   user_likes, recently_played, user_taste_profile, recommendation_events
--
-- RLS is enabled on every new table. Users can only modify their OWN rows.
-- ═════════════════════════════════════════════════════════════════════════

-- ── 1. artists ────────────────────────────────────────────────────────────
create table if not exists public.artists (
  id text primary key,                 -- canonical artist id / YouTube channel id
  name text not null,
  genre text,
  channel_id text,
  avatar_url text,
  verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ── 2. tracks ────────────────────────────────────────────────────────────
create table if not exists public.tracks (
  id text primary key,                 -- YouTube video id
  youtube_video_id text not null,
  title text not null,
  artist_id text references public.artists(id),
  artist_name text not null default '',
  thumbnail_url text,
  duration_seconds integer not null default 0,
  genre text,
  language text,
  vibe text,
  published_at timestamptz,
  created_at timestamptz not null default now()
);

-- ── 3. playlists ──────────────────────────────────────────────────────────
create table if not exists public.playlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  name text not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ── 4. playlist_tracks ────────────────────────────────────────────────────
create table if not exists public.playlist_tracks (
  id uuid primary key default gen_random_uuid(),
  playlist_id uuid references public.playlists(id) on delete cascade not null,
  track_id text references public.tracks(id) on delete cascade not null,
  position integer not null default 0,
  added_at timestamptz not null default now(),
  unique (playlist_id, track_id)
);

-- ── 5. user_likes ─────────────────────────────────────────────────────────
create table if not exists public.user_likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  video_id text not null,
  title text not null default '',
  artist text not null default '',
  thumbnail text,
  created_at timestamptz not null default now(),
  unique (user_id, video_id)
);

-- ── 6. recently_played ────────────────────────────────────────────────────
create table if not exists public.recently_played (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  video_id text not null,
  title text not null default '',
  artist text not null default '',
  thumbnail text,
  played_at timestamptz not null default now(),
  completed boolean not null default false,
  play_count integer not null default 1,
  unique (user_id, video_id)
);

-- ── 7. user_taste_profile ─────────────────────────────────────────────────
create table if not exists public.user_taste_profile (
  user_id uuid primary key references auth.users(id) on delete cascade not null,
  profile jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- ── 8. recommendation_events ──────────────────────────────────────────────
create table if not exists public.recommendation_events (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  event_type text not null,            -- song_play, song_complete, song_skip, song_like, ...
  video_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_recommendation_events_user
  on public.recommendation_events (user_id, created_at desc);

-- ── RLS: enable on all new tables ─────────────────────────────────────────
alter table public.artists enable row level security;
alter table public.tracks enable row level security;
alter table public.playlists enable row level security;
alter table public.playlist_tracks enable row level security;
alter table public.user_likes enable row level security;
alter table public.recently_played enable row level security;
alter table public.user_taste_profile enable row level security;
alter table public.recommendation_events enable row level security;

-- ── Policies: read-mostly for catalog, owner-only for user data ───────────

-- artists / tracks: public catalog, read by everyone; writes restricted (admin).
drop policy if exists "public read artists" on public.artists;
create policy "public read artists" on public.artists for select using (true);
drop policy if exists "public read tracks" on public.tracks;
create policy "public read tracks" on public.tracks for select using (true);

-- playlists: users manage their own playlists.
drop policy if exists "users read own playlists" on public.playlists;
create policy "users read own playlists" on public.playlists
  for select using (auth.uid() = user_id);
drop policy if exists "users insert own playlists" on public.playlists;
create policy "users insert own playlists" on public.playlists
  for insert with check (auth.uid() = user_id);
drop policy if exists "users update own playlists" on public.playlists;
create policy "users update own playlists" on public.playlists
  for update using (auth.uid() = user_id);
drop policy if exists "users delete own playlists" on public.playlists;
create policy "users delete own playlists" on public.playlists
  for delete using (auth.uid() = user_id);

-- playlist_tracks: owner through their playlist.
drop policy if exists "owner read playlist_tracks" on public.playlist_tracks;
create policy "owner read playlist_tracks" on public.playlist_tracks
  for select using (exists (
    select 1 from public.playlists p where p.id = playlist_tracks.playlist_id and p.user_id = auth.uid()
  ));
drop policy if exists "owner insert playlist_tracks" on public.playlist_tracks;
create policy "owner insert playlist_tracks" on public.playlist_tracks
  for insert with check (exists (
    select 1 from public.playlists p where p.id = playlist_tracks.playlist_id and p.user_id = auth.uid()
  ));
drop policy if exists "owner delete playlist_tracks" on public.playlist_tracks;
create policy "owner delete playlist_tracks" on public.playlist_tracks
  for delete using (exists (
    select 1 from public.playlists p where p.id = playlist_tracks.playlist_id and p.user_id = auth.uid()
  ));

-- user_likes: owner-only.
drop policy if exists "owner read user_likes" on public.user_likes;
create policy "owner read user_likes" on public.user_likes
  for select using (auth.uid() = user_id);
drop policy if exists "owner insert user_likes" on public.user_likes;
create policy "owner insert user_likes" on public.user_likes
  for insert with check (auth.uid() = user_id);
drop policy if exists "owner delete user_likes" on public.user_likes;
create policy "owner delete user_likes" on public.user_likes
  for delete using (auth.uid() = user_id);

-- recently_played: owner-only.
drop policy if exists "owner read recently_played" on public.recently_played;
create policy "owner read recently_played" on public.recently_played
  for select using (auth.uid() = user_id);
drop policy if exists "owner insert recently_played" on public.recently_played;
create policy "owner insert recently_played" on public.recently_played
  for insert with check (auth.uid() = user_id);
drop policy if exists "owner upsert recently_played" on public.recently_played;
create policy "owner upsert recently_played" on public.recently_played
  for update using (auth.uid() = user_id);

-- user_taste_profile: owner-only.
drop policy if exists "owner read user_taste_profile" on public.user_taste_profile;
create policy "owner read user_taste_profile" on public.user_taste_profile
  for select using (auth.uid() = user_id);
drop policy if exists "owner upsert user_taste_profile" on public.user_taste_profile;
create policy "owner upsert user_taste_profile" on public.user_taste_profile
  for insert with check (auth.uid() = user_id);
drop policy if exists "owner update user_taste_profile" on public.user_taste_profile;
create policy "owner update user_taste_profile" on public.user_taste_profile
  for update using (auth.uid() = user_id);

-- recommendation_events: owner-only (insert by owner, read by owner only).
drop policy if exists "owner read recommendation_events" on public.recommendation_events;
create policy "owner read recommendation_events" on public.recommendation_events
  for select using (auth.uid() = user_id);
drop policy if exists "owner insert recommendation_events" on public.recommendation_events;
create policy "owner insert recommendation_events" on public.recommendation_events
  for insert with check (auth.uid() = user_id);

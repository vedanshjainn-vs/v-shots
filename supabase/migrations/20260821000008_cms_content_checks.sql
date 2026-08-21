-- V Shots — CMS content-safety CHECK constraints (PHASE 16 hardening)
-- ---------------------------------------------------------------------------
-- Public admin mode is on (see 20260821000007_public_admin_mode.sql), so
-- writes are additionally constrained AT THE DATABASE LEVEL:
--   • provider/enum columns may only hold the values the app understands
--   • numeric ranges enforced (max_items, refresh_minutes, sort_order)
-- These make destructive/invalid writes impossible regardless of client.
-- Idempotent. Does not touch data rows. No user/auth tables are affected.
-- ---------------------------------------------------------------------------

-- ── home_layout_config ──────────────────────────────────────────────────────
alter table public.home_layout_config
  drop constraint if exists home_layout_config_source_type_check;
alter table public.home_layout_config
  add constraint home_layout_config_source_type_check check (
    source_type in (
      'youtube_search', 'youtube_playlist', 'youtube_channel',
      'youtube_trending', 'youtube_manual', 'jiosaavn_manual',
      'manual', 'personalized'
    )
  );

alter table public.home_layout_config
  drop constraint if exists home_layout_config_provider_check;
alter table public.home_layout_config
  add constraint home_layout_config_provider_check check (
    provider is null or provider in ('auto', 'youtube', 'jiosaavn', 'youtube_web', 'jiosaavn_web')
  );

alter table public.home_layout_config
  drop constraint if exists home_layout_config_playback_check;
alter table public.home_layout_config
  add constraint home_layout_config_playback_check check (
    playback_provider is null or playback_provider in ('auto', 'youtube', 'jiosaavn', 'youtube_web', 'jiosaavn_web')
  );

alter table public.home_layout_config
  drop constraint if exists home_layout_config_fallback_check;
alter table public.home_layout_config
  add constraint home_layout_config_fallback_check check (
    fallback_provider is null or fallback_provider in ('none', 'youtube', 'jiosaavn', 'youtube_web', 'jiosaavn_web')
  );

alter table public.home_layout_config
  drop constraint if exists home_layout_config_max_items_check;
alter table public.home_layout_config
  add constraint home_layout_config_max_items_check check (
    max_items is null or (max_items between 1 and 100)
  );

alter table public.home_layout_config
  drop constraint if exists home_layout_config_refresh_check;
alter table public.home_layout_config
  add constraint home_layout_config_refresh_check check (
    refresh_minutes is null or (refresh_minutes between 5 and 1440)
  );

alter table public.home_layout_config
  drop constraint if exists home_layout_config_sort_check;
alter table public.home_layout_config
  add constraint home_layout_config_sort_check check (
    sort_order is null or sort_order >= 0
  );

-- ── home_section_items ──────────────────────────────────────────────────────
alter table public.home_section_items
  drop constraint if exists home_section_items_provider_check;
alter table public.home_section_items
  add constraint home_section_items_provider_check check (
    provider is null or provider in ('auto', 'youtube', 'jiosaavn', 'youtube_web', 'jiosaavn_web')
  );

alter table public.home_section_items
  drop constraint if exists home_section_items_playback_check;
alter table public.home_section_items
  add constraint home_section_items_playback_check check (
    playback_provider is null or playback_provider in ('auto', 'youtube', 'jiosaavn', 'youtube_web', 'jiosaavn_web')
  );

alter table public.home_section_items
  drop constraint if exists home_section_items_fallback_check;
alter table public.home_section_items
  add constraint home_section_items_fallback_check check (
    fallback_provider is null or fallback_provider in ('none', 'youtube', 'jiosaavn', 'youtube_web', 'jiosaavn_web')
  );

alter table public.home_section_items
  drop constraint if exists home_section_items_sort_check;
alter table public.home_section_items
  add constraint home_section_items_sort_check check (
    sort_order is null or sort_order >= 0
  );

-- ── discovery_categories ────────────────────────────────────────────────────
-- The live table drifted from the original migration: kind/token/
-- ranking_order/visible never existed there, yet the Admin panel writes them
-- (which made Discover saves fail with UndefinedColumn). Add them idempotently.
alter table public.discovery_categories
  add column if not exists kind text default 'source',
  add column if not exists token text,
  add column if not exists ranking_order text default 'relevance',
  add column if not exists visible boolean not null default true;

alter table public.discovery_categories
  drop constraint if exists discovery_categories_kind_check;
alter table public.discovery_categories
  add constraint discovery_categories_kind_check check (
    kind in ('source', 'mood', 'language', 'region')
  );

alter table public.discovery_categories
  drop constraint if exists discovery_categories_sort_check;
alter table public.discovery_categories
  add constraint discovery_categories_sort_check check (
    sort_order is null or sort_order >= 0
  );

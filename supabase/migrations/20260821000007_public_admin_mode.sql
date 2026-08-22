-- V Shots — PUBLIC ADMIN MODE (owner decision 2026-08-21)
-- ---------------------------------------------------------------------------
-- The Admin panel no longer requires Google login. For the unauthenticated
-- (anon) role to load AND publish Home content, write access to the
-- CONTENT-ONLY CMS tables below is opened up. These tables hold NO user
-- data (no profiles/auth rows) — only Home layout, section items, flags,
-- config version, and Discover categories.
--
-- REVERT TO LOGIN-ONLY WRITES (run this when re-enabling admin auth):
--   drop policy if exists "public write home_layout_config"  on public.home_layout_config;
--   drop policy if exists "public write home_section_items"   on public.home_section_items;
--   drop policy if exists "public write feature_flags"        on public.feature_flags;
--   drop policy if exists "public write home_config"          on public.home_config;
--   drop policy if exists "public write discovery_categories" on public.discovery_categories;
--   drop policy if exists "public read home_layout_config"    on public.home_layout_config;
--   create policy "admin write home_layout_config" on public.home_layout_config
--     for all to authenticated using (public.is_home_admin()) with check (public.is_home_admin());
--   create policy "home_layout_public_read" on public.home_layout_config
--     for select using (published = true);
--   -- (and repeat the admin-write policy for the other four tables)
--
-- Idempotent — safe to re-run. Does not touch any data rows.
-- ---------------------------------------------------------------------------

-- 1) home_layout_config: full visibility (incl. unpublished) + anon writes
drop policy if exists "admin write home_layout_config" on public.home_layout_config;
drop policy if exists "home_layout_admin_insert" on public.home_layout_config;
drop policy if exists "home_layout_admin_delete" on public.home_layout_config;
drop policy if exists "home_layout_admin_select" on public.home_layout_config;
drop policy if exists "home_layout_admin_update" on public.home_layout_config;
drop policy if exists "home_layout_public_read" on public.home_layout_config;
create policy "public read home_layout_config" on public.home_layout_config
  for select using (true);
create policy "public write home_layout_config" on public.home_layout_config
  for all to anon, authenticated using (true) with check (true);

-- 2) home_section_items
drop policy if exists "admin write home_section_items" on public.home_section_items;
drop policy if exists "public read home_section_items" on public.home_section_items;
create policy "public read home_section_items" on public.home_section_items
  for select using (true);
create policy "public write home_section_items" on public.home_section_items
  for all to anon, authenticated using (true) with check (true);

-- 3) feature_flags
drop policy if exists "admin write feature_flags" on public.feature_flags;
drop policy if exists "public read feature_flags" on public.feature_flags;
create policy "public read feature_flags" on public.feature_flags
  for select using (true);
create policy "public write feature_flags" on public.feature_flags
  for all to anon, authenticated using (true) with check (true);

-- 4) home_config (publish version tracker)
drop policy if exists "admin write home_config" on public.home_config;
drop policy if exists "public read home_config" on public.home_config;
create policy "public read home_config" on public.home_config
  for select using (true);
create policy "public write home_config" on public.home_config
  for all to anon, authenticated using (true) with check (true);

-- 5) discovery_categories
drop policy if exists "admin write discovery_categories" on public.discovery_categories;
drop policy if exists "public read discovery_categories" on public.discovery_categories;
create policy "public read discovery_categories" on public.discovery_categories
  for select using (true);
create policy "public write discovery_categories" on public.discovery_categories
  for all to anon, authenticated using (true) with check (true);

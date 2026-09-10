-- ═══════════════════════════════════════════════════════════════════
-- V SHOTS — P0 SECURITY: lock CMS/flag writes to home admins
-- Date: 2026-09-10 · Approved by owner: "fix all issues, no app changes"
--
-- Problem (live-verified 2026-09-10): 6 CMS tables + notification_history
-- had permissive write policies (to anon, authenticated using(true)) —
-- anyone with the anon key embedded in every APK could rewrite the Home
-- feed, kill ads app-wide, or poison notification history.
--
-- Fix: writes gated by is_home_admin() (existing SECURITY DEFINER fn:
-- home_admins table OR owner email allowlist — the same allowlist the
-- admin panel already uses). Reads stay public (app only reads these).
-- App behavior: UNCHANGED (app never writes these tables).
-- Admin panel behavior: UNCHANGED (login already required by its UI;
-- authorized Google accounts pass is_home_admin()).
-- ═══════════════════════════════════════════════════════════════════
begin;

-- ── 1) CMS + feature flags: admin-gated writes ─────────────────────
drop policy if exists "public write feature_flags" on public.feature_flags;
create policy "admin write feature_flags" on public.feature_flags
  for all to authenticated
  using (public.is_home_admin()) with check (public.is_home_admin());

drop policy if exists "public write home_layout_config" on public.home_layout_config;
create policy "admin write home_layout_config" on public.home_layout_config
  for all to authenticated
  using (public.is_home_admin()) with check (public.is_home_admin());

drop policy if exists "public write home_section_items" on public.home_section_items;
create policy "admin write home_section_items" on public.home_section_items
  for all to authenticated
  using (public.is_home_admin()) with check (public.is_home_admin());

drop policy if exists "public write home_config" on public.home_config;
create policy "admin write home_config" on public.home_config
  for all to authenticated
  using (public.is_home_admin()) with check (public.is_home_admin());

drop policy if exists "public write discovery_categories" on public.discovery_categories;
create policy "admin write discovery_categories" on public.discovery_categories
  for all to authenticated
  using (public.is_home_admin()) with check (public.is_home_admin());

drop policy if exists "public write discover_settings" on public.discover_settings;
create policy "admin write discover_settings" on public.discover_settings
  for all to authenticated
  using (public.is_home_admin()) with check (public.is_home_admin());

-- ── 2) notification_history: own-rows-only inserts ─────────────────
-- (was: "System can insert" to public with check(true) — open to the world.
--  The app inserts with user_id = signed-in user, so this preserves app flow.)
drop policy if exists "System can insert notification history" on public.notification_history;
create policy "Users can insert their own history" on public.notification_history
  for insert to authenticated
  with check (auth.uid() = user_id);

-- ── 3) home_admins: add missing email column so claim_home_admin() ──
--    (RPC inserts (user_id, email) but the column never existed → RPC
--     always errored; admin still worked via the email fallback check.)
alter table public.home_admins add column if not exists email text;

commit;

-- V Shots — Remote Home CMS complete contract
-- Safe to re-run. Does not store secrets.

create table if not exists public.home_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  created_at timestamptz not null default now()
);

alter table public.home_admins enable row level security;

create or replace function public.is_home_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() is not null
    and (
      exists (select 1 from public.home_admins a where a.user_id = auth.uid())
      or lower(coalesce(auth.email(), '')) in (
        'lovesongs1106@gmail.com',
        'vedanshjainn@gmail.com',
        'mrvedansh11@gmail.com'
      )
    );
$$;

create or replace function public.claim_home_admin()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return false;
  end if;

  if lower(coalesce(auth.email(), '')) not in (
    'lovesongs1106@gmail.com',
    'vedanshjainn@gmail.com',
    'mrvedansh11@gmail.com'
  ) then
    return false;
  end if;

  insert into public.home_admins(user_id, email)
  values (auth.uid(), auth.email())
  on conflict (user_id) do update set email = excluded.email;

  return true;
end;
$$;

grant execute on function public.is_home_admin() to anon, authenticated;
grant execute on function public.claim_home_admin() to authenticated;

alter table public.home_layout_config
  add column if not exists subtitle text,
  add column if not exists source_type text default 'youtube_search',
  add column if not exists source_value text,
  add column if not exists region_code text,
  add column if not exists category_id text,
  add column if not exists refresh_minutes integer default 60,
  add column if not exists published boolean not null default true;

update public.home_layout_config
set source_value = coalesce(nullif(source_value, ''), query)
where source_value is null or source_value = '';

update public.home_layout_config
set section_type = 'personalized',
    source_type = 'personalized'
where section_key in ('made_for_you', 'because_listened', 'continue_listening',
                      'trending_for_you', 'discover_something_new',
                      'artists_for_you', 'official_music')
   or id in ('made_for_you', 'because_listened', 'continue', 'mfy', 'byld');

drop policy if exists "public read home_admins" on public.home_admins;
create policy "public read home_admins" on public.home_admins
  for select using (public.is_home_admin());

drop policy if exists "admin write home_admins" on public.home_admins;
create policy "admin write home_admins" on public.home_admins
  for all using (public.is_home_admin()) with check (public.is_home_admin());

drop policy if exists "admin write home_layout_config" on public.home_layout_config;
create policy "admin write home_layout_config" on public.home_layout_config
  for all using (public.is_home_admin()) with check (public.is_home_admin());

drop policy if exists "admin write home_section_items" on public.home_section_items;
create policy "admin write home_section_items" on public.home_section_items
  for all using (public.is_home_admin()) with check (public.is_home_admin());

drop policy if exists "admin write home_config" on public.home_config;
create policy "admin write home_config" on public.home_config
  for all using (public.is_home_admin()) with check (public.is_home_admin());

drop policy if exists "admin write feature_flags" on public.feature_flags;
create policy "admin write feature_flags" on public.feature_flags
  for all using (public.is_home_admin()) with check (public.is_home_admin());

drop policy if exists "admin write discovery_categories" on public.discovery_categories;
create policy "admin write discovery_categories" on public.discovery_categories
  for all using (public.is_home_admin()) with check (public.is_home_admin());

insert into public.feature_flags (key, value, description) values
  ('enable_remote_home', true, 'Fetch Home config from Supabase'),
  ('enable_home_cms', true, 'Remote Home page CMS')
on conflict (key) do nothing;

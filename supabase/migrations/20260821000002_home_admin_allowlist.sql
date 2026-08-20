-- V Shots — Remote Home CMS admin allowlist
-- Keep the dashboard restricted to the two explicitly authorized Google accounts.
-- This mirrors the function deployed in Supabase so future migrations do not restore the old allowlist.

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
    'vedanshjainn@gmail.com'
  ) then
    return false;
  end if;

  insert into public.home_admins(user_id)
  values (auth.uid())
  on conflict (user_id) do nothing;

  return true;
end;
$$;

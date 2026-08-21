-- V Shots — authenticated user may delete their own Auth account + owned rows.
-- SECURITY DEFINER, restricted to auth.uid(). Never called with service_role
-- from the Flutter client.

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Best-effort cleanup of user-owned public rows. Missing tables must not
  -- abort Auth deletion.
  begin
    delete from public.profiles where id = uid;
  exception
    when undefined_table then null;
    when undefined_column then null;
  end;

  begin
    delete from public.liked_songs where user_id = uid;
  exception
    when undefined_table then null;
    when undefined_column then null;
  end;

  begin
    delete from public.play_history where user_id = uid;
  exception
    when undefined_table then null;
    when undefined_column then null;
  end;

  begin
    delete from public.playlists where user_id = uid;
  exception
    when undefined_table then null;
    when undefined_column then null;
  end;

  begin
    delete from public.notifications where recipient_id = uid;
  exception
    when undefined_table then null;
    when undefined_column then null;
  end;

  begin
    delete from public.user_settings where user_id = uid;
  exception
    when undefined_table then null;
    when undefined_column then null;
  end;

  begin
    delete from public.home_admins where user_id = uid;
  exception
    when undefined_table then null;
    when undefined_column then null;
  end;

  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;

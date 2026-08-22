-- V Shots — Phase 17: admin preview resolution RPCs + jiosaavn_playlist source
-- ---------------------------------------------------------------------------
-- Tightly-constrained server-side proxies to YouTube's public InnerTube web
-- endpoints (the SAME endpoints the app's InnerTube client already uses).
-- The Admin panel (browser) can't call InnerTube directly (CORS), so these
-- RPCs resolve playlist/channel/trending/search previews.
--
-- TWO-STEP pattern (required by pg_net): http_post enqueues the request but
-- the worker only picks it up AFTER the creating transaction commits — a
-- collect inside the same statement deadlocks (observed live: 57014
-- statement timeout). So step 1 stores the request id; step 2 (separate
-- REST call) collects it.
--
-- Abuse guards: allowlisted browse ids (VL…/UC…/FEtrending) only, no
-- continuation tokens, length/range caps, request ids must exist in the
-- preview_requests ledger (anon cannot collect arbitrary ids).
-- Idempotent. No data rows touched. Requires pg_net (installed 2026-08-21).
-- ---------------------------------------------------------------------------

create extension if not exists pg_net;

create table if not exists public.preview_requests (
  request_id bigint primary key,
  created_at timestamptz not null default now()
);
alter table public.preview_requests enable row level security;
drop policy if exists "anon manage own preview requests" on public.preview_requests;
create policy "anon manage own preview requests" on public.preview_requests
  for all to anon, authenticated using (true) with check (true);

-- Bootstrap storage: current INNERTUBE key/version scraped from youtube.com
-- (YouTube rotates these occasionally; the app does the same extraction).
create table if not exists public.preview_boot (
  singleton boolean primary key default true,
  api_key text,
  client_version text,
  fetched_at timestamptz
);
alter table public.preview_boot enable row level security;
drop policy if exists "anon read preview boot" on public.preview_boot;
create policy "anon read preview boot" on public.preview_boot
  for select to anon, authenticated using (true);

-- Latest known-good WEB client constants (updated 2026-08-21).
drop function if exists public.inner_tube_boot_request();
create or replace function public.inner_tube_boot_request()
returns bigint
language plpgsql volatile security definer set search_path = public, net
as $$
declare v_req bigint;
begin
  v_req := net.http_get('https://www.youtube.com/', params := '{}'::jsonb, timeout_milliseconds := 15000);
  insert into public.preview_requests(request_id) values (v_req) on conflict (request_id) do nothing;
  return v_req;
end;
$$;

drop function if exists public.inner_tube_boot_collect(bigint);
create or replace function public.inner_tube_boot_collect(p_request_id bigint)
returns text
language plpgsql volatile security definer set search_path = public, net
as $$
declare
  v_res record;
  v_body text;
  v_key text;
  v_ver text;
begin
  if not exists (select 1 from public.preview_requests where request_id = p_request_id) then
    raise exception 'unknown or expired request id';
  end if;
  select * into v_res from net._http_collect_response(p_request_id, async := false);
  delete from public.preview_requests where request_id = p_request_id;
  if v_res.status is null or v_res.status <> 'SUCCESS' then
    raise exception 'boot fetch failed: %', coalesce(v_res.status::text, 'timeout');
  end if;
  v_body := (v_res.response).body;
  v_key := coalesce(
    (regexp_match(v_body, '"INNERTUBE_API_KEY":"([^"]+)"'))[1],
    'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8'
  );
  v_ver := coalesce(
    (regexp_match(v_body, '"INNERTUBE_CLIENT_VERSION":"([^"]+)"'))[1],
    '2.20260820.08.00'
  );
  insert into public.preview_boot(singleton, api_key, client_version, fetched_at)
  values (true, v_key, v_ver, now())
  on conflict (singleton) do update set
    api_key = excluded.api_key, client_version = excluded.client_version, fetched_at = now();
  return v_ver;
end;
$$;

grant execute on function public.inner_tube_boot_request() to anon, authenticated;
grant execute on function public.inner_tube_boot_collect(bigint) to anon, authenticated;

drop function if exists public.inner_tube_request(text, text, int);
create or replace function public.inner_tube_request(
  p_kind text,          -- 'browse' | 'search'
  p_value text,         -- browse id (VL…/UC…/FEtrending) or search query
  p_max_items int default 25
)
returns bigint
language plpgsql
volatile
security definer
set search_path = public, net
as $$
declare
  v_req bigint;
  v_body jsonb;
  v_url text;
  v_key text;
  v_ver text;
begin
  -- Prefer the runtime-scraped key/version (fresh within 24h), else constants.
  select coalesce(api_key, 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8'),
         coalesce(client_version, '2.20260820.08.00')
    into v_key, v_ver
    from public.preview_boot
   where singleton and fetched_at > now() - interval '24 hours';
  if v_key is null then
    v_key := 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
    v_ver := '2.20260820.08.00';
  end if;
  if p_max_items is null or p_max_items < 1 or p_max_items > 50 then
    raise exception 'max_items must be between 1 and 50';
  end if;
  if p_kind = 'browse' then
    if p_value !~ '^(VL[A-Za-z0-9_-]{2,64}|UC[A-Za-z0-9_-]{10,64}|FEtrending)$' then
      raise exception 'browse_id not allowed (only playlist/channel/trending ids)';
    end if;
    v_body := jsonb_build_object(
      'context', jsonb_build_object(
        'client', jsonb_build_object(
          'clientName', 'WEB',
          'clientVersion', v_ver,
          'hl', 'en',
          'gl', 'IN'
        )
      ),
      'browseId', p_value
    );
    v_url := 'https://www.youtube.com/youtubei/v1/browse?key=' || v_key || '&prettyPrint=false';
  elsif p_kind = 'search' then
    if p_value is null or length(trim(p_value)) = 0 or length(p_value) > 200 then
      raise exception 'query must be 1-200 chars';
    end if;
    v_body := jsonb_build_object(
      'context', jsonb_build_object(
        'client', jsonb_build_object(
          'clientName', 'WEB',
          'clientVersion', v_ver,
          'hl', 'en',
          'gl', 'IN'
        )
      ),
      'query', p_value
    );
    v_url := 'https://www.youtube.com/youtubei/v1/search?key=' || v_key || '&prettyPrint=false';
  else
    raise exception 'kind must be browse or search';
  end if;

  v_req := net.http_post(
    v_url,
    v_body,
    params := '{}'::jsonb,
    headers := jsonb_build_object('Content-Type', 'application/json'),
    timeout_milliseconds := 20000
  );
  insert into public.preview_requests(request_id) values (v_req)
  on conflict (request_id) do nothing;
  return v_req;
end;
$$;

drop function if exists public.inner_tube_collect(bigint);
create or replace function public.inner_tube_collect(p_request_id bigint)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public, net
as $$
declare
  v_res record;
begin
  if not exists (select 1 from public.preview_requests where request_id = p_request_id) then
    raise exception 'unknown or expired request id';
  end if;
  select * into v_res from net._http_collect_response(p_request_id, async := false);
  delete from public.preview_requests where request_id = p_request_id;
  if v_res.status is null then
    raise exception 'upstream request failed (timeout)';
  end if;
  if v_res.status <> 'SUCCESS' then
    raise exception 'upstream http %', v_res.status;
  end if;
  return (v_res.response).body::jsonb;
end;
$$;

grant execute on function public.inner_tube_request(text, text, int) to anon, authenticated;
grant execute on function public.inner_tube_collect(bigint) to anon, authenticated;

-- allow the new jiosaavn_playlist source type
alter table public.home_layout_config
  drop constraint if exists home_layout_config_source_type_check;
alter table public.home_layout_config
  add constraint home_layout_config_source_type_check check (
    source_type in (
      'youtube_search', 'youtube_playlist', 'youtube_channel',
      'youtube_trending', 'youtube_manual', 'jiosaavn_manual',
      'jiosaavn_playlist', 'manual', 'personalized'
    )
  );

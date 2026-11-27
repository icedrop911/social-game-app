-- Good Company launch-readiness hardening.
-- Apply only after review on a non-production Supabase branch.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.write_rate_limits (
  bucket_key text primary key,
  window_started_at timestamptz not null,
  hit_count integer not null check (hit_count > 0)
);
revoke all on private.write_rate_limits from public, anon, authenticated;

create or replace function private.consume_write_rate(
  p_scope text, p_actor text, p_max_hits integer, p_window_seconds integer
) returns void
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
declare v_hits integer; v_key text; v_reset boolean;
begin
  if p_scope is null or p_actor is null or length(p_actor) = 0
     or p_max_hits < 1 or p_window_seconds < 1 then
    raise exception 'Invalid rate-limit parameters';
  end if;
  v_key := left(p_scope, 48) || ':' || left(p_actor, 160);
  insert into private.write_rate_limits(bucket_key, window_started_at, hit_count)
  values (v_key, clock_timestamp(), 1)
  on conflict (bucket_key) do update
    set hit_count = case
      when private.write_rate_limits.window_started_at <= clock_timestamp() - make_interval(secs => p_window_seconds) then 1
      else private.write_rate_limits.hit_count + 1
    end,
    window_started_at = case
      when private.write_rate_limits.window_started_at <= clock_timestamp() - make_interval(secs => p_window_seconds) then clock_timestamp()
      else private.write_rate_limits.window_started_at
    end
  returning hit_count into v_hits;
  if v_hits > p_max_hits then
    raise exception 'Too many requests. Please wait and try again.' using errcode = 'P0001';
  end if;
end;
$$;
revoke all on function private.consume_write_rate(text,text,integer,integer) from public, anon, authenticated;

create or replace function private.enforce_good_company_write_limits()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare v_actor text; v_scope text; v_max integer; v_window integer;
begin
  if tg_table_name = 'community_messages' then
    v_actor := new.sender_id::text; v_scope := 'community_message'; v_max := 20; v_window := 60;
  elsif tg_table_name = 'community_posts' then
    v_actor := new.author_id::text; v_scope := 'community_post'; v_max := 5; v_window := 3600;
  elsif tg_table_name = 'community_replies' then
    v_actor := new.author_id::text; v_scope := 'community_reply'; v_max := 20; v_window := 60;
  elsif tg_table_name = 'community_friend_requests' then
    v_actor := new.sender_id::text; v_scope := 'friend_request'; v_max := 12; v_window := 3600;
  elsif tg_table_name = 'community_reports' then
    v_actor := new.reporter_id::text; v_scope := 'community_report'; v_max := 5; v_window := 3600;
  elsif tg_table_name = 'rooms' then
    v_actor := new.host_client_id; v_scope := 'room_create'; v_max := 5; v_window := 3600;
  elsif tg_table_name = 'players' then
    v_actor := new.client_id; v_scope := 'room_join'; v_max := 15; v_window := 600;
  elsif tg_table_name = 'votes' then
    v_actor := new.client_id; v_scope := 'room_vote'; v_max := 12; v_window := 60;
  elsif tg_table_name = 'prompt_reports' then
    v_actor := new.reporter_client_id; v_scope := 'prompt_report'; v_max := 5; v_window := 3600;
  else
    raise exception 'Rate-limit trigger is not configured for this table';
  end if;
  perform private.consume_write_rate(v_scope, coalesce(v_actor, ''), v_max, v_window);
  return new;
end;
$$;
revoke all on function public.enforce_good_company_write_limits() from public, anon, authenticated;

drop trigger if exists gc_limit_community_messages on public.community_messages;
create trigger gc_limit_community_messages before insert on public.community_messages
for each row execute function public.enforce_good_company_write_limits();
drop trigger if exists gc_limit_community_posts on public.community_posts;
create trigger gc_limit_community_posts before insert on public.community_posts
for each row execute function public.enforce_good_company_write_limits();
drop trigger if exists gc_limit_community_replies on public.community_replies;
create trigger gc_limit_community_replies before insert on public.community_replies
for each row execute function public.enforce_good_company_write_limits();
drop trigger if exists gc_limit_friend_requests on public.community_friend_requests;
create trigger gc_limit_friend_requests before insert on public.community_friend_requests
for each row execute function public.enforce_good_company_write_limits();
drop trigger if exists gc_limit_community_reports on public.community_reports;
create trigger gc_limit_community_reports before insert on public.community_reports
for each row execute function public.enforce_good_company_write_limits();
drop trigger if exists gc_limit_room_create on public.rooms;
create trigger gc_limit_room_create before insert on public.rooms
for each row execute function public.enforce_good_company_write_limits();
drop trigger if exists gc_limit_room_join on public.players;
create trigger gc_limit_room_join before insert on public.players
for each row execute function public.enforce_good_company_write_limits();
drop trigger if exists gc_limit_room_vote on public.votes;
create trigger gc_limit_room_vote before insert or update on public.votes
for each row execute function public.enforce_good_company_write_limits();
drop trigger if exists gc_limit_prompt_report on public.prompt_reports;
create trigger gc_limit_prompt_report before insert on public.prompt_reports
for each row execute function public.enforce_good_company_write_limits();

-- Moderator authorization comes only from trusted app_metadata, never user-editable user_metadata.
alter table public.community_reports
  add column if not exists reviewed_by uuid references auth.users(id) on delete set null,
  add column if not exists reviewed_at timestamptz,
  add column if not exists resolution_note text;

create table if not exists public.community_moderation_events (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.community_reports(id) on delete cascade,
  moderator_id uuid references auth.users(id) on delete set null,
  old_status text not null,
  new_status text not null,
  resolution_note text,
  created_at timestamptz not null default now()
);
alter table public.community_moderation_events enable row level security;
revoke all on public.community_moderation_events from public, anon;
grant select on public.community_moderation_events to authenticated;
drop policy if exists "Moderators can view moderation events" on public.community_moderation_events;
create policy "Moderators can view moderation events" on public.community_moderation_events
for select to authenticated
using ((select auth.jwt()->'app_metadata'->>'role') in ('moderator','admin'));

drop policy if exists "Moderators can view all community reports" on public.community_reports;
create policy "Moderators can view all community reports" on public.community_reports
for select to authenticated
using ((select auth.jwt()->'app_metadata'->>'role') in ('moderator','admin'));
drop policy if exists "Moderators can review community reports" on public.community_reports;
create policy "Moderators can review community reports" on public.community_reports
for update to authenticated
using ((select auth.jwt()->'app_metadata'->>'role') in ('moderator','admin'))
with check (
  (select auth.jwt()->'app_metadata'->>'role') in ('moderator','admin')
  and status in ('open','reviewing','resolved','dismissed')
);

create or replace function private.audit_good_company_report_review()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if old.status is distinct from new.status
     or old.resolution_note is distinct from new.resolution_note then
    new.reviewed_by := auth.uid();
    new.reviewed_at := clock_timestamp();
    insert into public.community_moderation_events(report_id, moderator_id, old_status, new_status, resolution_note)
    values (new.id, auth.uid(), old.status, new.status, new.resolution_note);
  end if;
  return new;
end;
$$;
revoke all on function public.audit_good_company_report_review() from public, anon, authenticated;
drop trigger if exists gc_audit_report_review on public.community_reports;
create trigger gc_audit_report_review before update on public.community_reports
for each row execute function public.audit_good_company_report_review();

create index if not exists community_reports_status_created_idx
on public.community_reports(status, created_at desc);

-- This is an application-identity rate limit, not an IP/device proof.
-- Guest room IDs can be reset by a determined attacker. Put public guest RPCs
-- behind an edge/API gateway with IP + device risk controls before broad launch.

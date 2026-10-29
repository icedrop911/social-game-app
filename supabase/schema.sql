-- Good Company database starter. Apply in Supabase SQL Editor after reviewing.
create extension if not exists pgcrypto;
create table if not exists public.rooms (
 id uuid primary key default gen_random_uuid(),
 code text not null unique check (code ~ '^[A-Z0-9]{6}$'),
 host_client_id text not null,
 game_id text not null check (game_id in ('would','truth','likely','never','couples','family')),
 mode text not null check (mode in ('friends','couples','family')),
 status text not null default 'lobby' check (status in ('lobby','playing','ended')),
 prompt_index integer not null default 0,
 paused boolean not null default false,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.room_secrets(room_id uuid primary key references public.rooms(id) on delete cascade,host_token text not null);
create table if not exists public.players(
 id uuid primary key default gen_random_uuid(),room_id uuid not null references public.rooms(id) on delete cascade,
 client_id text not null,nickname text not null check(char_length(nickname) between 1 and 20),
 is_host boolean not null default false,is_ready boolean not null default false,score integer not null default 0,
 created_at timestamptz not null default now(),unique(room_id,client_id));
create table if not exists public.votes(
 id uuid primary key default gen_random_uuid(),room_id uuid not null references public.rooms(id) on delete cascade,
 round_index integer not null,client_id text not null,choice text not null,created_at timestamptz not null default now(),
 unique(room_id,round_index,client_id));
create table if not exists public.prompt_reports(
 id uuid primary key default gen_random_uuid(),room_id uuid references public.rooms(id) on delete set null,
 game_id text not null,prompt_text text not null,reason text not null,reporter_client_id text not null,created_at timestamptz not null default now());
create index if not exists players_room_id_idx on public.players(room_id);
create index if not exists votes_room_round_idx on public.votes(room_id,round_index);
alter table public.rooms enable row level security;
alter table public.players enable row level security;
alter table public.room_secrets enable row level security;
alter table public.votes enable row level security;
alter table public.prompt_reports enable row level security;
drop policy if exists "room state readable" on public.rooms;
drop policy if exists "player state readable" on public.players;
drop policy if exists "votes readable" on public.votes;
drop policy if exists "members can read room" on public.rooms;
drop policy if exists "members can read players" on public.players;
drop policy if exists "members can read votes" on public.votes;
revoke all on public.rooms from anon,authenticated;
revoke all on public.players from anon,authenticated;
revoke all on public.room_secrets from anon,authenticated;
revoke all on public.votes from anon,authenticated;
revoke all on public.prompt_reports from anon,authenticated;
create or replace function public.create_game_room(p_code text,p_nickname text,p_client_id text,p_host_token text,p_game_id text,p_mode text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.rooms;p public.players;
begin
 if p_code !~ '^[A-Z0-9]{6}$' then raise exception 'Invalid room code'; end if;
 if length(trim(p_nickname)) not between 1 and 20 then raise exception 'Nickname must be 1–20 characters'; end if;
 if length(trim(p_client_id)) not between 1 and 80 then raise exception 'Invalid player identity'; end if;
 if length(trim(p_host_token)) < 20 then raise exception 'Invalid host token'; end if;
 if p_game_id not in ('would','truth','likely','never','couples','family') then raise exception 'Invalid game'; end if;
 if p_mode not in ('friends','couples','family') then raise exception 'Invalid mode'; end if;
 insert into rooms(code,host_client_id,game_id,mode) values(upper(p_code),p_client_id,p_game_id,p_mode) returning * into r;
 insert into room_secrets(room_id,host_token) values(r.id,p_host_token);
 insert into players(room_id,client_id,nickname,is_host,is_ready) values(r.id,p_client_id,trim(p_nickname),true,true) returning * into p;
 return jsonb_build_object('room_id',r.id,'code',r.code,'player_id',p.id);
end $$;
create or replace function public.join_game_room(p_code text,p_nickname text,p_client_id text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.rooms;p public.players;
begin
 if length(trim(p_nickname)) not between 1 and 20 then raise exception 'Nickname must be 1–20 characters'; end if;
 if p_code !~ '^[A-Za-z0-9]{6}$' then raise exception 'Enter a valid six-character room code'; end if;
 if length(trim(p_client_id)) not between 1 and 80 then raise exception 'Invalid player identity'; end if;
 select * into r from rooms where code=upper(p_code) and status<>'ended';
 if not found then raise exception 'Room not found or has ended'; end if;
 if not exists(select 1 from players where room_id=r.id and client_id=p_client_id) and (select count(*) from players where room_id=r.id)>=20 then raise exception 'This room is full (20 players maximum)'; end if;
 insert into players(room_id,client_id,nickname,is_host,is_ready) values(r.id,p_client_id,trim(p_nickname),false,false)
 on conflict(room_id,client_id) do update set nickname=excluded.nickname returning * into p;
 return jsonb_build_object('room_id',r.id,'code',r.code,'player_id',p.id);
end $$;
create or replace function public.game_room_action(p_code text,p_client_id text,p_host_token text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.rooms;p public.players;choice text;saved_host_token text;
begin
 select * into r from rooms where code=upper(p_code) for update;
 if not found then raise exception 'Room not found'; end if;
 if length(trim(p_client_id)) not between 1 and 80 then raise exception 'Invalid player identity'; end if;
 select * into p from players where room_id=r.id and client_id=p_client_id;
 if not found then raise exception 'Join this room first'; end if;
 if p_action in ('start','pause','skip','end') then
  select host_token into saved_host_token from room_secrets where room_id=r.id;
  if r.host_client_id<>p_client_id or saved_host_token is distinct from p_host_token then raise exception 'Only the host can do that'; end if;
 end if;
 case p_action
 when 'ready' then update players set is_ready=not is_ready where id=p.id;
 when 'start' then if r.status='ended' then raise exception 'This room has ended'; end if; update rooms set status='playing',paused=false,prompt_index=0,updated_at=now() where id=r.id;
 when 'pause' then if r.status<>'playing' then raise exception 'Game is not running'; end if; update rooms set paused=not paused,updated_at=now() where id=r.id;
 when 'skip' then if r.status<>'playing' then raise exception 'Game is not running'; end if; update rooms set prompt_index=prompt_index+1,updated_at=now() where id=r.id;
 when 'end' then update rooms set status='ended',paused=false,updated_at=now() where id=r.id;
 when 'vote' then if r.status<>'playing' or r.paused then raise exception 'Voting is not open'; end if;
  choice:=coalesce(p_payload->>'vote',''); if length(choice)=0 or length(choice)>80 then raise exception 'Choose a valid answer'; end if;
  insert into votes(room_id,round_index,client_id,choice) values(r.id,r.prompt_index,p_client_id,choice)
  on conflict(room_id,round_index,client_id) do update set choice=excluded.choice;
 when 'report' then insert into prompt_reports(room_id,game_id,prompt_text,reason,reporter_client_id)
  values(r.id,coalesce(p_payload->>'game_id',r.game_id),left(coalesce(p_payload->>'prompt_text',''),500),left(coalesce(p_payload->>'report_reason','Other concern'),100),p_client_id);
 else raise exception 'Unknown action';
 end case;
 return jsonb_build_object('ok',true);
end $$;
create or replace function public.get_room_snapshot(p_code text,p_client_id text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.rooms;
begin
 select * into r from public.rooms where code=upper(trim(p_code)) and status<>'ended';
 if not found then
   select * into r from public.rooms where code=upper(trim(p_code));
   if not found then raise exception 'Room not found'; end if;
 end if;
 if length(trim(coalesce(p_client_id,''))) not between 1 and 80 then raise exception 'Invalid player identity'; end if;
 if not exists(select 1 from public.players where room_id=r.id and client_id=p_client_id) then
   raise exception 'Join this room first';
 end if;
 return jsonb_build_object(
  'room',jsonb_build_object('id',r.id,'code',r.code,'game_id',r.game_id,'mode',r.mode,'status',r.status,'prompt_index',r.prompt_index,'paused',r.paused),
  'players',(select coalesce(jsonb_agg(jsonb_build_object('nickname',p.nickname,'client_id',p.client_id,'is_host',p.is_host,'is_ready',p.is_ready,'score',p.score) order by p.created_at),'[]'::jsonb) from public.players p where p.room_id=r.id),
  'votes',(select coalesce(jsonb_agg(jsonb_build_object('round_index',v.round_index,'client_id',v.client_id,'choice',v.choice)),'[]'::jsonb) from public.votes v where v.room_id=r.id and v.round_index=r.prompt_index)
 );
end $$;
revoke all on function public.create_game_room(text,text,text,text,text,text) from public;
revoke all on function public.join_game_room(text,text,text) from public;
revoke all on function public.game_room_action(text,text,text,text,jsonb) from public;
grant execute on function public.create_game_room(text,text,text,text,text,text) to anon,authenticated;
grant execute on function public.join_game_room(text,text,text) to anon,authenticated;
grant execute on function public.game_room_action(text,text,text,text,jsonb) to anon,authenticated;
revoke all on function public.get_room_snapshot(text,text) from public;
grant execute on function public.get_room_snapshot(text,text) to anon,authenticated;
do $$ begin alter publication supabase_realtime add table public.rooms; exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.players; exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.votes; exception when duplicate_object then null; when undefined_object then null; end $$;

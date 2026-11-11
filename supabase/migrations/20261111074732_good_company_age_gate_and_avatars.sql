-- Applied to the Good Company Supabase project as migration 20261111074732.
-- Stores only an adult-eligibility marker, never the submitted date of birth.
create table if not exists public.game_age_verifications (
  client_id text primary key check (char_length(client_id) between 1 and 80),
  verified_at timestamptz not null default now()
);
alter table public.game_age_verifications enable row level security;
revoke all on public.game_age_verifications from public, anon, authenticated;

create or replace function public.verify_game_age(p_client_id text, p_date_of_birth date)
returns boolean language plpgsql security definer set search_path=public as $$
begin
  if p_client_id is null or length(trim(p_client_id)) not between 1 and 80 then raise exception 'Invalid player identity'; end if;
  if p_date_of_birth is null or p_date_of_birth > (current_date - interval '18 years')::date then
    delete from public.game_age_verifications where client_id=p_client_id;
    return false;
  end if;
  insert into public.game_age_verifications(client_id,verified_at) values(p_client_id,now())
  on conflict(client_id) do update set verified_at=excluded.verified_at;
  return true;
end;
$$;
revoke all on function public.verify_game_age(text,date) from public;
grant execute on function public.verify_game_age(text,date) to anon, authenticated;

create or replace function public.create_game_room(p_code text,p_nickname text,p_client_id text,p_player_token text,p_host_token text,p_game_id text,p_mode text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.rooms; p public.players;
begin
 if not exists(select 1 from public.game_age_verifications where client_id=p_client_id) then raise exception 'Age verification required. You must be 18 or older to play.'; end if;
 if p_code !~ '^[A-Z0-9]{6}$' then raise exception 'Invalid room code'; end if;
 if length(trim(p_nickname)) not between 1 and 20 then raise exception 'Nickname must be 1–20 characters'; end if;
 if length(trim(p_client_id)) not between 1 and 80 then raise exception 'Invalid player identity'; end if;
 if length(trim(p_player_token)) < 20 then raise exception 'Invalid player token'; end if;
 if length(trim(p_host_token)) < 20 then raise exception 'Invalid host token'; end if;
 if p_game_id not in ('would','truth','likely','never','couples','family') then raise exception 'Invalid game'; end if;
 if p_mode not in ('friends','couples','family') then raise exception 'Invalid mode'; end if;
 insert into public.rooms(code,host_client_id,game_id,mode) values(upper(p_code),p_client_id,p_game_id,p_mode) returning * into r;
 insert into public.room_secrets(room_id,host_token) values(r.id,p_host_token);
 insert into public.players(room_id,client_id,nickname,is_host,is_ready) values(r.id,p_client_id,trim(p_nickname),true,true) returning * into p;
 insert into public.room_player_secrets(room_id,client_id,player_token) values(r.id,p_client_id,p_player_token);
 return jsonb_build_object('room_id',r.id,'code',r.code,'player_id',p.id);
end;
$$;

create or replace function public.join_game_room(p_code text,p_nickname text,p_client_id text,p_player_token text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.rooms; p public.players;
begin
 if not exists(select 1 from public.game_age_verifications where client_id=p_client_id) then raise exception 'Age verification required. You must be 18 or older to play.'; end if;
 if length(trim(p_nickname)) not between 1 and 20 then raise exception 'Nickname must be 1–20 characters'; end if;
 if p_code !~ '^[A-Za-z0-9]{6}$' then raise exception 'Enter a valid six-character room code'; end if;
 if length(trim(p_client_id)) not between 1 and 80 then raise exception 'Invalid player identity'; end if;
 if length(trim(p_player_token)) < 20 then raise exception 'Invalid player token'; end if;
 select * into r from public.rooms where code=upper(p_code) and status<>'ended' for update;
 if not found then raise exception 'Room not found or has ended'; end if;
 if not exists(select 1 from public.players where room_id=r.id and client_id=p_client_id) and (select count(*) from public.players where room_id=r.id)>=20 then raise exception 'This room is full (20 players maximum)'; end if;
 if exists(select 1 from public.room_player_secrets where room_id=r.id and client_id=p_client_id) then
  if not exists(select 1 from public.room_player_secrets where room_id=r.id and client_id=p_client_id and player_token=p_player_token) then
   raise exception 'This player session is already registered on another browser. Rejoin from the original browser or use a new player identity.';
  end if;
 else
  insert into public.room_player_secrets(room_id,client_id,player_token) values(r.id,p_client_id,p_player_token);
 end if;
 insert into public.players(room_id,client_id,nickname,is_host,is_ready) values(r.id,p_client_id,trim(p_nickname),false,false)
 on conflict(room_id,client_id) do update set nickname=excluded.nickname returning * into p;
 return jsonb_build_object('room_id',r.id,'code',r.code,'player_id',p.id);
end;
$$;

create or replace function public.game_room_action(p_code text,p_client_id text,p_player_token text,p_host_token text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.rooms; p public.players; choice text; saved_host_token text;
begin
 if not exists(select 1 from public.game_age_verifications where client_id=p_client_id) then raise exception 'Age verification required. You must be 18 or older to play.'; end if;
 select * into r from public.rooms where code=upper(p_code) for update;
 if not found then raise exception 'Room not found'; end if;
 if length(trim(p_client_id)) not between 1 and 80 then raise exception 'Invalid player identity'; end if;
 if length(trim(p_player_token)) < 20 then raise exception 'Invalid player token'; end if;
 select * into p from public.players where room_id=r.id and client_id=p_client_id;
 if not found then raise exception 'Join this room first'; end if;
 if not exists(select 1 from public.room_player_secrets where room_id=r.id and client_id=p_client_id and player_token=p_player_token) then raise exception 'Player session is not valid. Rejoin the room.'; end if;
 if p_action in ('start','pause','skip','end','set_adult_prompts') then
  select host_token into saved_host_token from public.room_secrets where room_id=r.id;
  if r.host_client_id<>p_client_id or saved_host_token is distinct from p_host_token then raise exception 'Only the host can do that'; end if;
 end if;
 case p_action
 when 'ready' then update public.players set is_ready=not is_ready where id=p.id;
 when 'start' then if r.status='ended' then raise exception 'This room has ended'; end if; update public.rooms set status='playing',paused=false,prompt_index=0,updated_at=now() where id=r.id;
 when 'pause' then if r.status<>'playing' then raise exception 'Game is not running'; end if; update public.rooms set paused=not paused,updated_at=now() where id=r.id;
 when 'set_adult_prompts' then update public.rooms set adult_prompts=coalesce((p_payload->>'enabled')::boolean,false),updated_at=now() where id=r.id;
 when 'skip' then if r.status<>'playing' then raise exception 'Game is not running'; end if; update public.rooms set prompt_index=prompt_index+1,updated_at=now() where id=r.id;
 when 'end' then update public.rooms set status='ended',paused=false,updated_at=now() where id=r.id;
 when 'vote' then
  if r.status<>'playing' then raise exception 'The game has not started or has already ended'; end if;
  if r.paused then raise exception 'The game is paused. The host must resume it before voting'; end if;
  choice:=coalesce(p_payload->>'vote',''); if length(choice)=0 or length(choice)>80 then raise exception 'Choose a valid answer'; end if;
  if r.game_id='truth' then
   select host_token into saved_host_token from public.room_secrets where room_id=r.id;
   if r.host_client_id<>p_client_id or saved_host_token is distinct from p_host_token then raise exception 'Only the host can choose Truth or Dare'; end if;
  end if;
  if r.game_id='likely' then
   if not exists(select 1 from public.players where room_id=r.id and client_id=choice) then raise exception 'Choose a player in this room'; end if;
  elsif choice not in ('a','b') then raise exception 'Choose a valid answer'; end if;
  insert into public.votes(room_id,round_index,client_id,choice) values(r.id,r.prompt_index,p_client_id,choice)
  on conflict(room_id,round_index,client_id) do update set choice=excluded.choice;
 when 'report' then insert into public.prompt_reports(room_id,game_id,prompt_text,reason,reporter_client_id)
  values(r.id,coalesce(p_payload->>'game_id',r.game_id),left(coalesce(p_payload->>'prompt_text',''),500),left(coalesce(p_payload->>'report_reason','Other concern'),100),p_client_id);
 else raise exception 'Unknown action';
 end case;
 return jsonb_build_object('ok',true);
end;
$$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('avatars','avatars',true,3145728,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=3145728,allowed_mime_types=array['image/jpeg','image/png','image/webp'];

drop policy if exists "Good Company avatar uploads" on storage.objects;
create policy "Good Company avatar uploads" on storage.objects for insert to authenticated
with check(bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "Good Company avatar updates" on storage.objects;
create policy "Good Company avatar updates" on storage.objects for update to authenticated
using(bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check(bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "Good Company avatar deletes" on storage.objects;
create policy "Good Company avatar deletes" on storage.objects for delete to authenticated
using(bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);

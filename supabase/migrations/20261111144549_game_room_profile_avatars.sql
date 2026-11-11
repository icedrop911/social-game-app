alter table public.players
  add column if not exists user_id uuid references auth.users(id) on delete set null;

create index if not exists players_user_id_idx on public.players(user_id);

create or replace function public.create_game_room(
  p_code text, p_nickname text, p_client_id text, p_player_token text,
  p_host_token text, p_game_id text, p_mode text
) returns jsonb
language plpgsql security definer set search_path to 'public'
as $function$
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
 insert into public.players(room_id,client_id,nickname,is_host,is_ready,user_id)
 values(r.id,p_client_id,trim(p_nickname),true,true,auth.uid()) returning * into p;
 insert into public.room_player_secrets(room_id,client_id,player_token) values(r.id,p_client_id,p_player_token);
 return jsonb_build_object('room_id',r.id,'code',r.code,'player_id',p.id);
end;
$function$;

create or replace function public.join_game_room(
  p_code text, p_nickname text, p_client_id text, p_player_token text
) returns jsonb
language plpgsql security definer set search_path to 'public'
as $function$
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
 if auth.uid() is not null and exists(
   select 1 from public.players where room_id=r.id and client_id=p_client_id
   and user_id is not null and user_id<>auth.uid()
 ) then raise exception 'This player session is linked to another member account. Use your own browser session.'; end if;
 if exists(select 1 from public.room_player_secrets where room_id=r.id and client_id=p_client_id) then
  if not exists(select 1 from public.room_player_secrets where room_id=r.id and client_id=p_client_id and player_token=p_player_token) then
   raise exception 'This player session is already registered on another browser. Rejoin from the original browser or use a new player identity.';
  end if;
 else
  insert into public.room_player_secrets(room_id,client_id,player_token) values(r.id,p_client_id,p_player_token);
 end if;
 insert into public.players(room_id,client_id,nickname,is_host,is_ready,user_id)
 values(r.id,p_client_id,trim(p_nickname),false,false,auth.uid())
 on conflict(room_id,client_id) do update
 set nickname=excluded.nickname,user_id=coalesce(public.players.user_id,excluded.user_id)
 returning * into p;
 return jsonb_build_object('room_id',r.id,'code',r.code,'player_id',p.id);
end;
$function$;

create or replace function public.get_room_snapshot(
  p_code text, p_client_id text, p_player_token text
) returns jsonb
language plpgsql security definer set search_path to 'public'
as $function$
declare r public.rooms;
begin
 select * into r from public.rooms where code=upper(trim(p_code)) and status<>'ended';
 if not found then
   select * into r from public.rooms where code=upper(trim(p_code));
   if not found then raise exception 'Room not found'; end if;
 end if;
 if length(trim(coalesce(p_client_id,''))) not between 1 and 80 then raise exception 'Invalid player identity'; end if;
 if length(trim(coalesce(p_player_token,''))) < 20 then raise exception 'Invalid player token'; end if;
 if not exists(select 1 from public.players where room_id=r.id and client_id=p_client_id) then raise exception 'Join this room first'; end if;
 if not exists(select 1 from public.room_player_secrets where room_id=r.id and client_id=p_client_id and player_token=p_player_token) then raise exception 'Player session is not valid. Rejoin the room.'; end if;
 return jsonb_build_object(
  'room',jsonb_build_object('id',r.id,'code',r.code,'game_id',r.game_id,'mode',r.mode,'status',r.status,'prompt_index',r.prompt_index,'paused',r.paused,'adult_prompts',r.adult_prompts),
  'players',(select coalesce(jsonb_agg(jsonb_build_object('nickname',p.nickname,'client_id',p.client_id,'is_host',p.is_host,'is_ready',p.is_ready,'score',p.score,'avatar_url',cp.avatar_url) order by p.created_at),'[]'::jsonb)
    from public.players p left join public.community_profiles cp on cp.id=p.user_id where p.room_id=r.id),
  'votes',(select coalesce(jsonb_agg(jsonb_build_object('round_index',v.round_index,'client_id',v.client_id,'choice',v.choice)),'[]'::jsonb) from public.votes v where v.room_id=r.id)
 );
end;
$function$;

alter publication supabase_realtime add table public.community_profiles;

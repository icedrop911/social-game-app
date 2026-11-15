-- Keep room activity timestamps accurate and close abandoned rooms without deleting history.
create or replace function public.touch_game_room_activity()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  update public.rooms
     set updated_at = now()
   where id = new.room_id;
  return new;
end;
$function$;

revoke all on function public.touch_game_room_activity() from public;

drop trigger if exists votes_touch_game_room_activity on public.votes;
create trigger votes_touch_game_room_activity
after insert or update on public.votes
for each row execute function public.touch_game_room_activity();

drop trigger if exists players_touch_game_room_activity on public.players;
create trigger players_touch_game_room_activity
after update on public.players
for each row execute function public.touch_game_room_activity();

create or replace function public.expire_stale_game_rooms()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  expired_count integer;
begin
  update public.rooms
     set status = 'ended',
         paused = false,
         updated_at = now()
   where status <> 'ended'
     and updated_at < now() - interval '24 hours';

  get diagnostics expired_count = row_count;
  return expired_count;
end;
$function$;

revoke all on function public.expire_stale_game_rooms() from public;
grant execute on function public.expire_stale_game_rooms() to anon, authenticated;

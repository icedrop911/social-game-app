-- Keep the stale-room sweep efficient as room history grows.
create index if not exists rooms_active_updated_at_idx
  on public.rooms (updated_at)
  where status <> 'ended';

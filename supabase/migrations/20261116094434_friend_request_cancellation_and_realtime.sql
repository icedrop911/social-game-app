-- Allow recipients to accept/decline requests and senders to cancel their own pending requests.
drop policy if exists "Recipients can respond to friend requests" on public.community_friend_requests;
create policy "Recipients can respond to friend requests" on public.community_friend_requests
for update to authenticated
using (
  recipient_id = auth.uid()
  or (sender_id = auth.uid() and status = 'pending')
)
with check (
  (recipient_id = auth.uid() and status in ('pending','accepted','declined'))
  or (sender_id = auth.uid() and status = 'cancelled')
);

-- Publish friend-request state changes so both members receive live updates.
do $$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime')
     and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='community_friend_requests') then
    alter publication supabase_realtime add table public.community_friend_requests;
  end if;
end $$;

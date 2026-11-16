-- Keep friend-request response permissions efficient by evaluating auth.uid once per query.
drop policy if exists "Recipients can respond to friend requests" on public.community_friend_requests;
create policy "Recipients can respond to friend requests" on public.community_friend_requests
for update to authenticated
using (
  recipient_id = (select auth.uid())
  or (sender_id = (select auth.uid()) and status in ('pending','cancelled'))
)
with check (
  (recipient_id = (select auth.uid()) and status in ('pending','accepted','declined'))
  or (sender_id = (select auth.uid()) and status in ('pending','cancelled'))
);

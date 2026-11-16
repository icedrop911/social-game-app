-- Allow a sender to restore a request they previously cancelled, without granting
-- senders permission to accept or decline requests on behalf of recipients.
drop policy if exists "Recipients can respond to friend requests" on public.community_friend_requests;
create policy "Recipients can respond to friend requests" on public.community_friend_requests
for update to authenticated
using (
  recipient_id = auth.uid()
  or (sender_id = auth.uid() and status in ('pending','cancelled'))
)
with check (
  (recipient_id = auth.uid() and status in ('pending','accepted','declined'))
  or (sender_id = auth.uid() and status in ('pending','cancelled'))
);

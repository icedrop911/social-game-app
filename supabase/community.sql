-- Good Company Community foundation
-- Apply this migration in the Supabase SQL Editor after backing up the project.
-- Uses Supabase Auth identities. Never expose service-role credentials in the browser.

create extension if not exists pgcrypto;

create table if not exists public.community_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[A-Za-z0-9_]{3,24}$'),
  display_name text not null default '' check (char_length(display_name) <= 50),
  bio text not null default '' check (char_length(bio) <= 240),
  avatar_url text,
  location_label text not null default '' check (char_length(location_label) <= 80),
  allow_messages text not null default 'everyone' check (allow_messages in ('everyone','friends_only','nobody')),
  show_online boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.community_contacts (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  phone text,
  whatsapp text,
  email text,
  instagram text,
  other_contact text,
  updated_at timestamptz not null default now()
);

create table if not exists public.community_contact_shares (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  contact_type text not null check (contact_type in ('phone','whatsapp','email','instagram','other')),
  contact_value text not null check (char_length(contact_value) between 1 and 200),
  created_at timestamptz not null default now(),
  unique(owner_id, recipient_id, contact_type),
  check(owner_id <> recipient_id)
);

create table if not exists public.community_friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(sender_id, recipient_id),
  check(sender_id <> recipient_id)
);

create table if not exists public.community_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id, blocked_id),
  check(blocker_id <> blocked_id)
);

create table if not exists public.community_conversations (
  id uuid primary key default gen_random_uuid(),
  is_group boolean not null default false,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.community_conversation_members (
  conversation_id uuid not null references public.community_conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(conversation_id,user_id)
);

create table if not exists public.community_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.community_conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);

create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 140),
  body text not null check (char_length(body) between 1 and 8000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.community_replies (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

create table if not exists public.community_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_user_id uuid references auth.users(id) on delete set null,
  post_id uuid references public.community_posts(id) on delete cascade,
  message_id uuid references public.community_messages(id) on delete cascade,
  reason text not null check (char_length(reason) between 3 and 500),
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now(),
  check(num_nonnulls(reported_user_id,post_id,message_id) = 1)
);

create index if not exists community_posts_created_idx on public.community_posts(created_at desc);
create index if not exists community_replies_post_idx on public.community_replies(post_id,created_at);
create index if not exists community_messages_conversation_idx on public.community_messages(conversation_id,created_at);
create index if not exists community_friend_recipient_idx on public.community_friend_requests(recipient_id,status);
create index if not exists community_contact_shares_recipient_idx on public.community_contact_shares(recipient_id);

-- Create a non-sensitive public profile when an Auth account is registered.
create or replace function public.community_create_profile()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare candidate text;
begin
  candidate := coalesce(nullif(regexp_replace(coalesce(new.raw_user_meta_data->>'username',''), '[^A-Za-z0-9_]', '', 'g'), ''), 'member_' || left(new.id::text,8));
  if exists(select 1 from public.community_profiles p where lower(p.username)=lower(candidate)) then
    candidate := left(candidate,15) || '_' || left(new.id::text,8);
  end if;
  insert into public.community_profiles(id,username,display_name)
  values(new.id,candidate,coalesce(left(new.raw_user_meta_data->>'display_name',50),''))
  on conflict(id) do nothing;
  return new;
end $$;

revoke all on function public.community_create_profile() from public, anon, authenticated;

drop trigger if exists community_auth_user_created on auth.users;
create trigger community_auth_user_created after insert on auth.users
for each row execute function public.community_create_profile();

alter table public.community_profiles enable row level security;
alter table public.community_contacts enable row level security;
alter table public.community_contact_shares enable row level security;
alter table public.community_friend_requests enable row level security;
alter table public.community_blocks enable row level security;
alter table public.community_conversations enable row level security;
alter table public.community_conversation_members enable row level security;
alter table public.community_messages enable row level security;
alter table public.community_posts enable row level security;
alter table public.community_replies enable row level security;
alter table public.community_reports enable row level security;

-- Public profile fields only. Private contact details are stored separately.
drop policy if exists "Authenticated users can view community profiles" on public.community_profiles;
create policy "Authenticated users can view community profiles" on public.community_profiles
for select to authenticated using (true);
drop policy if exists "Users can create their own profile" on public.community_profiles;
create policy "Users can create their own profile" on public.community_profiles
for insert to authenticated with check (id = auth.uid());
drop policy if exists "Users can update their own profile" on public.community_profiles;
create policy "Users can update their own profile" on public.community_profiles
for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "Owners manage private contacts" on public.community_contacts;
create policy "Owners manage private contacts" on public.community_contacts
for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "Owners can share contact details" on public.community_contact_shares;
create policy "Owners can share contact details" on public.community_contact_shares
for insert to authenticated with check (owner_id = auth.uid());
drop policy if exists "Owners and recipients can view shared contacts" on public.community_contact_shares;
create policy "Owners and recipients can view shared contacts" on public.community_contact_shares
for select to authenticated using (owner_id = auth.uid() or recipient_id = auth.uid());
drop policy if exists "Owners can revoke contact shares" on public.community_contact_shares;
create policy "Owners can revoke contact shares" on public.community_contact_shares
for delete to authenticated using (owner_id = auth.uid());
drop policy if exists "Owners can update shared contact values" on public.community_contact_shares;
create policy "Owners can update shared contact values" on public.community_contact_shares
for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "Users can view their friend requests" on public.community_friend_requests;
create policy "Users can view their friend requests" on public.community_friend_requests
for select to authenticated using (sender_id = auth.uid() or recipient_id = auth.uid());
drop policy if exists "Users can send friend requests" on public.community_friend_requests;
create policy "Users can send friend requests" on public.community_friend_requests
for insert to authenticated with check (
  sender_id = auth.uid()
  and not exists(select 1 from public.community_blocks b where
    (b.blocker_id=sender_id and b.blocked_id=recipient_id) or
    (b.blocker_id=recipient_id and b.blocked_id=sender_id))
);
drop policy if exists "Recipients can respond to friend requests" on public.community_friend_requests;
create policy "Recipients can respond to friend requests" on public.community_friend_requests
for update to authenticated using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());

drop policy if exists "Users manage their own blocks" on public.community_blocks;
create policy "Users manage their own blocks" on public.community_blocks
for all to authenticated using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

create or replace function public.community_is_conversation_member(target_conversation uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(select 1 from public.community_conversation_members m
    where m.conversation_id=target_conversation and m.user_id=auth.uid());
$$;
revoke all on function public.community_is_conversation_member(uuid) from public;
grant execute on function public.community_is_conversation_member(uuid) to authenticated;

drop policy if exists "Conversation members can view conversations" on public.community_conversations;
create policy "Conversation members can view conversations" on public.community_conversations
for select to authenticated using (
  public.community_is_conversation_member(id)
);
drop policy if exists "Members can view conversation membership" on public.community_conversation_members;
create policy "Members can view conversation membership" on public.community_conversation_members
for select to authenticated using (
  public.community_is_conversation_member(conversation_id)
);
drop policy if exists "Conversation members can read messages" on public.community_messages;
create policy "Conversation members can read messages" on public.community_messages
for select to authenticated using (
  exists(select 1 from public.community_conversation_members m where m.conversation_id=community_messages.conversation_id and m.user_id=auth.uid())
);
drop policy if exists "Conversation members can send messages" on public.community_messages;
create policy "Conversation members can send messages" on public.community_messages
for insert to authenticated with check (
  sender_id=auth.uid()
  and exists(select 1 from public.community_conversation_members m where m.conversation_id=community_messages.conversation_id and m.user_id=auth.uid())
  and not exists(
    select 1 from public.community_conversation_members other
    join public.community_blocks b on
      ((b.blocker_id=other.user_id and b.blocked_id=auth.uid()) or (b.blocker_id=auth.uid() and b.blocked_id=other.user_id))
    where other.conversation_id=community_messages.conversation_id and other.user_id<>auth.uid()
  )
);
drop policy if exists "Authors can edit their own messages" on public.community_messages;
create policy "Authors can edit their own messages" on public.community_messages
for update to authenticated using (sender_id=auth.uid() and public.community_is_conversation_member(conversation_id))
with check (sender_id=auth.uid() and public.community_is_conversation_member(conversation_id));

drop policy if exists "Authenticated users can read forum posts" on public.community_posts;
create policy "Authenticated users can read forum posts" on public.community_posts
for select to authenticated using (true);
drop policy if exists "Users can publish forum posts" on public.community_posts;
create policy "Users can publish forum posts" on public.community_posts
for insert to authenticated with check (author_id=auth.uid());
drop policy if exists "Authors can edit their forum posts" on public.community_posts;
create policy "Authors can edit their forum posts" on public.community_posts
for update to authenticated using (author_id=auth.uid()) with check (author_id=auth.uid());
drop policy if exists "Authors can delete their forum posts" on public.community_posts;
create policy "Authors can delete their forum posts" on public.community_posts
for delete to authenticated using (author_id=auth.uid());

drop policy if exists "Authenticated users can read forum replies" on public.community_replies;
create policy "Authenticated users can read forum replies" on public.community_replies
for select to authenticated using (true);
drop policy if exists "Users can publish forum replies" on public.community_replies;
create policy "Users can publish forum replies" on public.community_replies
for insert to authenticated with check (author_id=auth.uid());
drop policy if exists "Authors can edit their forum replies" on public.community_replies;
create policy "Authors can edit their forum replies" on public.community_replies
for update to authenticated using (author_id=auth.uid()) with check (author_id=auth.uid());
drop policy if exists "Authors can delete their forum replies" on public.community_replies;
create policy "Authors can delete their forum replies" on public.community_replies
for delete to authenticated using (author_id=auth.uid());

drop policy if exists "Users can submit and view their reports" on public.community_reports;
create policy "Users can submit and view their reports" on public.community_reports
for select to authenticated using (reporter_id=auth.uid());
drop policy if exists "Users can submit reports" on public.community_reports;
create policy "Users can submit reports" on public.community_reports
for insert to authenticated with check (reporter_id=auth.uid());

-- Securely create/reuse a one-to-one conversation without allowing a client to add arbitrary members.
create or replace function public.community_start_dm(target_user uuid)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare new_conversation uuid; existing_conversation uuid; target_setting text;
begin
  if auth.uid() is null then raise exception 'Sign in is required'; end if;
  if target_user is null or target_user=auth.uid() then raise exception 'Choose another member'; end if;
  if not exists(select 1 from public.community_profiles where id=target_user) then raise exception 'Member not found'; end if;
  if exists(select 1 from public.community_blocks where (blocker_id=auth.uid() and blocked_id=target_user) or (blocker_id=target_user and blocked_id=auth.uid())) then
    raise exception 'Messaging is unavailable for this member';
  end if;
  select allow_messages into target_setting from public.community_profiles where id=target_user;
  if target_setting='nobody' then raise exception 'This member is not accepting messages'; end if;
  if target_setting='friends_only' and not exists(
    select 1 from public.community_friend_requests f
    where f.status='accepted' and ((f.sender_id=auth.uid() and f.recipient_id=target_user) or (f.sender_id=target_user and f.recipient_id=auth.uid()))
  ) then raise exception 'Send a friend request first';
  end if;
  select c.id into existing_conversation
  from public.community_conversations c
  join public.community_conversation_members a on a.conversation_id=c.id and a.user_id=auth.uid()
  join public.community_conversation_members b on b.conversation_id=c.id and b.user_id=target_user
  where c.is_group=false
    and (select count(*) from public.community_conversation_members m where m.conversation_id=c.id)=2
  limit 1;
  if existing_conversation is not null then return existing_conversation; end if;
  insert into public.community_conversations(created_by,is_group) values(auth.uid(),false) returning id into new_conversation;
  insert into public.community_conversation_members(conversation_id,user_id) values(new_conversation,auth.uid()),(new_conversation,target_user);
  return new_conversation;
end $$;

revoke all on function public.community_start_dm(uuid) from public;
grant execute on function public.community_start_dm(uuid) to authenticated;

-- Only authenticated members can access community data. Do not grant anon access.
revoke all on public.community_profiles, public.community_contacts, public.community_contact_shares,
  public.community_friend_requests, public.community_blocks, public.community_conversations,
  public.community_conversation_members, public.community_messages, public.community_posts,
  public.community_replies, public.community_reports from anon;
grant select,insert,update on public.community_profiles to authenticated;
grant select,insert,update,delete on public.community_contacts to authenticated;
grant select,insert,update,delete on public.community_contact_shares to authenticated;
grant select,insert,update on public.community_friend_requests to authenticated;
grant select,insert,delete on public.community_blocks to authenticated;
grant select on public.community_conversations,public.community_conversation_members to authenticated;
grant select,insert,update on public.community_messages to authenticated;
grant select,insert,update,delete on public.community_posts,public.community_replies to authenticated;
grant select,insert on public.community_reports to authenticated;

-- Enable realtime delivery for private messages when the standard publication exists.
do $$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime')
     and not exists(
       select 1 from pg_publication_tables
       where pubname='supabase_realtime' and schemaname='public' and tablename='community_messages'
     ) then
    alter publication supabase_realtime add table public.community_messages;
  end if;
end $$;

-- Presence and typing are ephemeral Supabase Realtime Presence/Broadcast events;
-- do not persist them as a permanent online-status record.

-- Improve lookup performance for community relationships and reporting.
create index if not exists community_blocks_blocked_idx on public.community_blocks(blocked_id);
create index if not exists community_conversation_members_user_idx on public.community_conversation_members(user_id);
create index if not exists community_conversations_created_by_idx on public.community_conversations(created_by);
create index if not exists community_messages_sender_idx on public.community_messages(sender_id);
create index if not exists community_posts_author_idx on public.community_posts(author_id);
create index if not exists community_replies_author_idx on public.community_replies(author_id);
create index if not exists community_reports_message_idx on public.community_reports(message_id);
create index if not exists community_reports_post_idx on public.community_reports(post_id);
create index if not exists community_reports_reported_user_idx on public.community_reports(reported_user_id);
create index if not exists community_reports_reporter_idx on public.community_reports(reporter_id);
create index if not exists prompt_reports_room_idx on public.prompt_reports(room_id);

-- PostgreSQL invokes this event-trigger function internally, not via the client API.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

# Supabase setup and multiplayer status

The React app is wired to the following Supabase RPC functions:

- `create_game_room` creates a room and its host player.
- `join_game_room` joins an existing room, with a 20-player limit.
- `game_room_action` handles ready state, host controls, votes, and prompt reports.
- `get_room_snapshot` returns the room, players, and saved votes.

The client currently refreshes room state by polling the snapshot RPC. Realtime Postgres subscriptions are not implemented in the current client, so do not describe the app as using realtime subscriptions yet.

## Configure

1. Create or open the Good Company Supabase project.
2. Review and apply `schema.sql` in the Supabase SQL Editor.
3. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in Vercel and local `.env.local`.
4. Never expose a service-role key in browser code or Vercel variables prefixed with `VITE_`.

## Before public launch

The current database schema is an MVP foundation, not a completed security audit. The app uses browser-generated client IDs and a host token stored in the host browser session. These are not equivalent to authenticated user identities. Before public launch, add stronger player identity and abuse controls, room expiry/cleanup, rate limiting, and multi-device/reconnect tests.

Verify that database functions are installed in the correct Supabase project and that the app's Vercel environment variables point to that same project. Test room creation, concurrent joins, host-only controls, voting, prompt reports, and completed-game results from separate devices.

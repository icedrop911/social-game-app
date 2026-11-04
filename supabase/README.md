# Supabase setup and multiplayer status

The React app is wired to the following Supabase RPC functions:

- `create_game_room` creates a room and its host player.
- `join_game_room` joins an existing room, with a 20-player limit.
- `game_room_action` handles ready state, host controls, votes, and prompt reports.
- `get_room_snapshot` returns the room, players, and saved votes.

The client refreshes room state by polling the snapshot RPC. Realtime Postgres subscriptions are not implemented in the current client.

## Configure

1. Create or open the Good Company Supabase project.
2. Review and apply `schema.sql` in the Supabase SQL Editor.
3. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in Vercel and local `.env.local`.
4. Never expose a service-role key in browser code or Vercel variables prefixed with `VITE_`.

## Player and host session protection

Each browser creates a random player-session token for each room. The database stores it in `room_player_secrets` and requires it for snapshots and player actions. The host additionally needs a separate host token for host controls. Tokens are stored in that browser's local storage; they are not Supabase Auth accounts.

The schema removes older RPC signatures that accepted only a public client ID. Apply the complete schema before using the updated frontend. Players already in open rooms must rejoin using the room link/code so their new token is registered. The host should rejoin from the browser that created the room so the host token remains available. For a clean test, create a new room after applying the schema.

## Before public launch

This remains an MVP security foundation, not a completed security audit. Add Supabase Auth or another durable identity system before treating player identity as account-grade security. Also add room expiry/cleanup, rate limiting, abuse monitoring, and multi-device tests.

Verify that database functions are installed in the correct Supabase project and that the app's Vercel environment variables point to that same project. Test room creation, concurrent joins, host-only controls, voting, prompt reports, and completed-game results from separate devices.

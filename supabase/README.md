# Supabase setup (next milestone)

The current app is a front-end interaction preview, not live multiplayer. Do not expose service-role credentials in the browser.

Before production, implement and test tables/RPCs for rooms, players, round state, votes, and prompt reports. Enforce host permissions server-side, use expiring room codes, validate and rate-limit submissions, and enable only the minimum required Row Level Security policies. Realtime subscriptions should be scoped to a room and should not reveal host secrets. Test with multiple devices and reconnects before advertising live play.

After the backend is implemented, set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in local `.env.local` and your deployment provider. Never use the service-role key in client code.
# Good Company

**Less scrolling. More being together.** A social party-game web app for friends, couples, and family.

## What's in this repository
- Responsive React + Vite interface.
- Four party games: Would You Rather, Truth or Dare, Most Likely To, and Never Have I Ever.
- Supabase room creation/join RPCs, a player lobby, host controls, votes, prompt reports, and room-state polling.
- A Community area with email/password accounts, member profiles, online presence, discussions, private one-to-one messages, friend requests, blocking/reporting, and consent-based contact sharing.
- Optional member profile photos in Community and game rooms.

## Run locally

```bash
npm install
npm run dev
```

For a production build:

```bash
npm run build
```

## Current deployment

- Public site: https://good-company-orcin.vercel.app
- Frontend: Vercel
- Backend: Supabase (the connected project was observed as ACTIVE_HEALTHY during the 14 November 2026 readiness audit).
- Main branch: `main`

The game-room UI currently refreshes room state through Supabase RPC polling (normally every 2.5 seconds, with backoff while reconnecting). Community online presence and chat updates use Supabase Realtime. Do not describe game-room state as Realtime-subscribed until that implementation is changed and verified.

## Release status

Good Company is a deployed MVP, **not yet cleared for an unrestricted public launch**. The connected database and core room RPCs exist, but the production gate still includes:
- independent, multi-device testing of room creation, joining, host actions, voting, reconnects, and ended rooms;
- a documented review of public SECURITY DEFINER RPCs and their token/identity checks;
- server-side abuse controls and rate limits for room creation and reporting;
- moderation administration and a tested report-handling process for Community;
- a clear privacy notice, terms, retention policy, and age-assurance wording;
- accessibility and mobile browser QA;
- a successful production build/preview check tied to the exact release commit.

See [LAUNCH_READINESS.md](./LAUNCH_READINESS.md) for the evidence-based audit and [DEPLOYMENT.md](./DEPLOYMENT.md) for the release checklist.

## Supabase configuration

For a fresh development environment, copy `.env.example` to `.env.local` and set:
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY` (a publishable key is preferred for new setups)

Never put a Supabase service-role or secret key in browser-exposed environment variables. The existing production Supabase project already has applied migrations; do not re-run the starter schema against it. Use reviewed, version-controlled migrations for future database changes.

## Product notes

The current game set contains prompt flows rather than a points-based competition. The results screen explicitly states that points are not awarded in this version. The age gate is a self-declared 18+ check, not identity-verified age assurance. The product name should be checked for trademark conflicts before commercial expansion.

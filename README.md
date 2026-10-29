# Good Company

**Less scrolling. More being together.** A social party-game web app for friends, couples, and family.

## What's in this repository
- Responsive React + Vite interface
- Would You Rather, Truth or Dare, Most Likely To, and Never Have I Ever prompt flows
- Room creation preview, invite code UI, player lobby, host-start flow
- Skip/report affordances and family/friends/couples mode selection
- Supabase client configuration placeholder and database schema starter

## Run locally

```bash
npm install
npm run dev
```

For a production build: `npm run build`.

## Backend and deployment status

This repository is a development starter, not a production-ready multiplayer service. The current front end is a local interaction preview: a room code is generated in the browser, and joining that room from another device does not yet connect to the host. Do not present it as live multiplayer until the Supabase RPCs, realtime subscriptions, access controls, reconnect behavior, and multi-device tests are completed.

To configure Supabase, copy `.env.example` to `.env.local`, add the project URL and publishable/anon key, and apply the SQL in `supabase/schema.sql`. Never put a Supabase service-role key in client-side environment variables. Review and test the schema and RPC permissions before public launch.

## Deploy

Import this repository into Vercel or Netlify. Build command: `npm run build`; output directory: `dist`. Add the environment variables only after the Supabase project has been created and configured.

## Product notes

Working title: Good Company. Verify name availability and trademark requirements before commercial launch. Add moderation, abuse prevention, rate limits, privacy disclosures, and accessibility review before a public release.
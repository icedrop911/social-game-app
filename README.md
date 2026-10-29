# Good Company

**Less scrolling. More being together.** A social party-game web app for friends, couples, and family.

## What's in this repository
- Responsive React + Vite interface
- Would You Rather, Truth or Dare, Most Likely To, and Never Have I Ever prompt flows
- Supabase-backed room creation/join RPC integration, player lobby, host controls, votes, prompt reports, and realtime subscriptions (requires backend configuration and testing)
- Skip/report affordances and family/friends/couples mode selection
- Supabase client configuration placeholder and database schema starter

## Run locally

```bash
npm install
npm run dev
```

For a production build: `npm run build`.

## Backend and deployment status

This repository is an MVP starter, not yet a production-ready multiplayer service. The front end is wired to Supabase RPCs and realtime subscriptions, but these flows have not yet been validated against a configured Supabase project or tested across multiple devices. Do not launch publicly until database setup, security hardening, reconnect behavior, rate limiting, and multi-device testing are complete.

To configure Supabase, copy `.env.example` to `.env.local`, add the project URL and publishable/anon key, and apply the SQL in `supabase/schema.sql`. Never put a Supabase service-role key in client-side environment variables. Review and harden the schema and RPC permissions before public launch. In particular, the current client identity and public read policies are MVP-level and are not sufficient as a production security boundary.

## Deploy

Import this repository into Vercel or Netlify. Build command: `npm run build`; output directory: `dist`. Add the environment variables only after the Supabase project has been created and configured.

## Product notes

Working title: Good Company. Verify name availability and trademark requirements before commercial launch. Add moderation, abuse prevention, rate limits, privacy disclosures, and accessibility review before a public release.
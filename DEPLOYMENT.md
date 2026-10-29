# Good Company deployment checklist

## What is ready
- React/Vite front-end app in this repository.
- Supabase SQL starter and environment-variable template.
- GitHub Actions build-check workflow.
- Vercel configuration.

## What still requires project-owner access
I cannot create third-party Supabase or Vercel projects inside your accounts without you authorizing and completing their account setup. Do not paste passwords, service-role keys, or private tokens into chat.

### 1. Create Supabase
1. Create a project at https://supabase.com/dashboard.
2. Open SQL Editor and run the file `supabase/schema.sql` from this repository.
3. Review the SQL and test with a disposable project before using real users. This is a starter schema, not a completed security audit. The current UI is not yet wired to all RPCs/realtime updates, so do not advertise real multiplayer yet.
4. Copy the Project URL and publishable/anon client key from Project Settings → API.

### 2. Deploy the front end
1. Import https://github.com/icedrop911/social-game-app at https://vercel.com/new.
2. Vercel should detect Vite; build command `npm run build`, output directory `dist`.
3. Add VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY only after the backend integration is completed.
4. Deploy and test the preview URL on at least two devices.

## Production gate
Before public launch, wire the app to Supabase RPCs and realtime subscriptions; test concurrent joins, host actions, reconnects, duplicate votes, invalid room codes, and ended rooms; harden player identity and RPC authorization; rate-limit room creation/reporting; review privacy and age-appropriate prompt moderation; and confirm the production build succeeds in CI.
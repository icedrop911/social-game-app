# Good Company release checklist

## Current environment

- Public website: https://good-company-orcin.vercel.app
- Frontend hosting: Vercel
- Backend: existing Supabase project (observed as `ACTIVE_HEALTHY` on 14 November 2026)
- Database migrations observed as applied: community foundation, community performance/RPC hardening, 18+ age gate and avatars, and game-room profile avatars.

The live application already contains Supabase-backed room and Community functionality. The instructions below are for release verification and fresh development environments; they are not instructions to recreate or overwrite the live database.

## Before every release

1. Confirm the intended commit is on the release branch and review its diff.
2. Confirm the Vercel preview builds from that exact commit.
3. Confirm `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` are configured in the intended Vercel environments. Use only a publishable/anon key in the browser.
4. Confirm the connected Supabase project is healthy and migrations are in sync.
5. Run the Supabase security and performance advisors and review every finding. Do not blindly remove SECURITY DEFINER from guest-game RPCs: those functions currently provide the public guest-game interface and require a deliberate authorization redesign before permissions change.
6. Run the end-to-end checks below on at least two separate devices and networks.
7. Obtain release-owner approval before merging to `main` or promoting a production deployment.

## Required end-to-end checks

### Guest game rooms
- Complete the 18+ self-declaration flow.
- Create a room for each of the four games.
- Join each room from a second browser/device using its invite URL and six-character code.
- Confirm the lobby updates on both devices.
- Confirm only the host can start, pause/resume, skip, and end the game.
- Confirm each participant can submit only one vote per round and can change their vote without creating duplicate rows.
- Confirm Most Likely To accepts only a player who belongs to that room.
- Confirm Truth or Dare selection is host-controlled.
- Confirm prompt reports are recorded.
- Test refresh, temporary network loss, reconnect, invalid codes, full rooms, and ended rooms.

### Community
- Test signup, email confirmation, sign-in, sign-out, and password recovery.
- Test profile creation/update and avatar upload with valid and invalid files.
- Test presence across two accounts and verify hidden-online preferences.
- Test forum posting, private messaging, friend requests, blocks, and report submission.
- Verify that contact details remain private until explicitly shared and that revocation works.
- Confirm there is a staffed moderation workflow for reports before opening Community broadly.

### Device and accessibility
- Test current iOS Safari, Android Chrome, and desktop Chrome/Firefox.
- Check narrow screens, keyboard navigation, focus visibility, labels, contrast, reduced motion, and screen-reader names.
- Verify that reconnect messages and action errors are understandable.

## Security and operations gate

- Review all exposed SECURITY DEFINER functions, including guest-game RPCs, with their full privilege and token model.
- Keep direct table access denied for game-room secret tables; use narrowly scoped RPCs.
- Add server-side rate limits and abuse controls for room creation, joining, and reporting.
- Enable leaked-password protection in Supabase Auth.
- Review all RLS policies and the advisor's policy-performance findings.
- Define Community moderation, escalation, blocking, data deletion, retention, privacy, and terms processes.
- Define backup/restore and incident-response procedures.
- Verify custom domain, HTTPS, metadata, analytics/privacy choices, and support contact before commercial promotion.

## Fresh development environment

1. Copy `.env.example` to `.env.local`.
2. Add the Supabase project URL and publishable/anon client key.
3. Use a separate development Supabase project for schema experimentation.
4. Apply reviewed migrations in order. Do not run `supabase/schema.sql` over the already configured production database.
5. Install dependencies with `npm install`, then run `npm run build`.

## Launch decision

A successful Vercel deployment only proves that the frontend was deployed. It does not prove that multiplayer, security, Community moderation, or multi-device behavior is production-ready. Keep the release in controlled beta until the checks above have evidence and the release owner signs off.

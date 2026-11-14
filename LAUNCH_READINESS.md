# Good Company launch-readiness audit

**Audit date:** 14 November 2026  
**Repository:** `icedrop911/social-game-app`  
**Audited production URL:** https://good-company-orcin.vercel.app

## Executive decision

**Status: deployed MVP; not approved for unrestricted public launch.**

The website responds and the connected Supabase project was observed as `ACTIVE_HEALTHY`. The production database contains the room and Community structures, and four migrations are recorded as applied. This is meaningful progress, but it is not evidence that two or more real players can complete every game flow reliably or that Community has an operational moderation process.

## Verified evidence

- The live URL returns the Good Company page title and introductory content.
- The latest inspected `main` commit is `a780594d7bef385a80130a6d29db209e6c91998c`.
- The Supabase project was reported `ACTIVE_HEALTHY`, running PostgreSQL 17.11.
- Applied migration versions observed:
  - `20261111073311` — `good_company_community`
  - `20261111073539` — `community_performance_and_rpc_hardening`
  - `20261111074732` — `good_company_age_gate_and_avatars`
  - `20261111144549` — `game_room_profile_avatars`
- The frontend contains create/join room, snapshot, and action RPC calls. Room state is polled every 2.5 seconds under normal conditions and backs off when reconnecting; it is not currently a game-room Realtime subscription.
- Community uses Realtime Presence for online status and a Realtime database-change subscription for chat messages.
- The four game modes are present. The results screen says points are not awarded in this version.
- The current GitHub Actions workflow only installs dependencies and runs `npm run build`. No workflow run was returned for the audited main commit by the available commit-run lookup.
- The deployment documentation had stale instructions implying the Supabase project still needed to be created and the app was not wired to RPCs. This branch corrects that documentation without changing production code or database state.

## Supabase advisor findings

The 14 November 2026 advisor snapshot returned:

### Security
- Five guest-game SECURITY DEFINER RPCs are callable by `anon`: room creation, joining, room actions, room snapshots, and age self-declaration.
- Seven SECURITY DEFINER functions are callable by `authenticated`; this includes guest-game RPCs plus Community helper/DM functions.
- Seven game tables have RLS enabled with no direct table policies: age-verification markers, rooms, players, votes, room secrets, player secrets, and prompt reports. The current schema intentionally revokes direct table access and exposes game actions through RPCs. This design must be reviewed as a whole; adding broad table policies or blindly revoking guest RPC execution would break guest play.
- Leaked-password protection is disabled in Supabase Auth.

### Performance
- 22 RLS policy findings report per-row evaluation of `auth.uid()`/related auth functions rather than wrapping the call as `(select auth.uid())`.
- 13 indexes were reported unused at audit time. Do not drop these solely on that basis before representative traffic and query plans exist.

### Interpretation
The SECURITY DEFINER warnings are not automatically proof of an exploit: guest rooms are intentionally callable without an account. They do mean that every public RPC must be reviewed for identity binding, secret-token checks, input validation, abuse resistance, and data disclosure. Do not change production grants or functions until that review is complete and tested.

## Release blockers

1. **Multi-device gameplay evidence:** no controlled two-device test has yet been recorded for all four games, concurrent joins, host-only actions, voting, reconnects, or ended rooms.
2. **Abuse controls:** no server-side rate limiting was identified for room creation, joins, or prompt reports.
3. **Age assurance:** the current gate is a self-declared 18+ check. It stores an eligibility marker and does not store the submitted date of birth. Product copy and legal review must describe this accurately; it is not identity-verified age assurance.
4. **RPC security review:** document the threat model for guest client IDs, player tokens, host tokens, age markers, room-code discovery, and all SECURITY DEFINER functions.
5. **Community moderation:** users can submit reports and block members, but an operational moderator/admin queue and response process has not been verified.
6. **Auth hardening:** enable leaked-password protection and review signup confirmation, password recovery, abuse controls, and email delivery.
7. **Privacy/legal:** publish privacy notice, terms, retention/deletion policy, contact/support route, and Community rules.
8. **Mobile/accessibility:** test iOS Safari, Android Chrome, keyboard use, screen readers, contrast, and reduced-motion behavior.
9. **Release CI:** obtain a passing build for the exact release commit and add repeatable end-to-end tests before broad promotion.

## Work deliberately not performed

- No production database schema, migration, RLS policy, or function permission was changed during this audit.
- No production data was edited or deleted.
- No deployment was promoted and no pull request was merged.
- Live interactive browser testing was not completed in this pass; the available browser-run service could not start with the current account balance. This must be completed through a controlled test session before launch approval.

## Next engineering sequence

1. Review and test the guest-game RPC threat model.
2. Implement server-side rate limits and moderation administration in reviewed migrations.
3. Add repeatable browser tests for the four game modes and Community.
4. Verify two-device gameplay and recovery behavior.
5. Enable Auth hardening, complete privacy/legal materials, and perform accessibility/mobile QA.
6. Run a final release-candidate build and sign off before public promotion.

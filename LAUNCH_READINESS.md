# Good Company launch-readiness work

This branch is intentionally separate from production. Do not merge or apply its database migration to production until review and staging verification pass.

## Scope in this branch
- Database write-rate limits for room creation/join/voting/prompt reports and community messages/posts/replies/friend requests/reports.
- Moderator-only report queue access and status updates using trusted `auth.jwt()->app_metadata->>role` claims.
- Immutable moderation review events for status/note changes.
- Accessibility and reduced-motion CSS.
- Room polling pauses while the tab is backgrounded and refreshes immediately when the tab becomes visible.
- A repeatable two-browser manual test plan.

## Age assurance: explicit launch blocker
The existing `verify_game_age(client_id, date_of_birth)` stores only an adult marker, but the client ID and submitted birth date originate in the browser. This is self-declared age gating, not secure age assurance. A user can clear browser storage or fabricate a client ID/date. Do not describe this as identity-verified or robust age verification.

A proper implementation needs a selected age-assurance provider or another legally reviewed age assurance method, server-side verification callbacks, minimal retention, privacy/consent copy, and a documented fallback/appeal path. No provider credentials or vendor choice are available in this repo, so this branch deliberately does not invent one or transmit identity documents.

## Rate-limit limitations
The SQL migration provides per-account limits for authenticated community actions and per-client-ID limits for guest room actions. Guest IDs are browser-generated and spoofable; this is a useful abuse throttle, not an IP/device-level security boundary. Before public scale, route guest room RPCs through an Edge Function/API gateway with IP and risk-based limits. The migration is not applied to any database by this branch.

## Moderator setup
After the migration is reviewed and applied to a staging database, assign moderator access through the Supabase Auth admin API/dashboard by setting trusted `app_metadata.role` to `moderator` (or `admin`). Never use user-editable `user_metadata` for moderator authorization. The UI will only appear for those trusted roles.

## Two-device verification (staging only)
1. Open the Vercel preview in two independent browser profiles/devices.
2. On device A, pass the configured age gate, create a room, and copy its invite URL.
3. On device B, open the invite URL, pass age gate, join with a distinct nickname.
4. Confirm both clients show both players in the lobby within 5 seconds.
5. Start the game on A; confirm B transitions to the same prompt.
6. Vote from B; confirm A sees the vote after refresh.
7. Pause/resume and skip a round from A; confirm B follows.
8. End from A; confirm both show results.
9. Disconnect B briefly, reconnect, and verify state recovers without duplicate players or votes.
10. Repeat with a mobile viewport and a real iOS/Android browser.
Never use production rooms for this test.

## Accessibility QA
- Keyboard-only navigation and visible focus indicators.
- Screen-reader names and live status announcements.
- 200% zoom and narrow viewport (320 CSS px).
- Reduced-motion preference.
- Minimum 44x44 px primary interactive targets.
- Contrast checks in light and dark themes.
- Form labels, error announcements, and modal focus handling.

## Release gate
Do not announce as fully launch-ready until: the migration has been reviewed/applied in staging, CI/build passes, two-device tests pass, moderator role is configured and exercised, provider-backed age assurance is implemented or the product's age policy is formally revised, and mobile/accessibility QA has been signed off.

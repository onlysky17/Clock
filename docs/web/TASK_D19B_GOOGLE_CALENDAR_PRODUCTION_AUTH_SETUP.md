# TASK D19B - Google Calendar Production Auth Setup

## Status

`MERGED / PUBLIC POLICY READY / OWNER GOOGLE CONSOLE ACTION REQUIRED`

D19B prepares the public information needed for Google OAuth production review.
It does not claim that Google has approved or verified the application.

Merged evidence:

- PR #106 merge commit:
  `8b000d84a5cb9875626216246f7547d99087c96d`
- PR #107 visible privacy-link merge commit:
  `eab04d49ccb5ff8ab84d73d2b5555b5631db7201`
- Product Mode exposes `Quyền riêng tư` outside the Advanced section.

Canonical app:

`https://onlysky17.github.io/Clock/test.html`

Public privacy policy:

`https://onlysky17.github.io/Clock/privacy.html`

## Preserved Boundaries

- Google Calendar remains optional.
- Users who skip Google Calendar can still sync time, fetch weather, and render
  the device.
- The requested scope remains
  `https://www.googleapis.com/auth/calendar.readonly`.
- The static page keeps a short-lived access token only in the current browser
  tab session.
- No client secret, refresh token, Calendar content, or location is committed
  to Git or stored by an application backend.
- Firmware, BLE protocol, `test.html`, SDK output, and device state are
  unchanged.

## Public Google OAuth Information

Use these exact values in Google Cloud:

| Field | Value |
| --- | --- |
| Application name | `EINK Clock` |
| Application home page | `https://onlysky17.github.io/Clock/test.html` |
| Privacy policy | `https://onlysky17.github.io/Clock/privacy.html` |
| Authorized JavaScript origin | `https://onlysky17.github.io` |
| Client type | Web application |
| Scope | `https://www.googleapis.com/auth/calendar.readonly` |

The browser Client ID remains:

`64961652220-4b2s7mnvqfut2fsu213gokbi28qs74t6.apps.googleusercontent.com`

No client secret is used by the GitHub Pages application.

## Owner Google Cloud Checklist

1. Merge and deploy this task so the public privacy URL returns HTTP 200.
2. In Google Auth Platform, open **Branding**.
3. Set the application name to `EINK Clock`.
4. Set the home page and privacy-policy URLs to the exact public URLs above.
5. Confirm the support email and developer contact email belong to the owner.
6. In **Audience**, keep the app External and publish it to **In production**.
7. In **Data Access**, keep only the scope actively used by the app:
   `calendar.readonly`.
8. Confirm `onlysky17.github.io` ownership if Google asks for domain
   verification.
9. Submit OAuth verification when Google requests verification for the
   Calendar scope.
10. Provide Google with a short demonstration showing optional sign-in,
    read-only agenda import, session-only handling, revoke, and the public
    privacy page.

Publishing and verification are different gates. Publishing removes the
test-user-only boundary. Google approval is required before D19B may claim that
the unverified-app warning has been removed for public users.

## Owner Verification Matrix

After Google Cloud shows the approved production state, verify on Android
Chrome:

| Check | Required result |
| --- | --- |
| Canonical app opens | PASS |
| Privacy URL opens | PASS |
| User skips Google Calendar | Time, weather, and BLE remain usable |
| First Calendar authorization | No unverified-app warning |
| Read today's agenda | Read-only events appear correctly |
| Reload in the same tab | Valid session is restored |
| Expired authorization | Clear reauthorization request |
| Revoke Calendar permission | Token and agenda session are cleared |
| Unified daily update without Calendar | Continues without forced sign-in |

## Evidence Required To Close D19B

D19B can be closed only after the owner provides:

- Google Auth Platform screenshot showing **In production**;
- verification/approval state for the requested Calendar scope;
- Android Chrome proof that the warning no longer appears;
- proof that users can skip Google Calendar;
- proof that revoke and expiry remain clear and safe.

Until then, the truthful state is:

`PUBLIC POLICY READY / GOOGLE APPROVAL NOT YET VERIFIED`

## Next Action

Owner action (`TASK D19C - GOOGLE CALENDAR PRODUCTION APPROVAL GATE`):

`PUBLISH D19B PRIVACY PAGE, COMPLETE GOOGLE CLOUD PRODUCTION SETUP, THEN RUN THE ANDROID VERIFICATION MATRIX`

No firmware rebuild, BLE protocol change, BIN packaging, or physical panel test
is required for this web and Google-console milestone.

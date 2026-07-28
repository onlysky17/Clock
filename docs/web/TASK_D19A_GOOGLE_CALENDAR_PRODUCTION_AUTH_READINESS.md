# TASK D19A - Google Calendar Production Auth Readiness Audit

## Status

`AUDIT PASS / GOOGLE CLOUD ACTION REQUIRED`

D19A is audit-only. It does not change firmware, web runtime, BLE protocol,
`test.html`, OAuth behavior, or physical-device state.

Canonical URL:

`https://onlysky17.github.io/Clock/test.html`

## Current Integration

- Google Cloud project: `eink-clock-onlysky17`.
- OAuth client type: Web application.
- Authorized JavaScript origin: `https://onlysky17.github.io`.
- Public browser Client ID:
  `64961652220-4b2s7mnvqfut2fsu213gokbi28qs74t6.apps.googleusercontent.com`.
- Requested scope:
  `https://www.googleapis.com/auth/calendar.readonly`.
- Calendar source: the signed-in account's `primary` calendar.
- Authorization library: Google Identity Services token model.

The browser Client ID is public configuration and is safe to keep in the HTML.
No OAuth client secret belongs in this static GitHub Pages repository.

## Proven Root Cause

The warning and repeated authorization are Google OAuth publishing-state
behavior, not a BLE, firmware, calendar-query, or GitHub-account error.

The observed sequence matches an External OAuth application still in Testing or
not verified for its requested Calendar scope:

- only listed test users may authorize while the app is in Testing;
- test users see a warning before granting access;
- Testing authorizations expire after seven days;
- an unverified public app requesting user Calendar data can show the
  unverified-app warning and is subject to Google's new-user cap.

The Google account used for Calendar does not need to match the GitHub account.
While the OAuth app remains in Testing, that Google account must be listed as a
test user.

## Token And Session Boundary

The current static page uses the Google Identity Services browser token model:

- it receives a short-lived access token, not a refresh token;
- it stores the token only in `sessionStorage`;
- it preserves Google's expiry with a one-minute safety margin;
- closing the tab, explicit revoke, malformed/expired state, or HTTP 401 clears
  the saved token;
- automatic token refresh is not available in this browser-only model;
- obtaining an offline refresh token would require the authorization-code flow
  and a trusted backend.

This boundary is intentional. D19A does not add a backend, persistent token,
secret, or background service.

## Optional Google Calendar Behavior

Google Calendar remains optional:

- the unified daily update does not force Google authorization;
- owners without Google Calendar can continue with weather, time, and manual
  agenda data;
- OAuth opens only after the owner explicitly chooses Google Calendar;
- a missing, expired, or revoked Google token must not block BLE time sync or
  device rendering.

## Production Readiness Gaps

Before general public use, the owner must finish these Google Cloud Console
items:

1. Keep the audience `External`.
2. Confirm the authorized JavaScript origin is exactly
   `https://onlysky17.github.io`.
3. Declare only the actively requested
   `https://www.googleapis.com/auth/calendar.readonly` scope.
4. Complete the OAuth Branding and Audience information.
5. Provide a public homepage and privacy-policy URL describing the read-only,
   session-only Calendar use.
6. Verify ownership of the application website as required by Google.
7. Change Publishing status from `Testing` to `In production`.
8. Submit OAuth verification if Google marks the Calendar scope as sensitive
   and requests verification.

Publishing and verification are separate:

- publishing removes the test-user-only deployment boundary;
- verification removes the unverified-app warning for approved sensitive
  scopes and avoids the unverified new-user cap.

Until those actions are complete, personal testing may continue by keeping the
owner's Google account in the Test users list. That fallback is not a public
production launch.

## Android Chrome Verification Matrix

After the Google Console production work, D19B must verify on Android Chrome:

1. First authorization succeeds from the canonical URL.
2. Reload in the same tab restores a still-valid access token.
3. Expired access requires a new owner authorization and fails clearly.
4. `Ngắt quyền lịch` revokes and clears the current tab session.
5. Skipping Google Calendar leaves the unified daily update usable.
6. Calendar access remains read-only and no event data is persisted.
7. No unverified-app warning remains after Google approves the production
   configuration.

## D19B Scope

Next canonical action:

`TASK D19B - GOOGLE CALENDAR PRODUCTION AUTH SETUP AND OWNER VERIFICATION`

D19B is limited to:

- owner-executed Google Cloud publishing and verification;
- adding the minimum public homepage/privacy information if Google requires it;
- Android Chrome verification against the canonical URL;
- a narrow web copy/status adjustment only if the production flow exposes a
  real usability issue.

D19B must not change firmware, BLE protocol, scheduler, D2 packet formats,
`test.html`, or add a client secret. It must not claim Google verification until
the Google Cloud Console shows the approved state.

## Official References

- Google Calendar scopes:
  <https://developers.google.com/workspace/calendar/api/auth>
- Google Identity Services authorization:
  <https://developers.google.com/identity/oauth2/web/guides/overview>
- OAuth application audience and publishing status:
  <https://support.google.com/cloud/answer/15549945>
- Unverified applications:
  <https://support.google.com/cloud/answer/7454865>
- Submitting an application for verification:
  <https://support.google.com/cloud/answer/13461325>

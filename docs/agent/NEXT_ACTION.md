# NEXT_ACTION

## Canonical Current State

- Repository: `D:\EINK\Clock`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`
- Public privacy URL: `https://onlysky17.github.io/Clock/privacy.html`
- D19B web preparation and visible privacy link: MERGED.
- PR #106 merge commit: `8b000d84a5cb9875626216246f7547d99087c96d`.
- PR #107 merge commit: `eab04d49ccb5ff8ab84d73d2b5555b5631db7201`.
- Google Calendar remains optional, read-only, and session-scoped.
- Google approval and removal of the Android unverified-app warning are not yet
  verified.
- No firmware, BLE protocol, BIN, build, pack, flash, or device change was
  made by D19B.

## Next Canonical Action

`TASK D19C - GOOGLE CALENDAR PRODUCTION APPROVAL GATE`

Owner-visible goal:

- Publish the Google OAuth app as External / In production.
- Submit or complete Google verification for `calendar.readonly` when required.
- Confirm the Android unverified-app warning is gone for a normal user.
- Confirm Calendar can still be skipped without affecting time, weather, BLE,
  or rendering.

Audit gates:

1. Google Auth Platform shows External / In production.
2. Home page and privacy URLs use the canonical public URLs above.
3. Authorized JavaScript origin remains `https://onlysky17.github.io`.
4. Data Access keeps only `calendar.readonly`.
5. Android Chrome sign-in completes without the unverified-app warning.
6. Agenda read, reload, expiry, revoke, and skip-Calendar paths are verified.
7. Do not modify firmware, BLE protocol, `test.html`, BIN, SDK output, or SPI
   state.

## Expected Scope

- Owner Google Cloud console action and Android verification only.
- No Google client secret may be committed or embedded.
- Do not claim D19C PASS until Google and Android evidence exists.

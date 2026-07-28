# NEXT_ACTION

## Canonical Current State

- Repository: `D:\EINK\Clock`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`
- TASK D18B agenda firmware SPI final: CLOSED / MERGED / SPI PHYSICAL PASS.
- D18B feature commit: `cdf3d1e050b8e236af56c8f26333307880686051`.
- PR #103 merge commit: `c30b84428767550646b60a28cb5d10e13c8fc8d2`.
- Packed image SHA256: `5790AA976BBC7A57DF63873DCE192F57C606B63A10EDBBD4FFCEE52F9D15F44A`.
- SPI Burn, SPI Verify, cold boot, unified daily update, weather and agenda display, disconnected five-minute refresh, BLE reconnect, and no duplicate or second-black refresh: Owner PASS.
- No BIN or build artifact is tracked by Git.

## Next Canonical Action

`TASK D19A - GOOGLE CALENDAR PRODUCTION AUTH READINESS AUDIT`

Owner-visible goal:

- Remove uncertainty around the Google "unverified/test app" warning on Android.
- Determine the exact Google Cloud publishing and verification requirements for the existing read-only Calendar flow.
- Preserve optional Calendar behavior: users without Google Calendar must never be forced to sign in.
- Preserve session privacy and keep OAuth secrets out of Git.
- Keep the canonical URL and BLE protocol unchanged.

Audit gates:

1. Start from clean `main` with `HEAD == origin/main`.
2. Audit the current OAuth client, consent-screen audience, test-user state, authorized JavaScript origin, and requested scope.
3. Confirm which warning can be removed by publishing versus which requires Google verification.
4. Confirm Android Chrome behavior for sign-in, reload, expiry, revoke, and users who skip Calendar.
5. Define the smallest safe implementation or console-only change before editing the web.
6. Do not modify firmware, BLE protocol, `test.html`, BIN, SDK output, or SPI state.

## Expected Scope

- Audit and design first.
- No Google client secret may be committed or embedded.
- No web implementation starts until the production-auth boundary is documented.

# NEXT_ACTION

## Canonical Current State

- Repository: D:\EINK\Clock
- Branch baseline: main
- Canonical web URL: https://onlysky17.github.io/Clock/test.html
- TASK D16A next-day agenda autonomy policy: CLOSED / MERGED.
- TASK D16B next-day agenda rollover: CLOSED / MERGED.
- D16B PR: #96.
- D16B merge commit: 757bdd3ffa8caee335222f7919a6452671257ec6.
- D16B smoke: PASS.

D16B final behavior:

- Browser-open local-day changes clear stale agenda preview immediately.
- Exactly one coalesced current-day Google Calendar fetch is requested.
- Device refill is guarded and requires an already-connected compatible device.
- The web never auto-connects BLE.
- Firmware agenda expiry and forced day-rollover behavior remain unchanged.
- No firmware, BLE protocol, test.html redirect, BIN, build, package, flash, or physical-device change.

## Next Canonical Action

OWNER DECISION REQUIRED - select the next milestone after D16B.

- D16 currently ends at D16B.
- No D16C scope has been designed or approved.
- Do not infer, create, or implement D16C automatically.
- Do not begin a new feature until the Owner explicitly chooses its task ID, purpose, and scope.

## Guardrails

1. Start from clean main with HEAD equal to origin/main.
2. Preserve canonical URL https://onlysky17.github.io/Clock/test.html.
3. Preserve HINK213 geometry: logical 250 x 122, controller RAM 122 x 250, stride 16, payload 4000 bytes.
4. Do not commit BIN files or build output.
5. Do not modify firmware, BLE protocol, OAuth, persistence, scheduler, or panel rendering without a new approved task.
6. Do not flash, Burn SPI, reset hardware, or claim physical PASS without Owner evidence.

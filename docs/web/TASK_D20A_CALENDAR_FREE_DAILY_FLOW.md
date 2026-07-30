# TASK D20A - Calendar-Free Daily Flow

## Owner Goal

Product Mode must update the daily screen without requiring a Google account or
Google Calendar authorization.

## Final Flow

`Cập nhật màn hình hôm nay` now performs:

1. Weather refresh when phone location is available.
2. Device time synchronization.
3. Apply and render the selected clock face.

Weather remains optional. A weather failure does not block time synchronization
or rendering.

## Calendar Boundary

- Google Calendar controls, OAuth loading, background refresh, and the Calendar
  step were removed from Product Mode.
- The monthly calendar clock face remains unchanged.
- Empty hidden agenda fields remain only to preserve the existing BLE packet
  layout. No Google account or Calendar data is used.

## Scope

- Web-only behavior.
- No firmware, BLE protocol, `test.html`, BIN, build, pack, flash, or physical
  device changes.
- No Owner physical test is required.

## Validation

```powershell
node .\scripts\task-d20a-calendar-free-daily-flow-smoke.mjs
git diff --check
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\eink-auto-preflight.ps1
```

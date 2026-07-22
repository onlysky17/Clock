# TASK D8C - Live Device Health

## Goal

Keep Product Mode health current without requiring the Owner to press `Đọc danh tính thiết bị` after every successful operation.

Canonical URL remains:

`https://onlysky17.github.io/Clock/test.html`

## Behavior

- Identity is still read once after BLE connection.
- A successful D2 SET_TIME schedules one identity refresh.
- D2 render COMPLETE schedules one identity refresh.
- The card shows the local time of the latest successful identity response.
- Refresh failures are logged and shown as `Không đọc được`; they do not convert an already successful sync/render into a false product error.
- The manual identity button remains available.

No interval or background polling is added. Refreshes are event-driven and deduplicated by one in-memory guard.

## Preserved Contracts

- D8B compatibility requires runtime `D8A1` and Source ID `D8A00001`.
- D6B Product Mode state mapping remains active.
- D2 `03` and D2 `83` bytes are unchanged.
- BLE UUIDs, D2/E5/E6 commands, firmware, scheduler, and `test.html` are unchanged.

## Validation

Run:

`node .\scripts\task-d8c-live-device-health-smoke.mjs`

This task is web-only and requires no Keil build, pack, flash, or physical e-ink test.

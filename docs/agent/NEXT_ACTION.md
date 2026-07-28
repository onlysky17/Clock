# NEXT_ACTION

## Canonical Current State

- Repository: `D:\EINK\Clock`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`
- TASK D16A next-day agenda policy: CLOSED / MERGED.
- TASK D16B next-day agenda rollover: CLOSED / MERGED.
- TASK D17A unified daily update flow policy: CLOSED / MERGED.
- D17A implementation commit: `74348f3569015437940aed84b4b8118d2f574911`.
- D17A merge commit: `1af2f6dc22597110fdfc869446bb5ebdac0cc202`.
- D17A policy validation: PASS.
- No firmware, BLE protocol, web runtime, `test.html`, OAuth, BIN, build, package, flash, SPI Burn, or physical-device change.

## Next Canonical Action

`TASK D17B - IMPLEMENT UNIFIED DAILY UPDATE FLOW`

Owner-visible result:

- Product Mode shows one primary action: `Cập nhật màn hình hôm nay`.
- Owner manually connects BLE once, then presses the unified action.
- Progress is shown for weather, Google Calendar, device time, daily context, and display.
- Final result distinguishes full success, degraded success, and the exact failed step.

Required execution order:

1. Confirm an already-connected compatible BLE device.
2. Fetch fresh weather.
3. Fetch current-day Google Calendar agenda when authorized.
4. Synchronize device time through the existing D2 path.
5. Build and apply current-day weather and agenda context.
6. Produce exactly one final visible render.
7. Refresh status only after render completion.

Required behavior:

- Never auto-connect BLE.
- Only one unified run may be active.
- Repeated taps must not create parallel operations.
- Weather and Calendar failures degrade independently.
- Previous-day agenda must never be reused.
- Same-day cached data must be visibly marked cached or stale.
- D2 time-sync failure stops context apply and rendering.
- Render failure must not trigger a blind second render.
- Existing technical controls remain available under Advanced.

## Expected Maximum Tracked Files

1. `web/clock-app/hl24a-canvas-e5.html`
2. `scripts/task-d17b-unified-daily-update-flow-smoke.mjs`
3. `docs/web/TASK_D17A_UNIFIED_DAILY_UPDATE_FLOW_POLICY.md` only when implementation evidence must be appended

## Guardrails

1. Start from clean `main` with `HEAD == origin/main`.
2. Keep D17B web-only.
3. Reuse existing weather, Calendar, D2 time, daily-context, and render paths.
4. Do not modify firmware, BLE protocol, `test.html`, OAuth scopes, persistence, scheduler, or panel geometry.
5. Preserve logical `250 x 122`, controller RAM `122 x 250`, stride `16`, and payload `4000` bytes.
6. Do not commit BIN files or build output.
7. Do not build Keil, pack firmware, flash, Burn SPI, reset hardware, or claim physical PASS.

# NEXT_ACTION

## Canonical Current State

- Repository: `D:\EINK\Clock`
- Canonical branch baseline: `main`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`
- TASK D16A next-day agenda autonomy policy: CLOSED / MERGED.
- TASK D16B next-day agenda rollover: CLOSED / MERGED.
- D16B implementation merge commit: `757bdd3ffa8caee335222f7919a6452671257ec6`.
- D16B closeout merge commit: `e51ae9313435622a313d01f60fa37f835a37e5e3`.

## Current Policy Task

`TASK D17A - UNIFIED DAILY UPDATE FLOW POLICY DESIGN`

- Defines one Product Mode action: `Cập nhật màn hình hôm nay`.
- Defines weather, agenda, device-time, daily-context, and final-render sequencing.
- Defines controlled degraded behavior and cached-data rules.
- Preserves manual BLE connection and existing Advanced controls.
- Design-only: no firmware, BLE protocol, web runtime, `test.html`, BIN, build, pack, flash, or physical-device change.

## Next Canonical Action After D17A Merge

`TASK D17B - IMPLEMENT UNIFIED DAILY UPDATE FLOW`

- Add the primary Product Mode unified-update action.
- Reuse existing weather, Google Calendar, D2 time, daily-context, and render functions.
- Show owner-readable status for each step.
- Coalesce repeated taps into one active run.
- Produce exactly one final visible render.
- Keep all proven technical controls under Advanced.

Expected maximum tracked files:

1. `web/clock-app/hl24a-canvas-e5.html`
2. `scripts/task-d17b-unified-daily-update-flow-smoke.mjs`
3. D17A policy document only when evidence must be appended

## Guardrails

1. Start from clean `main` with `HEAD == origin/main`.
2. Do not auto-connect BLE.
3. Do not modify firmware, BLE protocol, `test.html`, OAuth scopes, persistence, scheduler, or panel geometry.
4. Preserve logical `250 x 122`, controller RAM `122 x 250`, stride `16`, and payload `4000`.
5. Do not commit BIN files or build output.
6. Do not build, pack, flash, Burn SPI, reset hardware, or claim physical PASS during D17A or D17B web-only work.

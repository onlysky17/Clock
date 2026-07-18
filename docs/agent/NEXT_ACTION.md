# NEXT_ACTION

## Canonical Current State

E1A automatic foundation is merged into `main`.

- E1A merge baseline commit: `0b5027d3945bc8514a1191a3a37576de8255e489`
- Active automation files:
  - `AGENTS.md`
  - `.codex/skills/eink-automatic/SKILL.md`
  - `tools/eink-auto-preflight.ps1`
  - `docs/agent/AUTOMATION_MODE.md`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`

Firmware milestone cuối đã đóng:

- `TASK D3E` long-run BLE/EPD lifecycle fix.
- Firmware commit: `08447bf3d142cd9aa1c1314a5beb58559f46659c`.
- Physical evidence:
  - Khoảng 90 phút RUNNING.
  - Uptime `5466` giây.
  - BLE reconnect PASS.
  - Refresh mỗi 5 phút tiếp tục đều.
  - Keil `0 errors`, `0 warnings`.
  - Code `41628`, RO-data `21624`, RW-data `608`, ZI-data `22928`.
  - Raw BIN `64996` bytes.
  - Raw headroom `532` bytes against the `65528` byte limit.
- D3D2 persistence is a passed foundation milestone, but it is not the final firmware milestone.
- D3E handoff has `VERIFY_HOME PASS`.

## Next Canonical Action

`TASK D4A` is the only next canonical action.

D4A is a product-decision task. It must start by deciding UX for `STALE_PRESENT` and the next feature direction after D3E.

Do not claim D4A is approved or implemented yet. Do not invent protocol, firmware behavior, or acceptance criteria before Owner approval.

## Guardrails For The Next Task

1. Start from `main`.
2. Preserve the final geometry contract: logical `250 x 122`, controller RAM `122 x 250`, stride `16`, payload `4000` bytes.
3. Keep the canonical web URL as `https://onlysky17.github.io/Clock/test.html`.
4. Do not use the old `104 x 212` golden geometry for this physical panel.
5. Do not commit `.bin` firmware images or build output.
6. Do not flash, Burn SPI, reset board, run Web Bluetooth physical tests, or claim hardware PASS without Owner evidence.

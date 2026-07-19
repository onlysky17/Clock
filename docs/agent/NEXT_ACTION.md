# NEXT_ACTION

## Canonical Current State

E1A automatic foundation is merged into `main`.

- E1A merge baseline commit: `0b5027d3945bc8514a1191a3a37576de8255e489`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`

Firmware milestone cuối đã đóng:

- `TASK D3E` long-run BLE/EPD lifecycle fix.
- Firmware commit: `08447bf3d142cd9aa1c1314a5beb58559f46659c`.
- D3D2 persistence is a passed foundation milestone, but it is not the final firmware milestone.

Web/layout milestone cuối đã đóng:

- `TASK D5A` flagship daily layout is CLOSED.
- `TASK D5B` bitmap font polish is CLOSED.
- `TASK D5B-FIX1` Vietnamese glyph/layout fix is CLOSED.
- `TASK D5B-FIX2` bitmap baseline normalization is CLOSED/PASS.
- D5B-FIX2 implementation commit: `642738c0b4d4f4bbf763838fe9eb43dca7b4749b`.
- D5B-FIX2 automated smoke PASS.
- D5B-FIX2 automated browser/metrics PASS.
- Owner physical màn e-ink PASS on `19/07/2026`.
- Physical evidence:
  - `THÁNG` and `ÂM` show correct accents;
  - baseline is straight;
  - solar date does not overflow the divider;
  - `HH:mm` is clear and prominent;
  - month calendar has 7 columns;
  - current day highlight is clear;
  - no clipping or stuck-together text.
- Layout is frozen; do not adjust the font again unless there is a regression.
- D5B-FIX2 did not change firmware or protocol.

## Next Canonical Action

`TASK D6A` is the only next canonical action.

TASK D6A — firmware headroom reduction audit and autonomous flagship layout port plan.

D6A must start as a read-only audit:

- Find a way to recover at least about `1-2 KB` of firmware headroom.
- Evaluate how to port the flagship daily layout into the device-side renderer.
- Preserve D3E scheduler/persistence.
- Do not change protocol or SPI sector.
- Do not implement yet.
- Do not claim feasibility until the audit is complete.

## Guardrails For The Next Task

1. Start from `main`.
2. Preserve the final geometry contract: logical `250 x 122`, controller RAM `122 x 250`, stride `16`, payload `4000` bytes.
3. Keep the canonical web URL as `https://onlysky17.github.io/Clock/test.html`.
4. Do not use the old `104 x 212` golden geometry for this physical panel.
5. Do not commit `.bin` firmware images or build output.
6. Do not flash, Burn SPI, reset board, run Web Bluetooth physical tests, or claim hardware PASS without Owner evidence.

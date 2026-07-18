# NEXT_ACTION

## Canonical Current State

E1A automatic foundation is merged into `main`.

- E1A merge baseline commit: `0b5027d3945bc8514a1191a3a37576de8255e489`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`

Firmware milestone cuối đã đóng:

- `TASK D3E` long-run BLE/EPD lifecycle fix.
- Firmware commit: `08447bf3d142cd9aa1c1314a5beb58559f46659c`.
- D3D2 persistence is a passed foundation milestone, but it is not the final firmware milestone.

Web/UX milestone cuối đã đóng:

- `TASK D4A` stale recovery UX decision is CLOSED and approved by Owner.
- `TASK D4B` stale recovery CTA implementation and physical validation are CLOSED/PASS.
- D4B implementation commit: `9b4cb9b58907960b3605b4cbf6a62dc39524b89f`.
- D4B merge/main commit: `ca359a025a7e854b468a381dc7c601a9be053bdc`.
- D4B smoke PASS.
- D4B automated browser 4/4 PASS: `A_STALE`, `B_NOTIFY_RACE_GUARD`, `C_FOLLOW_UP_CONFIRM`, `D_RECOVERY_ERROR`.
- Owner physical test at `https://onlysky17.github.io/Clock/test.html` PASS, including BLE thật PASS and màn e-ink render đúng giờ PASS.
- D4B did not change firmware or protocol.
- D4B required no Keil build or flash.

## Next Canonical Action

`TASK D5A` is the only next canonical action.

D5A is read-only next-feature/product-direction selection after D4B.

D5A has not been approved and has not been implemented. Do not invent a feature, firmware behavior, protocol change, or acceptance criteria before Owner decision.

Expected D5A scope:

- Read canonical state and directly related closeout docs.
- Summarize possible next product directions after D4B.
- Recommend options for Owner decision only.
- Do not modify firmware, web, SDK, smoke, or protocol.

## Guardrails For The Next Task

1. Start from `main`.
2. Preserve the final geometry contract: logical `250 x 122`, controller RAM `122 x 250`, stride `16`, payload `4000` bytes.
3. Keep the canonical web URL as `https://onlysky17.github.io/Clock/test.html`.
4. Do not use the old `104 x 212` golden geometry for this physical panel.
5. Do not commit `.bin` firmware images or build output.
6. Do not flash, Burn SPI, reset board, run Web Bluetooth physical tests, or claim hardware PASS without Owner evidence.

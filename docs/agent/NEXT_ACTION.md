# NEXT_ACTION

## Canonical Current State

E1A automatic foundation is merged into `main`.

- E1A merge baseline commit: `0b5027d3945bc8514a1191a3a37576de8255e489`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`

Firmware milestone cuoi da dong:

- `TASK D7A` autonomous flagship daily layout is CLOSED, MERGED, and PHYSICAL PASS.
- D7A implementation commit: `2308fce61388ef99126cc80a6c81fd9b353baed4`.
- D7A calendar alignment FIX1 commit: `68a47e5c4ce90c874f9c3c21bdb34754e4444600`.
- D7A immediate D2 render FIX2 commit: `32fa562d0d36127a3ded4b46bd35148ff3ccc172`.
- Main merge commit after FIX1/FIX2: `b4e8002774231f197821308d49c11327bda3e550`.
- Owner physical evidence on `2026-07-20`:
  - D2 `SYNCED -> RENDERING -> COMPLETE` PASS.
  - Layout appears immediately after `Dong bo gio` PASS.
  - No blank panel after D2 COMPLETE PASS.
  - Header `T2..CN` aligns with date columns PASS.
  - Current-day invert highlight PASS.
  - Solar date, large `HH:mm`, and lunar date PASS.
  - Divider, clipping, and overlap PASS.
  - BLE-disconnected five-minute scheduler PASS.
  - No duplicate refresh and no second black refresh PASS.
  - E6 was NOT RUN during the autonomous test.
- Final build evidence: Code `41968`, RO-data `3592`, RW-data `552`, ZI-data `22928`, raw BIN `47248` bytes.
- Final raw BIN SHA256: `14CF053BC1EF88B7CCB7733F8372F6484AD635FE6012613D7024FA07F69CE986`.
- Keil result: `0 errors`, `0 warnings`.
- Legacy font symbols remain absent from the active renderer link path.
- D3E long-run BLE/EPD lifecycle fix and D3D2 persistence remain passed foundation milestones.

Web/layout milestone cuoi da dong:

- `TASK D5A` flagship daily layout is CLOSED.
- `TASK D5B` bitmap font polish is CLOSED.
- `TASK D5B-FIX1` Vietnamese glyph/layout fix is CLOSED.
- `TASK D5B-FIX2` bitmap baseline normalization is CLOSED/PASS.
- D5B-FIX2 implementation commit: `642738c0b4d4f4bbf763838fe9eb43dca7b4749b`.
- D5B-FIX2 automated smoke PASS.
- D5B-FIX2 automated browser/metrics PASS.
- Owner physical e-ink panel PASS on `2026-07-19`.
- D7A now owns the final autonomous firmware layout for the physical panel.

## Current Finding

- Product Mode needs a visible test identity/cache marker so Owner can distinguish stale cached web builds from the intended D7A test page.
- The page must not claim the firmware currently in the chip is automatically verified, because there is no firmware version command yet.

## Next Canonical Action

`TASK D7A-WEB1` is the only next canonical action.

TASK D7A-WEB1 - add visible test identity and cache marker.

Goal:

- Keep the canonical URL as `https://onlysky17.github.io/Clock/test.html`.
- Show the web build/test identity visibly in Product Mode.
- Show Expected Firmware: `D7A`.
- Show firmware commit marker: `32fa562d`.
- Show shortened BIN hash marker: `14CF053B`.
- Help Owner distinguish stale cached web builds.
- Do not change BLE protocol.
- Do not claim firmware in chip has been automatically verified.

D7B must not start until D7A-WEB1 is fixed and closed out.

## Guardrails For The Next Task

1. Start from `main`.
2. Preserve the final geometry contract: logical `250 x 122`, controller RAM `122 x 250`, stride `16`, payload `4000` bytes.
3. Keep the canonical web URL as `https://onlysky17.github.io/Clock/test.html`.
4. Do not use the old `104 x 212` golden geometry for this physical panel.
5. Do not commit `.bin` firmware images or build output.
6. Do not flash, Burn SPI, reset board, run Web Bluetooth physical tests, or claim hardware PASS without Owner evidence.

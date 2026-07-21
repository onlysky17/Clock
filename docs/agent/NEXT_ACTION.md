# NEXT_ACTION

## Canonical Current State

E1A automatic foundation is merged into `main`.

- E1A merge baseline commit: `0b5027d3945bc8514a1191a3a37576de8255e489`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`

Firmware milestone cuoi da dong:

- `TASK D7B FIX5` flagship layout persistent SPI final is CLOSED, MERGED, and PHYSICAL PASS.
- D7B FIX5 implementation commit: `e9a32950a7093ff31d0a06720fb74d9f9c5cff82`.
- D7B package merge commit: `a9396797d3a7300093264722feed0b2578960b21`.
- Final packed SHA256: `048D916521B6B0A54D2192409340D1D2EB270C8A72CD98147C66ADE9928843FF`.
- SPI Burn/Verify, cold boot, D2 sync, FIX5 first-boot redraw, five-minute scheduler, and BLE reconnect: PASS.
- No blank panel, duplicate refresh, or second black refresh.

Historical D7A lineage:

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

- D7B FIX5 is the current known-good persistent SPI baseline.
- Package path: `D:\EINK\Clock\_incoming\D7B_FIX5_SPI_FINAL_2026-07-21`.

## Next Canonical Action

No new implementation task is authorized yet.

- Preserve D7B FIX5 without firmware, web, protocol, or layout changes.
- Wait for Owner to name the next milestone.

## Guardrails For The Next Task

1. Start from `main`.
2. Preserve the final geometry contract: logical `250 x 122`, controller RAM `122 x 250`, stride `16`, payload `4000` bytes.
3. Keep the canonical web URL as `https://onlysky17.github.io/Clock/test.html`.
4. Do not use the old `104 x 212` golden geometry for this physical panel.
5. Do not commit `.bin` firmware images or build output.
6. Do not flash, Burn SPI, reset board, run Web Bluetooth physical tests, or claim hardware PASS without Owner evidence.

# NEXT_ACTION

## Canonical Current State

E1A automatic foundation is merged into `main`.

- E1A merge baseline commit: `0b5027d3945bc8514a1191a3a37576de8255e489`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`

Firmware milestone cuối đã đóng:

- `TASK D6C` compact bitmap renderer replacement is PHYSICAL PASS, merged into `main`, and CLOSED.
- Merge commit: `2ad9dc6b228f8406741fb9046c33b2554fa6e179`.
- Implementation commit: `14d72b9f169bf7ef2e3ccbea721e638c7d073ee3`.
- PR: `#37`.
- Owner physical evidence on `20/07/2026`:
  - SysRAM load PASS.
  - D2 immediate render PASS.
  - HH:mm bitmap, colon, and clipping PASS.
  - BLE disconnect PASS.
  - Five-minute autonomous refresh PASS.
  - No duplicate refresh and no second black refresh PASS.
  - E-ink panel displayed `08:35` on `20/07/2026`.
- Build evidence: Code `40804`, RO-data `3592`, RW-data `552`, ZI-data `22928`, raw BIN `46084` bytes, headroom `19444` bytes.
- Legacy font symbols are gone from the active D6C renderer link path.
- Post-merge gate PASS: `HEAD == origin/main`, working tree clean, and EINK AUTO PREFLIGHT PASS.
- D3E long-run BLE/EPD lifecycle fix and D3D2 persistence remain passed foundation milestones.

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

## Current Finding

- Web Product Mode can show `Có lỗi` even when the D2 log reports OK/SYNCED/COMPLETE.
- This is a web status rendering/state issue and did not block D6C firmware merge or physical PASS.

## Next Canonical Action

`TASK D6B-FIX1` is the only next canonical action.

TASK D6B-FIX1 — repair Product Mode device-state mapping.

Reason:

- Web Product Mode can show `Có lỗi` while D2 state/log is OK/SYNCED/RENDERING/COMPLETE.

D6D must not start until D6B-FIX1 is fixed and closed out.

D6B-FIX1 must preserve D6C bitmap firmware behavior, D3E scheduler/persistence, geometry, protocol, and SPI sector unless the task explicitly scopes changes.

## Guardrails For The Next Task

1. Start from `main`.
2. Preserve the final geometry contract: logical `250 x 122`, controller RAM `122 x 250`, stride `16`, payload `4000` bytes.
3. Keep the canonical web URL as `https://onlysky17.github.io/Clock/test.html`.
4. Do not use the old `104 x 212` golden geometry for this physical panel.
5. Do not commit `.bin` firmware images or build output.
6. Do not flash, Burn SPI, reset board, run Web Bluetooth physical tests, or claim hardware PASS without Owner evidence.

# NEXT_ACTION

## Canonical Current State

E1A automatic foundation is merged into `main`.

- E1A merge baseline commit: `0b5027d3945bc8514a1191a3a37576de8255e489`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`

Firmware milestone cuối đã đóng:

- `TASK D7A` autonomous flagship daily layout is PHYSICAL PASS, merged into `main`, and CLOSED.
- Merge/main commit: `248d49b02914a996e503b7e00d73e6db8ef463b9`.
- Implementation commit: `2308fce61388ef99126cc80a6c81fd9b353baed4`.
- Owner Physical PASS date: `2026-07-20`.
- SysRAM artifact: `D:\EINK\Clock\_incoming\D7A_SYSRAM_TEST\D7A_SYSRAM_ble_app_peripheral_585.bin`.
- Raw BIN SHA256: `A7AD2917A8A7DCB0C5661E770C9A9E782008397D01F39243C60B7A58B7BDDB37`.
- Build evidence:
  - Keil `0 errors`, `0 warnings`.
  - Code `41932`, RO-data `3592`, RW-data `552`, ZI-data `22928`.
  - Raw BIN `47212` bytes.
  - Packer headroom `18316` bytes.
  - Legacy font symbols absent.
- Owner physical evidence:
  - D2 SYNCED -> RENDERING -> COMPLETE: PASS.
  - Autonomous immediate render: PASS.
  - Solar date `T2 20/07/2026`: PASS.
  - Large time render: PASS.
  - Lunar `ÂL 07/06`: PASS.
  - Monthly calendar 7 columns: PASS.
  - Current day `20` invert highlight: PASS.
  - Divider/text clipping/overlap: PASS.
  - BLE-disconnected scheduler refresh at `13:35`: PASS.
  - No duplicate refresh and no second black refresh PASS.
- D7A is CLOSED / MERGED / PHYSICAL PASS.
- Post-merge gate PASS: `HEAD == origin/main`, working tree clean, and EINK AUTO PREFLIGHT PASS.
- D3E long-run BLE/EPD lifecycle fix and D3D2 persistence remain passed foundation milestones.

## Next Canonical Action

`TASK D7A-WEB1` is the only next canonical action.

TASK D7A-WEB1 — add visible test identity and cache marker.

Goals:

- Canonical URL remains `https://onlysky17.github.io/Clock/test.html`.
- Product Mode must show the active web/test build identity.
- Display Expected Firmware `D7A / 2308fce`.
- Display shortened BIN hash `A7AD2917`.
- Help Owner distinguish stale cached web builds from the current test page.
- Do not change BLE protocol.
- Do not claim the firmware currently in-chip is verified unless firmware later exposes a version command.

D7B must not start until D7A-WEB1 is fixed and closed out.

## Guardrails For The Next Task

1. Start from `main`.
2. Preserve the final geometry contract: logical `250 x 122`, controller RAM `122 x 250`, stride `16`, payload `4000` bytes.
3. Keep the canonical web URL as `https://onlysky17.github.io/Clock/test.html`.
4. Do not use the old `104 x 212` golden geometry for this physical panel.
5. Do not commit `.bin` firmware images or build output.
6. Do not flash, Burn SPI, reset board, run Web Bluetooth physical tests, or claim hardware PASS without Owner evidence.

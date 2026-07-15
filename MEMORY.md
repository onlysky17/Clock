# MEMORY

## TASK C2K SPI Final Closeout

- Repo: `D:\EINK\Clock`
- Canonical web: `https://onlysky17.github.io/Clock/test.html`
- Final firmware image: `D:\EINK\Clock\_incoming\TASK_C2J_FINAL_PACKED_256KB.bin`
- Size: `262144` bytes
- SHA256: `2D6A48DE726AC02325EA7A1D657421C0ABBD7FC4FE6D652348393FA11D207F47`
- Do not commit `.bin` firmware images.

Verified hardware state:
- Firmware runs persistently from SPI after cold boot.
- SysRAM load is no longer required for the final image.
- E5 COMPLETE: payload `4000` bytes, chunks `286`, CRC match.
- E6 COMPLETE.
- C2G full-panel PASS.
- C2H one-shot latch PASS.
- C2J size trim PASS.
- SPI persistent final PASS.
- SPI Burn/Verify PASS.
- Cold boot PASS.
- Full screen is clean.
- Panel remained unchanged after 30 seconds.
- After BLE disconnect and another 30 seconds, panel still remained unchanged.
- No unintended second refresh to black.

Final geometry:
- Physical panel logical geometry: `250 x 122`
- Controller RAM geometry: `122 x 250`
- Stride: `16` bytes
- Framebuffer payload: `4000` bytes
- Do not use the old `104 x 212` golden geometry for this physical panel.

## TASK D1 Clock Web Milestone

- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`
- Current page title: `TASK D1C - Auto Minute Clock Sync`
- Current badge: `TASK D1C • AUTO MINUTE CLOCK SYNC • HINK213 BW`
- Current heading: `250×122 Clock Preview → Auto E5/E6 Minute Sync`
- The current page no longer shows `TASK C2G`, `C2G`, or `C1 TEST` labels.

Verified web clock state:
- D1A PASS: preview uses browser local time, large `HH:mm`, short Vietnamese weekday/date, and the update button only redraws/repacks without sending BLE.
- D1B PASS: `Đồng bộ giờ lên màn` draws the current clock, sends E5, waits for E5 COMPLETE with CRC match, then sends E6 and waits for E6 COMPLETE.
- D1C PASS: `Tự đồng bộ khi phút đổi` defaults OFF, first enable does not send immediately, sends only when the full minute key changes, does not overlap transfers, and turns OFF on disconnect/error.
- D1C physical auto minute sync PASS.

Stable web/firmware contract:
- Logical canvas: `250 x 122`
- Controller RAM: `122 x 250`
- Stride: `16`
- Payload: `4000` bytes
- Chunks: `286`
- E5 CRC16
- E6 one-shot refresh
- Persistent firmware still runs from SPI after cold boot, does not need SysRAM, and does not refresh black after disconnect.

Next proposed milestone:
- `TASK D2A — DEVICE TIME SYNC PROTOCOL DESIGN`
- D2A should design epoch/timezone transfer from web to firmware only.
- D2A should not implement yet, should not auto refresh device-side, and should not modify EPD.
- D2A must decide data format, persistence, drift handling, and reconnect behavior.

## TASK D2E D2D Final SPI Closeout

- Repo: `D:\EINK\Clock`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`
- Canonical source: `D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE`
- Final packed firmware image: `D:\EINK\Clock\_incoming\TASK_D2D_FINAL_PACKED_256KB.bin`
- Final packed size: `262144` bytes
- Final packed SHA256: `F9C08469C1267C291EA722818E6A7451773D86C5AA271741BEF113AB2537142B`
- Raw canonical build size: `65164` bytes
- Packer raw limit: `65528` bytes
- Golden full image: `D:\EINK\Clock\tools\packages\HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin`
- Golden SHA256: `C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452`
- Do not commit `.bin` firmware images.

Verified D2 state:
- D2B firmware RAM-only time handler PASS.
- D2C web device time controls PASS.
- D2D firmware-rendered clock command PASS.
- D2D persistent SPI PASS after Burn/Verify and cold boot.
- `D2 00 SET_TIME` PASS.
- `D2 01 GET_TIME_STATUS` PASS.
- `D2 02 RENDER_CLOCK_NOW` PASS.
- `D2 82` sequence: ACCEPTED -> RENDERING -> COMPLETE.
- BLE stays connected during D2D render.
- Firmware renders `HH:mm` directly into `fb_bw`.
- D2D does not use E5 transfer and does not call legacy `clock_draw`.
- No unintended second black refresh.

Operational notes:
- Time state is still RAM-only and is lost after reset/cold boot.
- After cold boot, run: Connect -> Gửi giờ xuống thiết bị -> Vẽ giờ từ thiết bị lên màn.
- QR and low-battery legacy visual redraw paths are disabled as an accepted firmware-size tradeoff; current HINK213 clock-panel flow is unaffected.
- Next milestone: `TASK D3A — device auto-minute clock policy/design`.

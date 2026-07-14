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

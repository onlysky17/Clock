# NEXT_ACTION

Current final state is closed out:
- C2G full-panel PASS.
- C2H one-shot latch PASS.
- C2J size trim PASS.
- SPI persistent final PASS.
- D1A preview giờ thật PASS.
- D1B one-tap E5 to E6 PASS.
- D1C auto sync khi phút đổi PASS.
- D2B RAM-only time handler PASS.
- D2C web device time controls PASS.
- D2D device-side clock renderer PASS.
- D2D persistent SPI PASS.

No immediate recovery action is required.

If continuing development:
1. Start from `main`.
2. Preserve the final geometry contract: logical `250 x 122`, controller RAM `122 x 250`, stride `16`, payload `4000` bytes.
3. Keep the canonical web URL as `https://onlysky17.github.io/Clock/test.html`.
4. Do not use the old `104 x 212` golden geometry for this physical panel.
5. Do not commit `.bin` firmware images.
6. Before any future SPI write, verify a fresh backup and a packed image SHA256.

Final firmware image remains local only:
D:\EINK\Clock\_incoming\TASK_D2D_FINAL_PACKED_256KB.bin

Final D2D image facts:
- Packed size: 262144 bytes.
- Packed SHA256: `F9C08469C1267C291EA722818E6A7451773D86C5AA271741BEF113AB2537142B`.
- Raw canonical build size: 65164 bytes.
- Packer raw limit: 65528 bytes.
- D2 time state is RAM-only and is lost after reset/cold boot.
- After cold boot, use: Connect -> Gửi giờ xuống thiết bị -> Vẽ giờ từ thiết bị lên màn.
- QR and low-battery legacy visual redraw paths are disabled as an accepted firmware-size tradeoff; current HINK213 clock-panel flow is unaffected.

## Current protocol design

TASK D2A — DEVICE TIME SYNC PROTOCOL DESIGN

Status:
- Protocol contract designed.
- No firmware implementation yet.
- No web runtime implementation yet.
- No EPD changes.

Goal:
- Design a protocol to send epoch/timezone from the web page down to firmware.
- Use `D2 00 SET_TIME` and `D2 01 GET_TIME_STATUS`.
- Keep D2 RAM-only at first.

## Current implementation task

TASK D2D — DEVICE CLOCK RENDER COMMAND

D2D scope:
- Add manual `D2 02 RENDER_CLOCK_NOW`.
- Firmware renders from RAM-only D2 epoch/timezone state.
- Firmware draws into existing `fb_bw` and performs one physical refresh from an application timer callback.
- Web adds a manual "Vẽ giờ từ thiết bị lên màn" button and parses `D2 82` render status.
- No automatic minute refresh yet.
- E5/E6 transfer contracts remain unchanged.
- Legacy QR and low-battery visual redraw paths are disabled as an accepted size tradeoff; current HINK213 clock-panel flow is unaffected.

Validation still required outside Codex:
- Sync canonical source to SDK.
- Run one Keil rebuild and confirm raw size still fits the packer limit.
- Test through canonical URL after flashing/loading the D2D build.

Current design milestone:
- D3A — Device auto-minute clock policy/design is complete.

D3A policy summary:
- Use D2 RAM-only time state.
- Minute key formula: `floor((current_epoch_utc + timezone_offset_minutes * 60) / 60)`.
- Do not render twice for the same minute.
- DAILY_5_MIN is the default physical refresh cadence.
- TEST_1_MIN is reserved for QA only.
- Day rollover forces refresh.
- Busy E5/E6/D2D states keep only the latest pending minute.
- Cold boot remains UNSET until SET_TIME.
- BLE disconnect does not turn off auto clock.
- D2 02 manual render remains available and updates last-rendered minute state.
- D3B must preserve the approximate 364-byte raw headroom and audit map before coding.

Next milestone:
- D3B — Auto-minute scheduler implementation.

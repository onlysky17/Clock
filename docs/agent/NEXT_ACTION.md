# NEXT_ACTION

Current final state is closed out:
- C2G full-panel PASS.
- C2H one-shot latch PASS.
- C2J size trim PASS.
- SPI persistent final PASS.
- D1A preview giờ thật PASS.
- D1B one-tap E5 to E6 PASS.
- D1C auto sync khi phút đổi PASS.

No immediate recovery action is required.

If continuing development:
1. Start from `main`.
2. Preserve the final geometry contract: logical `250 x 122`, controller RAM `122 x 250`, stride `16`, payload `4000` bytes.
3. Keep the canonical web URL as `https://onlysky17.github.io/Clock/test.html`.
4. Do not use the old `104 x 212` golden geometry for this physical panel.
5. Do not commit `.bin` firmware images.
6. Before any future SPI write, verify a fresh backup and a packed image SHA256.

Final firmware image remains local only:
D:\EINK\Clock\_incoming\TASK_C2J_FINAL_PACKED_256KB.bin

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

Later tasks:
- D2E — Device-side auto minute render policy after D2D size and physical behavior are verified.

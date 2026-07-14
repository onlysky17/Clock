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

TASK D2B — Firmware time state + D2 command handler

D2B status:
- Firmware handler implemented in canonical source.
- Time state is RAM-only.
- No panel refresh.
- No SPI/flash writes.
- E5/E6 unchanged.

Validation still required outside Codex:
- Sync canonical source to SDK.
- Run one Keil rebuild.
- Load SysRAM or next packed test image only after build result is reviewed.

## Next implementation task

TASK D2C — Web time sync controls

D2C scope:
- Add web controls to send `D2 00 SET_TIME`.
- Add status display using `D2 01 GET_TIME_STATUS`.
- Do not add device-side auto panel clock yet.
- Keep existing D1 web E5/E6 flow intact.

Later tasks:
- D2D — Device-side minute renderer: firmware refreshes clock by minute after refresh policy and battery review.

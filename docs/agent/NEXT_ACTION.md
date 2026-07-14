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

## Proposed next task

TASK D2A — DEVICE TIME SYNC PROTOCOL DESIGN

Goal:
- Design a protocol to send epoch/timezone from the web page down to firmware.
- Do not implement it yet.
- Do not auto refresh device-side yet.
- Do not modify EPD.

Design questions to close in D2A:
- Data format for epoch/timezone/local offset.
- Whether and how time should persist across reboot.
- Drift behavior while BLE is disconnected.
- Reconnect behavior and conflict handling.
- How device-side time interacts with the existing web-driven E5/E6 clock flow.

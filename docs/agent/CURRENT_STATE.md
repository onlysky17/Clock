# CURRENT_STATE

Active firmware base:
firmware/active/HINK213_CLOCK_22_BASE

Canonical web:
https://onlysky17.github.io/Clock/test.html

Final persistent firmware:
D:\EINK\Clock\_incoming\TASK_C2J_FINAL_PACKED_256KB.bin

SHA256:
2D6A48DE726AC02325EA7A1D657421C0ABBD7FC4FE6D652348393FA11D207F47

Verified final state:
- C2G full-panel PASS.
- C2H one-shot latch PASS.
- C2J size trim PASS.
- SPI persistent final PASS.
- Firmware runs persistently from SPI after cold boot; SysRAM is not required.
- SPI Burn/Verify PASS.
- Cold boot PASS.
- E5 COMPLETE: payload 4000 bytes, chunks 286, CRC match.
- E6 COMPLETE.
- Panel logical geometry is 250 x 122.
- Controller RAM geometry is 122 x 250.
- Stride is 16 bytes.
- Full screen is clean.
- Panel remained unchanged after 30 seconds.
- After BLE disconnect and another 30 seconds, panel still remained unchanged.
- No unintended refresh to black.
- D1A clock web PASS: preview uses browser local time, shows large HH:mm, shows short Vietnamese weekday/date, and `Cập nhật giờ hiện tại` only redraws/re-packs without sending BLE.
- D1B one-tap clock sync PASS: `Đồng bộ giờ lên màn` draws current clock, sends E5, waits for E5 COMPLETE plus CRC match, then sends E6 and waits for E6 COMPLETE.
- D1B physical panel PASS: the panel displayed the correct real local time.
- D1C auto minute sync PASS: `Tự đồng bộ khi phút đổi` defaults OFF, first enable does not send immediately, sends only when the minute key changes, prevents overlap, and turns OFF on disconnect/error.
- D1C physical auto minute sync PASS.

Current web labels:
- Title: `TASK D1C - Auto Minute Clock Sync`
- Badge: `TASK D1C • AUTO MINUTE CLOCK SYNC • HINK213 BW`
- Heading: `250×122 Clock Preview → Auto E5/E6 Minute Sync`
- The current page does not show old `TASK C2G`, `C2G`, or `C1 TEST` labels.

Important geometry note:
- Do not use the old 104 x 212 golden geometry for this physical panel.
- The final physical-panel contract is 250 x 122 logical pixels over 122 x 250 controller RAM.

Stable E5/E6 contract:
- Logical canvas: 250 x 122.
- Controller RAM: 122 x 250.
- Stride: 16 bytes.
- Payload: 4000 bytes.
- Chunks: 286.
- E5 CRC16.
- E6 one-shot refresh.

Do not commit `.bin` firmware images. The final `.bin` remains local under:
D:\EINK\Clock\_incoming

# TASK C2K SPI Final Manifest

## Firmware Image

- Filename: `TASK_C2J_FINAL_PACKED_256KB.bin`
- Local path: `D:\EINK\Clock\_incoming\TASK_C2J_FINAL_PACKED_256KB.bin`
- Size: `262144` bytes
- SHA256: `2D6A48DE726AC02325EA7A1D657421C0ABBD7FC4FE6D652348393FA11D207F47`
- Git policy: do not commit `.bin` firmware images.

## Target

- Device: DA14585 HINK213 2.13 inch e-paper BLE clock
- Physical panel logical geometry: `250 x 122`
- Controller RAM geometry: `122 x 250`
- Stride: `16` bytes
- Framebuffer payload: `4000` bytes
- Do not use the old `104 x 212` golden geometry for this physical panel.

## Web

- Canonical URL: `https://onlysky17.github.io/Clock/test.html`

## E5 Contract

- Payload: `4000` bytes
- Chunk size: max `14` bytes
- Chunks: `286`
- CRC: browser CRC must match firmware CRC
- Verified result: `E5 COMPLETE`, payload `4000` bytes, chunks `286`, CRC match

## E6 Contract

- One explicit E6 request causes exactly one physical refresh.
- Status polling never triggers a refresh.
- After E6 starts, legacy QR/LB/clock redraws are latched off.
- COMPLETE/ERROR disarm the E6 timer.
- Disconnect does not refresh or clear the panel.
- Verified result: `E6 COMPLETE`

## Hardware Validation

- C2G full-panel PASS.
- C2H one-shot latch PASS.
- C2J size trim PASS.
- SPI Burn/Verify PASS.
- Cold boot persistent SPI PASS.
- Firmware runs persistently from SPI after cold boot; SysRAM load is not required.
- Full panel refresh is clean.
- Panel remained unchanged after 30 seconds.
- After BLE disconnect and another 30 seconds, panel still remained unchanged.
- No unintended second refresh to black was observed.

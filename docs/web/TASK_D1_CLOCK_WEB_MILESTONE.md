# TASK D1 Clock Web Milestone

## Scope

This milestone closes out the working web-clock control path for the DA14585 HINK213 e-paper clock.

Canonical URL:

```text
https://onlysky17.github.io/Clock/test.html
```

No firmware behavior changed in D1. The persistent firmware final remains the C2K SPI image.

## D1A PASS

- Preview takes time from the browser local timezone.
- The preview shows a large `HH:mm`.
- The preview shows a short Vietnamese weekday/date below the time.
- `Cập nhật giờ hiện tại` only redraws/re-packs the canvas.
- D1A does not send BLE automatically.

## D1B PASS

- `Đồng bộ giờ lên màn` performs the manual one-tap flow.
- The flow draws the current clock.
- The flow sends E5.
- E5 reaches COMPLETE and browser CRC matches firmware CRC.
- The flow then sends E6.
- E6 reaches COMPLETE.
- Physical panel test PASS: the panel displayed the correct real local time.

## D1C PASS

- `Tự đồng bộ khi phút đổi` is available as an Auto sync checkbox.
- Auto sync defaults OFF each time the page opens.
- The first enable does not send immediately; it arms the current minute and waits for the next minute.
- Auto sync sends only when the full minute key changes.
- Minute key includes year, month, day, hour, and minute.
- Auto sync does not overlap E5/E6 flows and does not send repeatedly in the same minute.
- BLE disconnect turns Auto sync OFF.
- E5/E6 error turns Auto sync OFF.
- Physical auto minute sync test PASS.

## Current Page Labels

- Document title: `TASK D1C - Auto Minute Clock Sync`
- Badge: `TASK D1C • AUTO MINUTE CLOCK SYNC • HINK213 BW`
- Heading: `250×122 Clock Preview → Auto E5/E6 Minute Sync`
- The current page no longer shows old `TASK C2G`, `C2G`, or `C1 TEST` labels.

## Stable Contract

- Logical canvas: `250 x 122`
- Controller RAM: `122 x 250`
- Stride: `16` bytes
- Payload: `4000` bytes
- Chunks: `286`
- E5 CRC16
- E6 one-shot refresh
- Polarity and ROTATE_3 mapping remain unchanged.

## Firmware Persistent Final

- Firmware runs from SPI after cold boot.
- SysRAM is not required for the final image.
- Packed final SHA256:

```text
2D6A48DE726AC02325EA7A1D657421C0ABBD7FC4FE6D652348393FA11D207F47
```

- No unintended refresh to black after BLE disconnect.
- Do not commit `.bin` firmware images.

## Next Action

Recommended next task:

```text
TASK D2A — DEVICE TIME SYNC PROTOCOL DESIGN
```

D2A goal:

- Design the protocol for sending epoch/timezone from web to firmware.
- Do not implement it yet.
- Do not add device-side auto refresh yet.
- Do not modify EPD.
- Decide data format, persistence, drift behavior, and reconnect behavior.

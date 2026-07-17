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

D2A device time protocol design:
- D2A is design-only and does not change firmware/web runtime.
- Proposed command family is D2 and does not modify E4/E5/E6.
- Opcode audit found current E4/E5/E6 usage and no active D2 conflict.
- `D2 00 SET_TIME`: 9-byte RAM-only time sync packet using UTC epoch uint32 LE, timezone offset minutes int16 LE, and flags.
- `D2 01 GET_TIME_STATUS`: 2-byte status request.
- `D2 81` status response: 15 bytes with result, state, current epoch, timezone, flags, and uptime.
- Initial persistence is RAM-only; cold boot returns time to UNSET until a new sync.
- Initial STALE threshold proposal is 24 hours.
- Firmware persistent SPI final remains unchanged.

D2B firmware time handler:
- Firmware D2 handler is implemented in `firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c`.
- `D2 00 SET_TIME` validates exact 9-byte payload, epoch range, timezone range, and reserved flags.
- `D2 01 GET_TIME_STATUS` validates exact 2-byte payload and returns deterministic status.
- Status notify is `D2 81` with 15 bytes.
- Time state is RAM-only and uses the existing software clock tick path; no new panel timer is created.
- SET_TIME always returns a status notify for consistency with current E4/E5/E6 command responses.
- D2B does not refresh the panel, does not write SPI/flash/NVDS, and does not modify E5/E6.

Do not commit `.bin` firmware images. The final `.bin` remains local under:
D:\EINK\Clock\_incoming

## D2E D2D final persistent state

Current persistent firmware image:
D:\EINK\Clock\_incoming\TASK_D2D_FINAL_PACKED_256KB.bin

SHA256:
F9C08469C1267C291EA722818E6A7451773D86C5AA271741BEF113AB2537142B

Verified D2 final state:
- D2B firmware RAM-only time handler PASS.
- D2C web device time controls PASS.
- D2D firmware-rendered clock command PASS.
- D2D persistent SPI PASS.
- SPI Burn/Verify PASS.
- Cold boot PASS.
- D2 SET_TIME PASS.
- D2 GET_TIME_STATUS PASS.
- D2 02 render PASS.
- D2 82 ACCEPTED -> RENDERING -> COMPLETE.
- BLE remains connected during render.
- Firmware renders HH:mm directly into the existing `fb_bw`.
- D2D does not use E5 transfer and does not call legacy `clock_draw`.
- No second black refresh.

Build/package facts:
- Raw canonical build size: 65164 bytes.
- Packer raw limit: 65528 bytes.
- Final packed size: 262144 bytes.
- Final packed SHA256: F9C08469C1267C291EA722818E6A7451773D86C5AA271741BEF113AB2537142B.

Runtime note:
- D2 time state is still RAM-only and is lost after reset/cold boot.
- After cold boot, use: Connect -> Gửi giờ xuống thiết bị -> Vẽ giờ từ thiết bị lên màn.
- QR and low-battery legacy visual redraw paths are disabled as an accepted firmware-size tradeoff; current HINK213 clock-panel flow is unaffected.

Next milestone:
- TASK D3A — device auto-minute clock policy/design.

## D3A auto-minute policy design

D3A is design-only and does not change firmware or web runtime.

Policy now defined:
- Time source remains the D2 RAM-only state.
- Current epoch is derived as synced epoch plus elapsed uptime.
- BLE connection is not required after SET_TIME.
- Reset/cold boot returns time to UNSET until SET_TIME.
- STALE after 24 hours still continues to run and may render.
- Minute key formula: `floor((current_epoch_utc + timezone_offset_minutes * 60) / 60)`.
- No duplicate same-minute render.
- Successful SET_TIME may render once immediately, then waits for the next minute.
- DAILY_5_MIN is the default physical-refresh cadence.
- TEST_1_MIN is reserved for physical QA and must not be the cold-boot default.
- Day rollover forces a refresh.
- Busy E5/E6/D2D states coalesce to the latest pending minute only.
- Disconnect BLE does not turn off auto clock.
- D2 02 manual render remains valid and updates last-rendered minute state.
- D3B implementation must fit within the approximate 364-byte raw headroom.

Next implementation milestone:
- TASK D3B — auto-minute scheduler implementation.

## D3C final persistent clock state

Current persistent firmware image:
D:\EINK\Clock\_incoming\TASK_D3C_FINAL_PACKED_256KB.bin

Packed SHA256:
648123BE0CC83291D9CD0DC6E5B8D3B2AD68373698954BA7F6C189C1260F44F1

Raw image:
D:\EINK\Clock\_incoming\TASK_D3C_FINAL_RAW.bin

Raw SHA256:
3A360340C943F1EAD0E9EA5AC14EF584767EF57B2AC6229A221F5CA84BCC6EBC

Verified D3C final state:
- D3B dedicated minute timer PASS.
- D3C date + lunar renderer PASS.
- Safe disconnect/re-advertise PASS.
- Minute-boundary pending race fixed.
- Lunar label is `AL`.
- SPI Burn/Verify PASS.
- Cold boot PASS.
- Two disconnected five-minute refresh boundaries PASS.
- BLE reconnect after disconnect PASS.
- No duplicate refresh.
- No second black refresh.

Build/package facts:
- Code: 40760.
- RO-data: 21624.
- RW-data: 608.
- ZI-data: 22920.
- Raw BIN: 64128 bytes.
- Packer raw limit: 65528 bytes.
- Raw headroom: 1400 bytes.
- Packed size: 262144 bytes.

Runtime note:
- Time remains RAM-only.
- After power cycle/cold boot, run SET_TIME once before relying on the device-side clock scheduler.

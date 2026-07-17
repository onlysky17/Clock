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

## D3C final closeout

D3C is now the current final clock milestone.

Verified:
- Dedicated minute timer PASS.
- Safe disconnect/re-advertise PASS.
- Minute-boundary pending race fixed.
- `AL` lunar label PASS.
- SPI Burn/Verify PASS.
- Cold boot PASS.
- Two disconnected five-minute refresh boundaries PASS.
- BLE reconnect PASS.
- No duplicate refresh.
- No second black refresh.

Current final firmware image remains local only:
D:\EINK\Clock\_incoming\TASK_D3C_FINAL_PACKED_256KB.bin

D3C final image facts:
- Packed size: 262144 bytes.
- Packed SHA256: `648123BE0CC83291D9CD0DC6E5B8D3B2AD68373698954BA7F6C189C1260F44F1`.
- Raw BIN: 64128 bytes.
- Raw SHA256: `3A360340C943F1EAD0E9EA5AC14EF584767EF57B2AC6229A221F5CA84BCC6EBC`.
- Code=40760, RO=21624, RW=608, ZI=22920.
- Raw headroom: 1400 bytes.

Important runtime note:
- Time is still RAM-only.
- After power cycle/cold boot, connect and send SET_TIME once before relying on the device-side auto clock.

Next recommended milestone:
- TASK D4A — decide next product behavior after D3D-2 last-known time persistence.

## D3D-2 final closeout

D3D-2 is now the current final SPI milestone.

Verified:
- Safe persistence sector: `0x3B000..0x3BFFF`.
- Slot A: `0x3B000`.
- Slot B: `0x3B020`.
- Sector size: `4096` bytes.
- Only valid SET_TIME writes the last-known metadata record.
- Cold boot from a valid record reports NOT_INITIALIZED + UNSET + STALE_PRESENT, with flags `0x82`.
- Stale metadata does not start the dedicated scheduler and does not auto-refresh.
- SET_TIME again returns to RUNNING and five-minute refresh PASS.
- BLE reconnect PASS.
- SPI Burn/Verify PASS.

Current final firmware image remains local only:
D:\EINK\Clock\_incoming\TASK_D3D2_FINAL_PACKED_256KB.bin

D3D-2 final image facts:
- Packed size: 262144 bytes.
- Packed SHA256: `81E19127880D60730F8DC09588A9D15A452AAC69F81EAC5ECE92D3BAD08B1C14`.
- Raw BIN: 64884 bytes.
- Raw SHA256: `0F79057E2FCC37951F855E2425A20CE08822EB83789929556954D937DFC8A843`.
- Code=41516, RO=21624, RW=608, ZI=22928.
- Raw headroom: 644 bytes.

Important runtime note:
- D3D-2 persists only last-known metadata.
- It does not claim accurate RUNNING time after cold boot.
- After cold boot, send SET_TIME once to return to RUNNING and restart the dedicated five-minute scheduler.

Recommended next milestone:
- TASK D4A — product behavior decision after stale metadata support.
- Decide whether to improve UX around STALE_PRESENT in the web UI, add user-facing stale messaging, or continue with another firmware feature.

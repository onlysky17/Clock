# CURRENT_STATE

## Canonical Current State

E1A automatic foundation is merged into `main`.

- E1A merge baseline commit: `0b5027d3945bc8514a1191a3a37576de8255e489`
- Active automation files:
  - `AGENTS.md`
  - `.codex/skills/eink-automatic/SKILL.md`
  - `tools/eink-auto-preflight.ps1`
  - `docs/agent/AUTOMATION_MODE.md`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`

Firmware milestone cuối đã đóng:

- `TASK D3E` long-run BLE/EPD lifecycle fix.
- Firmware commit: `08447bf3d142cd9aa1c1314a5beb58559f46659c`.
- Physical evidence:
  - Khoảng 90 phút RUNNING.
  - Uptime `5466` giây.
  - BLE reconnect PASS.
  - Refresh mỗi 5 phút tiếp tục đều.
  - Keil `0 errors`, `0 warnings`.
  - Code `41628`, RO-data `21624`, RW-data `608`, ZI-data `22928`.
  - Raw BIN `64996` bytes.
  - Raw headroom `532` bytes against the `65528` byte limit.
- D3D2 persistence is a passed foundation milestone, but it is not the final firmware milestone.
- D3E handoff has `VERIFY_HOME PASS`.

Product decision:

- `TASK D4A` stale recovery UX decision is approved by Owner.
- Decision: Option B, Web recovery CTA.
- When D2 status has `flags & 0x80`, web must interpret it as `STALE_PRESENT`.
- Exact warning: `Thiết bị đang giữ giờ cũ. Hãy đồng bộ giờ hiện tại để tiếp tục chạy đồng hồ.`
- Exact CTA: `Đồng bộ giờ hiện tại`
- Web must not automatically send `SET_TIME`; the user must press the CTA.
- When stale is present, lock `Vẽ giờ từ thiết bị lên màn`.
- After successful `SET_TIME`, read D2 status again, confirm stale flag is cleared, hide the warning, and re-enable render.
- Use the existing D2 `SET_TIME` flow.
- No firmware change and no new command or protocol.

Next canonical action:

- `TASK D4B` - implement web stale recovery CTA.
- D4B is not implemented and has not passed validation.
- Expected D4B scope: canonical web, web-only smoke, and closeout doc.
- BLE physical validation remains an Owner phone test at `https://onlysky17.github.io/Clock/test.html`.

## Historical Project State

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

## Historical D2E D2D persistent state

Current persistent firmware image:
D:\EINK\Clock\_incoming\TASK_D2D_FINAL_PACKED_256KB.bin

SHA256:
F9C08469C1267C291EA722818E6A7451773D86C5AA271741BEF113AB2537142B

Verified historical D2 state:
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

Historical next milestone at that time:
- TASK D3A — device auto-minute clock policy/design.

## Historical D3A auto-minute policy design

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

Historical next implementation milestone at that time:
- TASK D3B — auto-minute scheduler implementation.

## Historical D3C persistent clock state

Current persistent firmware image:
D:\EINK\Clock\_incoming\TASK_D3C_FINAL_PACKED_256KB.bin

Packed SHA256:
648123BE0CC83291D9CD0DC6E5B8D3B2AD68373698954BA7F6C189C1260F44F1

Raw image:
D:\EINK\Clock\_incoming\TASK_D3C_FINAL_RAW.bin

Raw SHA256:
3A360340C943F1EAD0E9EA5AC14EF584767EF57B2AC6229A221F5CA84BCC6EBC

Verified historical D3C state:
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

## Historical D3D2 last-known time persistence

D3D2 is a passed persistence foundation milestone. It is not the final firmware milestone; D3E is the final closed firmware milestone.

Current final firmware image remains local only:
D:\EINK\Clock\_incoming\TASK_D3D2_FINAL_PACKED_256KB.bin

Raw firmware image:
D:\EINK\Clock\_incoming\TASK_D3D2_FINAL_RAW.bin

Build/package facts:
- Code: 41516.
- RO-data: 21624.
- RW-data: 608.
- ZI-data: 22928.
- Raw BIN: 64884 bytes.
- Packer raw limit: 65528 bytes.
- Raw headroom: 644 bytes.
- Raw SHA256: 0F79057E2FCC37951F855E2425A20CE08822EB83789929556954D937DFC8A843.
- Packed size: 262144 bytes.
- Packed SHA256: 81E19127880D60730F8DC09588A9D15A452AAC69F81EAC5ECE92D3BAD08B1C14.

Persistence layout:
- Safe sector: 0x3B000..0x3BFFF.
- Sector size: 4096 bytes.
- Slot A: 0x3B000.
- Slot B: 0x3B020.
- Record size: 32 bytes.
- Record stores last-known metadata only: magic, version, sequence, epoch, timezone, flags, and CRC.
- Only a valid SET_TIME writes a record.
- Firmware does not write every minute and does not write on each refresh.

Verified:
- SPI Burn/Verify PASS.
- Cold boot PASS.
- BLE boot/connect PASS.
- BLE reconnect PASS.
- SET_TIME record write PASS.
- Cold boot status from a valid record is NOT_INITIALIZED + UNSET + STALE_PRESENT, with flags 0x82.
- Stale metadata does not start the dedicated scheduler and does not auto-refresh.
- SET_TIME again clears stale behavior, returns to RUNNING, and five-minute refresh PASS.
- D3C dedicated timer, renderer, lunar layout, safe disconnect, and minute-boundary race fix remain valid.

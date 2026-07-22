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

Current persistent firmware milestone:

- `TASK D12C` clock display preferences SPI final is CLOSED / MERGED / SPI PHYSICAL PASS.
- Implementation commit: `6a69ee2b24a8c0f77d59e490a19db5dbef49d4e2`.
- Web controls merge commit: `1ea9364`.
- Firmware merge commit: `1bbf42d22c108556ac9fbea4cd7558d895364a77`.
- D12C package commit: `1c04965217eb9130324c991f6dcc3f335e287e4f`.
- D12C package merge commit: `1107f80f822dac7fdcac73383443463997d3a625`.
- Owner physical PASS date: `2026-07-22`.
- 24/12-hour display and AM/PM in Monthly Calendar and Large Time profiles: PASS.
- Cadence 1/5/10 minutes, default five minutes, persistence across reset, immediate render, disconnected scheduling, and BLE reconnect: PASS.
- No blank first render, duplicate refresh, or second black refresh.
- Build: Code `43568`, RO `3592`, RW `552`, ZI `22936`; raw `48848` bytes; Keil 0 errors/0 warnings.
- Final raw SHA256: `845ABEEED290B361C58C86CC0B4394A2F1FBAC2B62F9AF6AE92935B11C93B188`.
- Packed BIN `262144` bytes; SHA256 `9519751A5875F58DE16EC0F0273AABB1F1F6C50A6941E65017DDCAE587412251`.
- SmartSnippets Burn/Verify, cold boot, restored preferences, both profiles, 24/12-hour modes, cadence 1/5/10, disconnected scheduler, and BLE reconnect: PASS.
- D12C supersedes D11C as the latest known-good persistent SPI baseline.

Firmware milestone cuối đã đóng:

- `TASK D11C` clock profiles persistent SPI final is CLOSED / MERGED / PHYSICAL PASS.
- D11B implementation commit: `a355d5f398e9acd9ca631dd78e69fbe930b6e58d`.
- D11B merge commit: `63d6063a33d7b4905a0114fbaa7f1aa8909001ed`.
- D11C package commit: `13cd620106dec5d3abd63897789f46bc89dfa637`.
- D11C package merge commit: `5fe026ef5203e53c8264171933b63359b7aa8c48`.
- Owner SPI Physical PASS date: `2026-07-22`.
- Build: Code `43100`, RO `3592`, RW `552`, ZI `22932`; raw `48380` bytes; Keil 0 errors/0 warnings.
- Raw SHA256: `6ACDE0EED8728C8F16B0D92F7DB14502B36069459D5D99B8FAEE5F93B4EA22CE`.
- Packed SHA256: `0A8C78B071FA5F16775F34D3643BE2644EE0274287FA82DFA3D859F113D43197`.
- Burn/Verify, cold boot, immediate render, both clock profiles, profile restore, five-minute scheduler, BLE reconnect, and no duplicate/second-black refresh: PASS.
- Package: `D:\EINK\Clock\_incoming\D11C_SPI_FINAL_2026-07-22`.
- D11C supersedes D9B as the latest known-good persistent SPI baseline.

Historical firmware milestone:

- `TASK D9B` balanced flagship layout persistent SPI final is CLOSED / MERGED / PHYSICAL PASS.
- D9A layout implementation commit: `63936eb8a9e2324fac9447319f5e789e1fdd85f7`.
- D9A merge commit: `246dab2603e4ff9c407b439dd04da9ef82b007e4`.
- D9B package commit: `0ff2eb7be98fdb5e63074a5828ca66ef8de44c55`.
- D9B package merge commit: `66625a6d0cb214e0de5184445d8d25a7833d1650`.
- Owner SPI Physical PASS date: `2026-07-22`.
- Final build evidence:
  - Keil `0 errors`, `0 warnings`.
  - Code `42644`, RO-data `3592`, RW-data `552`, ZI-data `22928`.
  - Raw BIN `47924` bytes, SHA256 `212911C6C68E8EC2060A63B8ADCE65BD44E055B6822B5B6B236AC694F326F824`.
  - Packed BIN `262144` bytes, SHA256 `51D90603363B9660CC43686E68E93FCAA9668ECB3985FF1CE292A58DB55DD8B2`.
  - Legacy font symbols absent.
- Final physical evidence:
  - SmartSnippets SPI Burn/Verify and cold boot from SPI: PASS.
  - BLE connect, D2 time sync, and render COMPLETE: PASS.
  - Firmware `D8A1` and Source ID `D8A00001`: PASS.
  - Cold-boot `STALE / PRIME / STORE`: PASS.
  - Running `TIME / TIMER / STORE`: PASS.
  - Balanced left clock pane and uniformly bold `ÂL dd/MM`: PASS.
  - Right monthly calendar remains correct: PASS.
  - BLE-disconnected five-minute scheduler: PASS.
  - BLE reconnect: PASS.
  - No blank panel, duplicate refresh, or second black refresh: PASS.
- Package: `D:\EINK\Clock\_incoming\D9B_SPI_FINAL_2026-07-22`.
- D9B is now the latest closed firmware milestone.

Product and web milestones:

- `TASK D4A` stale recovery UX decision is CLOSED and approved by Owner.
- `TASK D4B` stale recovery CTA implementation and physical validation are CLOSED/PASS.
- D4B implementation commit: `9b4cb9b58907960b3605b4cbf6a62dc39524b89f`.
- D4B merge/main commit: `ca359a025a7e854b468a381dc7c601a9be053bdc`.
- D4B smoke PASS.
- D4B automated browser 4/4 PASS: `A_STALE`, `B_NOTIFY_RACE_GUARD`, `C_FOLLOW_UP_CONFIRM`, `D_RECOVERY_ERROR`.
- Owner physical test at `https://onlysky17.github.io/Clock/test.html` PASS:
  - stale warning đúng;
  - CTA đúng;
  - render bị khóa khi stale;
  - SET_TIME recovery thành công;
  - stale flag clear;
  - warning ẩn;
  - render mở lại;
  - BLE thật PASS;
  - màn e-ink render đúng giờ PASS.
- D4B did not change firmware or protocol.
- D4B required no Keil build or flash.
- `TASK D5A` flagship daily layout is CLOSED.
- `TASK D5B` bitmap font polish is CLOSED.
- `TASK D5B-FIX1` Vietnamese glyph/layout fix is CLOSED.
- `TASK D5B-FIX2` bitmap baseline normalization is CLOSED/PASS.
- D5B-FIX2 implementation commit: `642738c0b4d4f4bbf763838fe9eb43dca7b4749b`.
- D5B-FIX2 automated smoke PASS.
- D5B-FIX2 automated browser/metrics PASS.
- Owner physical màn e-ink PASS on `19/07/2026`:
  - `THÁNG` and `ÂM` show correct accents;
  - baseline is straight;
  - solar date does not overflow the divider;
  - `HH:mm` is clear and prominent;
  - month calendar has 7 columns;
  - current day highlight is clear;
  - no clipping or stuck-together text.
- Layout is frozen; do not adjust the font again unless there is a regression.
- D5B-FIX2 is the latest closed web/layout milestone.

Next canonical action:

- `TASK D12A - Clock preference policy design` is complete on its task branch.
- Policy defines 24-hour default, optional 12-hour display, and 1/5/10-minute cadence with five minutes recommended.
- D2 `06/07/86` and persistence bytes `17..18` are reserved for implementation; D11C runtime is unchanged.
- Next implementation gate: `TASK D12B - IMPLEMENT CLOCK PREFERENCES`.

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
- D1A clock web PASS: preview uses browser local time, shows large HH:mm, shows short Vietnamese weekday/date, and `Cáº­p nháº­t giá» hiá»‡n táº¡i` only redraws/re-packs without sending BLE.
- D1B one-tap clock sync PASS: `Äá»“ng bá»™ giá» lÃªn mÃ n` draws current clock, sends E5, waits for E5 COMPLETE plus CRC match, then sends E6 and waits for E6 COMPLETE.
- D1B physical panel PASS: the panel displayed the correct real local time.
- D1C auto minute sync PASS: `Tá»± Ä‘á»“ng bá»™ khi phÃºt Ä‘á»•i` defaults OFF, first enable does not send immediately, sends only when the minute key changes, prevents overlap, and turns OFF on disconnect/error.
- D1C physical auto minute sync PASS.

Current web labels:
- Title: `TASK D1C - Auto Minute Clock Sync`
- Badge: `TASK D1C â€¢ AUTO MINUTE CLOCK SYNC â€¢ HINK213 BW`
- Heading: `250Ã—122 Clock Preview â†’ Auto E5/E6 Minute Sync`
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
- After cold boot, use: Connect -> Gá»­i giá» xuá»‘ng thiáº¿t bá»‹ -> Váº½ giá» tá»« thiáº¿t bá»‹ lÃªn mÃ n.
- QR and low-battery legacy visual redraw paths are disabled as an accepted firmware-size tradeoff; current HINK213 clock-panel flow is unaffected.

Historical next milestone at that time:
- TASK D3A â€” device auto-minute clock policy/design.

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
- TASK D3B â€” auto-minute scheduler implementation.

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

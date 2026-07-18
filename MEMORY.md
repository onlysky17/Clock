# MEMORY

## Canonical Current State

- E1A automatic foundation has been merged into `main`.
- E1A merge baseline commit: `0b5027d3945bc8514a1191a3a37576de8255e489`.
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

## Historical Milestones

## TASK C2K SPI Final Closeout

- Repo: `D:\EINK\Clock`
- Canonical web: `https://onlysky17.github.io/Clock/test.html`
- Final firmware image: `D:\EINK\Clock\_incoming\TASK_C2J_FINAL_PACKED_256KB.bin`
- Size: `262144` bytes
- SHA256: `2D6A48DE726AC02325EA7A1D657421C0ABBD7FC4FE6D652348393FA11D207F47`
- Do not commit `.bin` firmware images.

Verified hardware state:
- Firmware runs persistently from SPI after cold boot.
- SysRAM load is no longer required for the final image.
- E5 COMPLETE: payload `4000` bytes, chunks `286`, CRC match.
- E6 COMPLETE.
- C2G full-panel PASS.
- C2H one-shot latch PASS.
- C2J size trim PASS.
- SPI persistent final PASS.
- SPI Burn/Verify PASS.
- Cold boot PASS.
- Full screen is clean.
- Panel remained unchanged after 30 seconds.
- After BLE disconnect and another 30 seconds, panel still remained unchanged.
- No unintended second refresh to black.

Final geometry:
- Physical panel logical geometry: `250 x 122`
- Controller RAM geometry: `122 x 250`
- Stride: `16` bytes
- Framebuffer payload: `4000` bytes
- Do not use the old `104 x 212` golden geometry for this physical panel.

## TASK D1 Clock Web Milestone

- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`
- Current page title: `TASK D1C - Auto Minute Clock Sync`
- Current badge: `TASK D1C • AUTO MINUTE CLOCK SYNC • HINK213 BW`
- Current heading: `250×122 Clock Preview → Auto E5/E6 Minute Sync`
- The current page no longer shows `TASK C2G`, `C2G`, or `C1 TEST` labels.

Verified web clock state:
- D1A PASS: preview uses browser local time, large `HH:mm`, short Vietnamese weekday/date, and the update button only redraws/repacks without sending BLE.
- D1B PASS: `Đồng bộ giờ lên màn` draws the current clock, sends E5, waits for E5 COMPLETE with CRC match, then sends E6 and waits for E6 COMPLETE.
- D1C PASS: `Tự đồng bộ khi phút đổi` defaults OFF, first enable does not send immediately, sends only when the full minute key changes, does not overlap transfers, and turns OFF on disconnect/error.
- D1C physical auto minute sync PASS.

Stable web/firmware contract:
- Logical canvas: `250 x 122`
- Controller RAM: `122 x 250`
- Stride: `16`
- Payload: `4000` bytes
- Chunks: `286`
- E5 CRC16
- E6 one-shot refresh
- Persistent firmware still runs from SPI after cold boot, does not need SysRAM, and does not refresh black after disconnect.

Next proposed milestone:
- `TASK D2A — DEVICE TIME SYNC PROTOCOL DESIGN`
- D2A should design epoch/timezone transfer from web to firmware only.
- D2A should not implement yet, should not auto refresh device-side, and should not modify EPD.
- D2A must decide data format, persistence, drift handling, and reconnect behavior.

## TASK D2E D2D Final SPI Closeout

- Repo: `D:\EINK\Clock`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`
- Canonical source: `D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE`
- Final packed firmware image: `D:\EINK\Clock\_incoming\TASK_D2D_FINAL_PACKED_256KB.bin`
- Final packed size: `262144` bytes
- Final packed SHA256: `F9C08469C1267C291EA722818E6A7451773D86C5AA271741BEF113AB2537142B`
- Raw canonical build size: `65164` bytes
- Packer raw limit: `65528` bytes
- Golden full image: `D:\EINK\Clock\tools\packages\HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin`
- Golden SHA256: `C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452`
- Do not commit `.bin` firmware images.

Verified D2 state:
- D2B firmware RAM-only time handler PASS.
- D2C web device time controls PASS.
- D2D firmware-rendered clock command PASS.
- D2D persistent SPI PASS after Burn/Verify and cold boot.
- `D2 00 SET_TIME` PASS.
- `D2 01 GET_TIME_STATUS` PASS.
- `D2 02 RENDER_CLOCK_NOW` PASS.
- `D2 82` sequence: ACCEPTED -> RENDERING -> COMPLETE.
- BLE stays connected during D2D render.
- Firmware renders `HH:mm` directly into `fb_bw`.
- D2D does not use E5 transfer and does not call legacy `clock_draw`.
- No unintended second black refresh.

Operational notes:
- Time state is still RAM-only and is lost after reset/cold boot.
- After cold boot, run: Connect -> Gửi giờ xuống thiết bị -> Vẽ giờ từ thiết bị lên màn.
- QR and low-battery legacy visual redraw paths are disabled as an accepted firmware-size tradeoff; current HINK213 clock-panel flow is unaffected.
- Next milestone: `TASK D3A — device auto-minute clock policy/design`.

## TASK D3C Final Clock Milestone Closeout

- Repo: `D:\EINK\Clock`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`
- Canonical source: `D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE`
- Final raw firmware image: `D:\EINK\Clock\_incoming\TASK_D3C_FINAL_RAW.bin`
- Final raw size: `64128` bytes
- Final raw SHA256: `3A360340C943F1EAD0E9EA5AC14EF584767EF57B2AC6229A221F5CA84BCC6EBC`
- Final packed firmware image: `D:\EINK\Clock\_incoming\TASK_D3C_FINAL_PACKED_256KB.bin`
- Final packed size: `262144` bytes
- Final packed SHA256: `648123BE0CC83291D9CD0DC6E5B8D3B2AD68373698954BA7F6C189C1260F44F1`
- Build final: Code `40760`, RO-data `21624`, RW-data `608`, ZI-data `22920`
- Packer raw limit: `65528` bytes
- Raw headroom: `1400` bytes
- Do not commit `.bin` firmware images.

Verified D3C final state:
- D3B dedicated five-minute clock scheduler is active.
- D3C firmware clock renderer shows `HH:mm`, weekday/solar date, and lunar date with `AL dd/MM` label.
- Safe disconnect/re-advertise PASS: BLE can scan and reconnect after disconnect.
- Minute-boundary pending race fixed: initial render crossing into a non-5-minute boundary does not retrigger stale pending.
- SPI Burn/Verify PASS.
- Cold boot PASS.
- Two disconnected five-minute refresh boundaries PASS.
- No duplicate same-minute refresh.
- No unintended second black refresh.
- Time remains RAM-only: after power cycle/cold boot, run SET_TIME once again before device-side clock rendering/scheduling.

## TASK D3D2 Historical Time Persistence Closeout

- Repo: `D:\EINK\Clock`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`
- Canonical source: `D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE`
- Final raw firmware image: `D:\EINK\Clock\_incoming\TASK_D3D2_FINAL_RAW.bin`
- Final raw size: `64884` bytes
- Final raw SHA256: `0F79057E2FCC37951F855E2425A20CE08822EB83789929556954D937DFC8A843`
- Final packed firmware image: `D:\EINK\Clock\_incoming\TASK_D3D2_FINAL_PACKED_256KB.bin`
- Final packed size: `262144` bytes
- Final packed SHA256: `81E19127880D60730F8DC09588A9D15A452AAC69F81EAC5ECE92D3BAD08B1C14`
- Build final: Code `41516`, RO-data `21624`, RW-data `608`, ZI-data `22928`
- Packer raw limit: `65528` bytes
- Raw headroom: `644` bytes
- Do not commit `.bin` firmware images.

Persistence layout:
- Safe sector: `0x3B000..0x3BFFF`
- Sector size: `4096` bytes
- Slot A: `0x3B000`
- Slot B: `0x3B020`
- Record size: `32` bytes
- Record contains magic, version, sequence, epoch, timezone, flags, and CRC.
- Only valid `D2 00 SET_TIME` writes a record.
- The firmware never writes on each minute tick or each panel refresh.

Verified D3D2 historical state:
- SPI Burn/Verify PASS.
- Cold boot PASS.
- BLE boot/connect PASS.
- BLE reconnect PASS.
- `D2 SET_TIME` writes the last-known record PASS.
- Cold boot from a valid record returns `NOT_INITIALIZED` + `UNSET` with flags `0x82` (`STALE_PRESENT`).
- Stale metadata does not start the dedicated scheduler and does not auto-refresh the panel.
- A new `SET_TIME` clears stale behavior, returns to RUNNING, and five-minute refresh PASS.
- D3C renderer, lunar date, safe disconnect/re-advertise, and minute-boundary race fix remain intact.

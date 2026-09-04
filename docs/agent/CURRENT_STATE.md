# CURRENT_STATE

## Post-Merge Canonical Checkpoint — 2026-09-04 10:50 (+07)

`EINK-BW-RETAIN-MODE-CONNECT-REFRESH-001` is CLOSED / MERGED / OWNER PHYSICAL PASS.

- PR #200: `feat: retain B/W image mode across reboot`
- PR URL: `https://github.com/onlysky17/Clock/pull/200`
- Feature closeout HEAD: `dd9be4131236fded79d58ec74d045af9d160d39c`
- Merge commit / verified main: `31be1520168b342b85e183652951e703ec6db668`
- Owner acceptance remains PASS: retained image survives cold reboot; first BLE connection waits about two seconds, refreshes the same retained image exactly once, BLE remains connected/stable for 30 seconds, and same-boot reconnect does not force another refresh.
- Harness remains FROZEN.

A narrow governance follow-up is active to make critical execution rules repository-enforced instead of relying on chat memory.

Next product milestone after this governance follow-up is merged: **B/W Web user-ready**. EINK 3-color follows afterward.

---

## Current Closeout Checkpoint — 2026-09-04 10:39 (+07)

`EINK-BW-RETAIN-MODE-CONNECT-REFRESH-001` has Owner physical PASS on the
feature branch and is ready for PR / Owner merge. It is not merged yet.

Repository state for this closeout:

- Repository: `onlysky17/Clock`
- Feature branch: `task-d/eink-bw-retain-mode-connect-refresh`
- Product implementation HEAD before documentation closeout:
  `2a648010f944d358d417ff66b2b561822b305978`
- Base `main`: `3fbc49be9760d07c113f64ccf55fb358854944a9`
- Harness remains FROZEN; this task makes no Harness change.

Validated B/W retained-image behavior:

- A successfully displayed uploaded B/W frame is persisted only after the E6
  display completion path.
- Cold reboot preserves the retained uploaded image and image mode; it does not
  force a switch back to the clock.
- The first successful BLE connection after cold boot waits about two seconds,
  then performs exactly one FULL refresh of the retained image as visible
  connection feedback.
- BLE remains connected through that refresh; the prior `Connection Error`
  regression is resolved.
- Owner observed the BLE connection remain stable for at least 30 seconds after
  the retained-image refresh.
- Disconnect still holds the image.
- A same-boot reconnect succeeds normally and does not trigger a second forced
  retained-image refresh.

Validation / artifact evidence:

- Task smoke: `EINK B/W retain-mode connect-refresh smoke PASS`
- Keil target: `DA14585`
- Compiler: `V6.24`
- RAW size: `59296` bytes
- RAW SHA256:
  `58610C6BDF58064284039EF67665716FB8D21535D09B2908AD7B6D8D6261E478`
- PACKED size: `262144` bytes
- PACKED SHA256:
  `5433D7FCC8FCD7B5A1E82137126309CE2D9DD17AAA77BAF1222D68532F85E36C`
- Packer validation: `HEADER_CRC_LAYOUT_PASS`
- Payload byte match: PASS
- SmartSnippets erase/write/full verify: PASS
- Owner physical timing-fix acceptance: PASS

Owner acceptance sequence:

`send image -> disconnect holds image -> cold reboot holds retained image -> connect -> ~2 s -> one FULL refresh of same image -> BLE remains connected -> 30 s stable -> disconnect/reconnect -> no second forced refresh`

Product roadmap after this PR is merged:

1. Make the B/W Web experience user-ready.
2. Begin EINK 3-color product work.

---

## Current Canonical Checkpoint — 2026-08-21

EINK Portrait Analog v2 and Harness SHA compatibility are MERGED.

### Canonical repository state

- Repository: `onlysky17/Clock`
- Canonical workspace: `D:\EINK\Clock`
- Canonical branch: `main`
- Current merged main commit:
  `0a8387ccc75456da37f60f79561e1f403b00af42`
- PR #157 `feat: add EINK portrait analog calendar`:
  MERGED
- PR #157 actual main commit:
  `30c9efc4d2ad5e95f28147e99fc6b501358c93c5`
- PR #157 feature commit:
  `32d5add076f599483d59abc69d0faea136dcaf70`
- PR #158 `fix: make EINK SHA verification PowerShell-compatible`:
  MERGED
- PR #158 actual main commit:
  `0a8387ccc75456da37f60f79561e1f403b00af42`
- PR #158 feature commit:
  `7511f0e1882199616016e58cee5203aa863171d1`

### Current product baseline — Portrait Analog v2

Clock Classic is now a portrait analog/calendar layout.

- Logical canvas: `122 x 250`
- Rotation: `ROTATE_0`
- Analog center: `(61,72)`
- Analog radius: `51`
- Large digital `HH:MM`: removed
- `DONG HO KIM` title: removed
- Seconds hand: absent
- Solar date position: `(22,143)`
- Lunar date position: `(37,163)`
- Separator: `x=31..90`, `y=134`
- Daily sayings: `36`
- Daily saying selection: `local_day % 36`
- Saying format: ASCII-safe, maximum 3 lines, maximum 18 characters per line
- Saying baselines: `y=190/204/218`

Owner physical inspection of Portrait Analog v2: PASS.

### Refresh policy

Clock Classic prioritizes clean e-ink output.

Ordinary minutes do not open the EPD and do not trigger a display refresh.

Maintenance FULL refresh remains aligned to local wall-clock minute marks:

`00 / 05 / 10 / 15 / 20 / 25 / 30 / 35 / 40 / 45 / 50 / 55`

Therefore the analog hands update on the stable five-minute display cadence.

Weekly remains unchanged and keeps its canonical:

- `ROTATE_3`
- `UPDATE_FLY` ordinary-minute behavior

### Portrait v2 validation / device proof

- Portrait v2 validator: PASS
- `git diff --check`: PASS
- Keil ARM Compiler: `V6.24`
- build: `0 Error(s), 0 Warning(s)`
- RAW size: `54016`
- RAW SHA256:
  `D2E6CAE8BDD25A1C88DB4AB14439EBEC0BFEEB7C8F1B1175C1196C2922F52FF2`
- PACKED size: `262144`
- PACKED SHA256:
  `D987C0651DBC76507E2E8FF984BDE415ACA4B6B50D5B503546A8629E42F2494A`
- header / CRC / layout: PASS
- raw payload byte match: PASS
- fresh SPI backup: PASS
- erase + write: PASS
- full 262144-byte SPI readback: PASS
- packed/readback SHA exact match: PASS
- Owner portrait orientation/layout/date/lunar/daily-saying physical test: PASS

Validated Portrait package:

`D:\EINK\Clock\_incoming\PORTRAIT_ANALOG_V2_VALIDATED_20260821_100046`

### Rejected partial/local refresh research

The V1 through V6 partial/local FAST experiments are rejected and are not
part of the canonical product implementation.

Observed failure modes included:

- invalid/corrupt window geometry;
- differential/custom LUT darkening;
- whole-panel partial greying;
- RAM-window-only noise;
- local-gate noise caused by incomplete RAM coverage;
- local FAST region visual greying/discontinuity even with full-row RAM data.

Do not silently revive V1-V6 local refresh techniques in future product work.

### Harness v0.7 + SHA compatibility

Harness v0.7 remains the canonical build / pack / verify pipeline.

PR #158 adds PowerShell-compatible SHA256 verification through the .NET
cryptography implementation so the Harness does not depend exclusively on
`Get-FileHash`.

PR #158 validation:

- exact scope: `scripts/eink.ps1` + `tools/pack-hink.ps1`
- `git diff --check`: PASS
- prepare-test smoke: PASS
- real `scripts/eink.ps1 prepare-test`: PASS
- RAW size: `54016`
- RAW SHA256:
  `2F4C0FC751F6AEA6C08EC945F1D5181F0307BE0B2F8FF76964A7D741445DF1B9`
- PACKED size: `262144`
- PACKED SHA256:
  `DD5681CFF1AB087743009C58949E375FC1B761D6E9A4C2A8C1D1B82A0071A27D`
- header / CRC / layout: PASS
- payload byte match: PASS
- safe stop:
  `OWNER_BURN_CONFIRMATION_REQUIRED`
- destructive burn for PR #158: NOT PERFORMED

Validated SHA compatibility backup:

`D:\EINK\Clock\_incoming\EINK_HARNESS_SHA_COMPAT_VALIDATED_20260821_102535`

### Canonical execution flow

For normal firmware/layout work:

`source change -> validate -> prepare-test -> Owner burn gate -> cold boot/BLE/physical visual -> backup PASS -> commit/push/PR -> Owner merge`

Automatic PASS stages continue without repetitive Owner confirmation.

Owner gates remain:

- destructive SPI burn;
- physical/device validation where required;
- final merge.

---
## EINK Harness v0.1 Closeout

- PR #139 is merged to `main`.
- Main merge commit: `37a1860429691c941dc8b908f512d29aa7be173e`
  (`chore: add EINK harness v0.1 (#139)`).
- Original feature commit: `4afdd45c3ddcd600658ac3f8b0e74578508341b1`.
- Merged scope: exactly five files, 330 insertions:
  - `scripts/task-eink-harness-v0.1-smoke.ps1`
  - `tools/harness/artifact-policy.ps1`
  - `tools/harness/eink-profile.json`
  - `tools/harness/task-state.ps1`
  - `tools/harness/workspace-guard.ps1`
- Pre-merge engineering evidence: harness smoke PASS, `git diff --check` PASS,
  staged check PASS, and EINK AUTO PREFLIGHT PASS.
- Post-merge evidence: local `main` is synced, `HEAD == origin/main`, and the
  working tree is clean.
- This task made no firmware, web, BIN, build-output, or flash changes.
- These are Harness and repository validation facts only. They do not establish
  a physical firmware or device PASS.

## Canonical Current State

E1A automatic foundation is merged into `main`.

- E1A merge baseline commit: `0b5027d3945bc8514a1191a3a37576de8255e489`
- Active automation files:
  - `AGENTS.md`
  - `.codex/skills/eink-automatic/SKILL.md`
  - `tools/eink-auto-preflight.ps1`
  - `docs/agent/AUTOMATION_MODE.md`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`

Current final firmware milestone:

- `TASK D13D` Vietnamese weather calendar is CLOSED / MERGED / SPI PHYSICAL PASS.
- Feature commit: `3d8ad577a8d359dfc7dba7c2fbbb26212b52ff70`.
- PR #81 merge commit: `caf39289afa7bfb3c1ca3436bcc7a2dcb5390dc7`.
- SPI Burn PASS, SPI Verify PASS, and cold boot PASS.
- PRIME recovery is approximately one second.
- Weather row is shifted right to x=6 and its first character is not clipped.
- Confirmed flow: `Láº¥y thá»i tiáº¿t ngay` -> `Ăp dá»¥ng lĂªn mĂ n`.
- `Äá»“ng bá»™ giá»` alone does not display the weather row; this is the confirmed current behavior.
- Rain threshold is `>= 0.20 mm`; `0.10 mm` maps to `MĂ‚Y`.
- Final package: `D:\EINK\Clock\_incoming\D13D_FIX1_FINAL_SPI_20260723_160645`.
- Packed file: `firmware\D13D_FIX1_FINAL_PACKED_256KB.bin`.
- Packed size: `262144` bytes.
- Packed SHA256: `4C926E52B38D594BDC7E45CE30EEC51CD09D418E572987AC0B871E36E1065FF9`.
- No BIN is committed.

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

Firmware milestone cuá»‘i Ä‘Ă£ Ä‘Ă³ng:

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
  - Balanced left clock pane and uniformly bold `Ă‚L dd/MM`: PASS.
  - Right monthly calendar remains correct: PASS.
  - BLE-disconnected five-minute scheduler: PASS.
  - BLE reconnect: PASS.
  - No blank panel, duplicate refresh, or second black refresh: PASS.
- Package: `D:\EINK\Clock\_incoming\D9B_SPI_FINAL_2026-07-22`.
- D9B is now the latest closed firmware milestone.

Product and web milestones:

- `TASK D15A` through `TASK D15H` Google agenda support is CLOSED / MERGED / OWNER PASS.
- Merge lineage: D15A `b371021`, D15B `57abfcd`, D15C `91e86be`, D15D `7c15f99`,
  D15E `1b0a154`, D15F `d1b748a`, D15G `a23ed7c`, and D15H `78c4401`.
- Google Calendar access is read-only and explicitly owner-authorized.
- The web keeps at most two upcoming timed events, removes ended events, restores agenda access
  within the current tab after reload, and refreshes at most every 15 minutes while visible.
- Product Mode reports the last successful agenda update and whether automatic refresh is active
  or paused.
- Owner confirmed weather and agenda rows render together on the physical e-ink panel.
- D15D through D15H changed no firmware, BLE protocol, canonical `test.html`, or SPI package.
- `TASK D14B` connected automatic weather refresh is CLOSED / MERGED / OWNER PASS.
- Feature commit: `aa26b3cd92055bbca22b859244122a8e37b5c942`.
- PR #84 merge commit: `ba786fac946105576863ebba1385bcdf88a40cc1`.
- Automatic weather defaults OFF, starts immediately when explicitly enabled and eligible, then uses a 30-minute minimum successful interval.
- Owner confirmed the first automatic weather update displayed correctly on the panel.
- Hidden-page and BLE-disconnect states pause automation; no auto-connect or auto-reconnect is attempted.
- Unchanged `FRESH` payloads skip D2 SET and physical render; one weather retry is bounded to 60 seconds.
- Firmware, BLE protocol, `test.html`, and the physical renderer are unchanged.
- `TASK D4A` stale recovery UX decision is CLOSED and approved by Owner.
- `TASK D4B` stale recovery CTA implementation and physical validation are CLOSED/PASS.
- D4B implementation commit: `9b4cb9b58907960b3605b4cbf6a62dc39524b89f`.
- D4B merge/main commit: `ca359a025a7e854b468a381dc7c601a9be053bdc`.
- D4B smoke PASS.
- D4B automated browser 4/4 PASS: `A_STALE`, `B_NOTIFY_RACE_GUARD`, `C_FOLLOW_UP_CONFIRM`, `D_RECOVERY_ERROR`.
- Owner physical test at `https://onlysky17.github.io/Clock/test.html` PASS:
  - stale warning Ä‘Ăºng;
  - CTA Ä‘Ăºng;
  - render bá»‹ khĂ³a khi stale;
  - SET_TIME recovery thĂ nh cĂ´ng;
  - stale flag clear;
  - warning áº©n;
  - render má»Ÿ láº¡i;
  - BLE tháº­t PASS;
  - mĂ n e-ink render Ä‘Ăºng giá» PASS.
- D4B did not change firmware or protocol.
- D4B required no Keil build or flash.
- `TASK D5A` flagship daily layout is CLOSED.
- `TASK D5B` bitmap font polish is CLOSED.
- `TASK D5B-FIX1` Vietnamese glyph/layout fix is CLOSED.
- `TASK D5B-FIX2` bitmap baseline normalization is CLOSED/PASS.
- D5B-FIX2 implementation commit: `642738c0b4d4f4bbf763838fe9eb43dca7b4749b`.
- D5B-FIX2 automated smoke PASS.
- D5B-FIX2 automated browser/metrics PASS.
- Owner physical mĂ n e-ink PASS on `19/07/2026`:
  - `THĂNG` and `Ă‚M` show correct accents;
  - baseline is straight;
  - solar date does not overflow the divider;
  - `HH:mm` is clear and prominent;
  - month calendar has 7 columns;
  - current day highlight is clear;
  - no clipping or stuck-together text.
- Layout is frozen; do not adjust the font again unless there is a regression.
- D5B-FIX2 is the latest closed web/layout milestone.

Next canonical action:

- `TASK D16A - NEXT-DAY AGENDA AUTONOMY POLICY DESIGN`.
- Define what the device should show after midnight when the browser is closed or BLE is
  disconnected and no fresh Google agenda is available.
- Audit bounded expiry, day rollover, stale-row removal, reconnect refresh, and privacy behavior.
- Keep D16A design-only; do not change firmware, BLE protocol, Google OAuth, or panel rendering.

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
- D1A clock web PASS: preview uses browser local time, shows large HH:mm, shows short Vietnamese weekday/date, and `CĂ¡ÂºÂ­p nhĂ¡ÂºÂ­t giĂ¡Â»Â hiĂ¡Â»â€¡n tĂ¡ÂºÂ¡i` only redraws/re-packs without sending BLE.
- D1B one-tap clock sync PASS: `Ă„ÂĂ¡Â»â€œng bĂ¡Â»â„¢ giĂ¡Â»Â lĂƒÂªn mĂƒÂ n` draws current clock, sends E5, waits for E5 COMPLETE plus CRC match, then sends E6 and waits for E6 COMPLETE.
- D1B physical panel PASS: the panel displayed the correct real local time.
- D1C auto minute sync PASS: `TĂ¡Â»Â± Ă„â€˜Ă¡Â»â€œng bĂ¡Â»â„¢ khi phĂƒÂºt Ă„â€˜Ă¡Â»â€¢i` defaults OFF, first enable does not send immediately, sends only when the minute key changes, prevents overlap, and turns OFF on disconnect/error.
- D1C physical auto minute sync PASS.

Current web labels:
- Title: `TASK D1C - Auto Minute Clock Sync`
- Badge: `TASK D1C Ă¢â‚¬Â¢ AUTO MINUTE CLOCK SYNC Ă¢â‚¬Â¢ HINK213 BW`
- Heading: `250Ăƒâ€”122 Clock Preview Ă¢â€ â€™ Auto E5/E6 Minute Sync`
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
- After cold boot, use: Connect -> GĂ¡Â»Â­i giĂ¡Â»Â xuĂ¡Â»â€˜ng thiĂ¡ÂºÂ¿t bĂ¡Â»â€¹ -> VĂ¡ÂºÂ½ giĂ¡Â»Â tĂ¡Â»Â« thiĂ¡ÂºÂ¿t bĂ¡Â»â€¹ lĂƒÂªn mĂƒÂ n.
- QR and low-battery legacy visual redraw paths are disabled as an accepted firmware-size tradeoff; current HINK213 clock-panel flow is unaffected.

Historical next milestone at that time:
- TASK D3A Ă¢â‚¬â€ device auto-minute clock policy/design.

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
- TASK D3B Ă¢â‚¬â€ auto-minute scheduler implementation.

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

## Current D16B closeout state

TASK D16B is CLOSED and MERGED.

- PR: #96 - Handle next-day agenda rollover.
- Merge commit: 757bdd3ffa8caee335222f7919a6452671257ec6.
- D16B smoke: PASS.
- git diff --check: PASS.
- Change type: web-only.
- Firmware and BLE protocol: unchanged.
- Canonical test.html redirect: unchanged.
- BIN/build/package/flash/physical device: unchanged.

Confirmed browser-open rollover behavior:

- Detect a new local day while the page remains open.
- Clear stale previous-day agenda preview immediately.
- Run one coalesced current-day Google Calendar fetch.
- Refill only when a compatible device is already connected.
- Never auto-connect BLE.
- Preserve the firmware agenda-expiry and forced day-rollover contracts.

Planning state:

- D16A policy design is complete.
- D16B implementation is complete.
- No D16C task is defined.
- Await explicit Owner selection of the next milestone.

## Current D17A closeout state

TASK D17A is CLOSED and MERGED.

- PR: #98 - Define unified daily update flow.
- Implementation commit: `74348f3569015437940aed84b4b8118d2f574911`.
- Merge commit: `1af2f6dc22597110fdfc869446bb5ebdac0cc202`.
- Policy smoke before merge: PASS.
- Post-merge policy content validation: PASS.
- Post-merge smoke syntax validation: PASS.
- Change type: design and automated policy smoke only.

D17A defines:

- One primary Product Mode action: `Cáº­p nháº­t mĂ n hĂ¬nh hĂ´m nay`.
- Manual BLE connection only; no browser auto-connect.
- Weather, agenda, device-time, daily-context, and final-render sequencing.
- Independent degraded behavior for weather and Calendar failures.
- Previous-day agenda rejection and controlled same-day cache reuse.
- One active unified run and exactly one final visible render.
- Existing diagnostic controls preserved under Advanced.

Next canonical task:

- `TASK D17B - IMPLEMENT UNIFIED DAILY UPDATE FLOW`.

## Current D17B closeout state

TASK D17B is CLOSED, MERGED, and Owner-tested.

- PR: #100 - Add unified daily update flow.
- Feature commit: `692f76cedc90545e4b7e6f6bacdf8b7c03ddb1da`.
- Merge commit: `cad429364f72589bf2ace07a6223ad3700112e2a`.
- Post-merge smoke: PASS.
- Owner web and BLE test: PASS.
- Canonical URL: `https://onlysky17.github.io/Clock/test.html`.
- Product Mode exposes `Cáº­p nháº­t mĂ n hĂ¬nh hĂ´m nay` as the single primary daily action.
- Weather, optional Google agenda, D2 time sync, daily context, and one final render run in a guarded sequence.
- Google Calendar is skipped cleanly when not authorized; the unified flow does not force login.
- The web never auto-connects BLE and does not allow overlapping unified runs.
- No firmware, BLE protocol, `test.html`, BIN, build, pack, flash, or SPI state changed in D17B.

Next canonical task:

- `TASK D18A - AGENDA FIRMWARE SPI FINAL AUDIT`.

## Current D18B closeout state

TASK D18B is CLOSED, MERGED, and SPI PHYSICAL PASS.

- PR: #103 - Prepare agenda firmware SPI final.
- Feature commit: `cdf3d1e050b8e236af56c8f26333307880686051`.
- Merge commit: `c30b84428767550646b60a28cb5d10e13c8fc8d2`.
- Canonical URL: `https://onlysky17.github.io/Clock/test.html`.
- Keil build: Code `45232`, RO-data `3632`, RW-data `552`, ZI-data `22956`; 0 errors and 0 warnings.
- Raw BIN: `50552` bytes with `14976` bytes packer headroom.
- Raw SHA256: `586DB6FFFAD3B5121982B291E9A32032C73C1878DF199872C414E69C7C434063`.
- Packed image: `262144` bytes.
- Packed SHA256: `5790AA976BBC7A57DF63873DCE192F57C606B63A10EDBBD4FFCEE52F9D15F44A`.
- Package verify, package smoke, post-merge preflight, and post-merge smoke: PASS.
- Owner confirmed SPI Burn, SPI Verify, cold boot, unified daily update, optional weather and agenda rows, disconnected five-minute refresh, BLE reconnect, and no duplicate or second-black refresh: PASS.
- No BIN, AXF, MAP, SDK output, or `_incoming` artifact is tracked by this closeout.

Next canonical task:

- `TASK D19A - GOOGLE CALENDAR PRODUCTION AUTH READINESS AUDIT`.

## Current D19B production-auth handoff

TASK D19B web preparation is MERGED. Google production approval is not yet
verified.

- PR #106 feature commit: `07ed843422846558260146d305f35744e08e95bf`.
- PR #106 merge commit: `8b000d84a5cb9875626216246f7547d99087c96d`.
- PR #107 feature commit: `244a84c5920dc701f94d7e231aad99b88fbcde40`.
- PR #107 merge commit: `eab04d49ccb5ff8ab84d73d2b5555b5631db7201`.
- Canonical app: `https://onlysky17.github.io/Clock/test.html`.
- Public privacy policy: `https://onlysky17.github.io/Clock/privacy.html`.
- Product Mode now exposes a visible `Quyá»n riĂªng tÆ°` link outside Advanced.
- Google Calendar stays optional and requests only `calendar.readonly`.
- Users who skip Calendar retain time sync, weather, BLE, and rendering.
- No firmware, BLE protocol, `test.html`, BIN, build, pack, flash, or device
  state changed.
- Google Cloud production publishing, scope approval, and removal of the
  unverified-app warning remain Owner verification gates.

Next canonical action:

- `TASK D19C - GOOGLE CALENDAR PRODUCTION APPROVAL GATE`.

## Current D20C Product Mode usability closeout

TASK D20C is CLOSED after validating the merged D20B Product Mode on the
canonical public page.

- D20B feature commit: `2b3e92e`.
- D20B merge commit: `90c42451c595cfc62ed53ca99998824a2807ab3f`.
- Canonical URL: `https://onlysky17.github.io/Clock/test.html`.
- Product Mode shows one primary `Cáº­p nháº­t mĂ n hĂ¬nh hĂ´m nay` action.
- Clock-face selection remains directly available.
- Optional weather remains available through `TĂ³m táº¯t trong ngĂ y`.
- `Ká»¹ thuáº­t / NĂ¢ng cao` is closed by default and retains detailed progress,
  preferences, identity, preview, D2, E5, and E6 controls.
- Desktop and 360 px mobile canonical-page checks passed without horizontal
  overflow.
- Product status mapping and BLE protocol constants are unchanged.
- Google Calendar is not required by the daily-update action.
- No firmware, SDK, `test.html`, BIN, build, pack, flash, or physical-device
  change is part of D20C.

Next canonical action:

- `TASK D21A - PRODUCT MODE DAILY UPDATE RESILIENCE AUDIT`.

## Current D21 Product Mode recovery closeout

TASK D21 is CLOSED, MERGED, and automated validation is PASS.

- D21B resilience implementation merged in PR #114.
- Product Mode recovery fixes continued through PRs #116 to #123.
- Final control restoration: PR #123, merge commit
  `7c9795465f14734ccd75d2b47561231027cfd0a9`.
- The canonical page again exposes connect/disconnect, device identity and
  battery, clock-face selection and apply controls, the primary daily update,
  and an independently toggleable Advanced section.
- Advanced remains closed by default.
- Weather degradation, immediate disconnect cancellation, bounded BUSY
  recovery, one successful physical render, and later error recovery remain
  covered by the D21B smoke.
- Post-merge D21B smoke on clean `main`: PASS.
- No firmware, BLE protocol, `test.html`, BIN, Keil build, pack, flash, or
  physical-device state changed in this closeout.

Next canonical action:

- `TASK D22A - PRODUCT MODE BROWSER RUNTIME REGRESSION GATE`.

## Current D21L handoff checkpoint

The authoritative Product Mode recovery baseline is now the merged PR #124.

- Main merge commit: `b7dd5d9096afdc7007e790405ae2bf353be04694`.
- PR #124 feature commit: `cc1bc0d6f04f92ad6211bbf3f640dc2f4225ffe1`.
- Runtime restoration remains PR #123 merge commit:
  `7c9795465f14734ccd75d2b47561231027cfd0a9`.
- The complete resume contract is in
  `docs/handoff/EINK_HANDOFF_D21_PRODUCT_MODE_RECOVERY_2026-08-03.md`.
- No new firmware, web runtime, protocol, BIN, build, pack, flash, or physical
  device work is part of this handoff checkpoint.

Next canonical action remains exactly:

- `TASK D22A - PRODUCT MODE BROWSER RUNTIME REGRESSION GATE`.

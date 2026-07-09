# EINK / HINK213 CLOCK HANDOFF — 2026-07-09

## Repo

GitHub:
onlysky17/Clock

Local repo:
D:\EINK\Clock

Firmware SDK/project root:
D:\EINK\6.0.18.1182.1\projects\target_apps\ble_examples

Main firmware project currently used:
D:\EINK\6.0.18.1182.1\projects\target_apps\ble_examples\HINK213_CLOCK_P3_EPD_SMOKE

## Current Locked State

State:
HL17B docs cleanup only, after HL17A preview PASS/LIVE.

Canonical web page:
web/clock-app/hl17a-213-preview.html

Canonical URL:
https://onlysky17.github.io/Clock/web/clock-app/hl17a-213-preview.html

Scope lock:
- Target only HINK213 2.13 inch.
- Do not implement 4.2 / 5.83 / 7.5 drivers now.
- Do not use web/clock-app/eink-dev.html.
- Do not push .bin firmware images to public GitHub.
- Do not touch real EPD refresh/framebuffer while the current panel/FPC is broken.

## Hardware

Target board:
DA14585 based HINK213 / 2.13 inch e-ink BLE clock

Current real panel:
2.13 inch HINK213 only

Important:
Do not implement 4.2 / 5.83 / 7.5 drivers now. Those were only architecture references from another app.

Screen/FPC condition:
Current panel/FPC is damaged, so do not run refresh/framebuffer tests yet.

## Programming

Tool:
SmartSnippets Toolbox + J-Link v9

Flash settings:
Device: DA14585
Offset: 00000
SPI Flash size: 40000
Flow:
Erase -> Burn & Verify -> close SmartSnippets -> unplug J-Link/SWD -> power-cycle board

## Golden firmware

Golden connect-good full image:
D:\EINK\GOOD_CONNECT\HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin

Golden SHA256:
C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452

Working flash layout:
0x00000 header: 70 50
0x04000 app header: 70 51
0x4040 raw app payload
0x38000 product header: 70 52

Do not push BIN files to public GitHub.

## Known milestones

### HL11_REPRO

File:
D:\EINK\GOOD_CONNECT\HL11_REPRO_HINK213_FULL_256KB.bin

Result:
Built source reproduced working BLE/timekeeping.

Status:
PASS

### HL12

Change:
BLE name changed to EINK-HL12

Result:
BLE scan/connect worked. Web originally needed EINK/HINK filter.

Status:
PASS

### HL13B

File:
D:\EINK\GOOD_CONNECT\HL13B_CONST_DEBUG_FULL_256KB.bin

Device:
EINK-HL13

Test:
Send HEX:
F0 13

Expected notify:
13 13

Result:
Custom source patch confirmed running.

Status:
PASS

### HL14

File:
D:\EINK\GOOD_CONNECT\HL14_P3_EPD_SMOKE_FULL_256KB.bin

SHA256:
7A54CAF30C61A9FD860C31BF2255A1EFDBE6D25CFB7ECB3059E97BAA3647FF1B

Device:
EINK-HL14

Safe EPD command results:
E2 00 02 = parser OK
E2 40 02 = GPIO idle OK
E2 41 02 = SPI init OK
E2 44 01 = BUSY read, HIGH
E2 45 11 = reset pulse OK, BUSY HIGH
E2 42 02 = SPI byte transfer OK
E2 43 11 = soft reset byte OK, BUSY HIGH

Status:
PASS

Do not run refresh commands while screen/FPC is broken:
E2 03
E2 04
E2 30
E2 31
E2 50

### HL15A

Web page:
web/clock-app/hl15-213-dev.html

Result:
Web buttons + decode log worked.

Status:
PASS

### HL16A

Firmware file:
D:\EINK\GOOD_CONNECT\HL16_PANEL_DESC_FULL_256KB.bin

Purpose:
Panel descriptor command for HINK213 2.13.

Expected descriptor:
E2 D0 01 = driver id HINK213 2.13 BW
E2 D1 80 = width low 128
E2 D2 00 = width high
E2 D3 28 = height low 296
E2 D4 01 = height high
E2 D5 10 = x bytes 16

Observed:
Descriptor works.

Note:
Windows/Chrome may cache old BLE name EINK-HL14 by MAC. Descriptor result matters more than displayed cached name.

Status:
PASS

### HL16B

Stable web page:
web/clock-app/hl16-213-panel.html

Stable URL:
https://onlysky17.github.io/Clock/web/clock-app/hl16-213-panel.html

Result:
Clean web panel works:
- Connect EINK/HINK
- Read Panel Info
- Driver HINK213 2.13 BW
- Width 128
- Height 296
- X bytes 16
- Safe EPD buttons
- Clear log
- Copy log
- decoded-only mode

Status:
PASS

### HL17A

Web page:
web/clock-app/hl17a-213-preview.html

Purpose:
Web-only 2.13 framebuffer/canvas preview. This is the canonical web page after HL17A. It previews and packs bytes without sending framebuffer data to firmware.

Implemented:
- Landscape display preview, 296x128
- Raw HINK213 buffer remains 128x296
- Black/white pixel buffer
- Sample clock drawing
- Packed byte export preview
- Copy packed HEX
- Send framebuffer remains locked

Packed preview:
16 bytes per row, 296 rows, 4736 bytes total, MSB-first within each byte.

Status:
PASS / LIVE

### HL17B

Task:
Docs cleanup and state lock only.

Result:
- Canonical web page locked to web/clock-app/hl17a-213-preview.html
- HINK213 2.13-only scope restated.
- eink-dev.html explicitly not canonical.
- .bin public GitHub push remains forbidden.
- Real EPD refresh/framebuffer remains locked because panel/FPC is broken.

Status:
PASS

## BLE UUIDs

Custom service:
18424398-7cbc-11e9-8f9e-2a86e4085a59

WRITE:
2d86686a-53dc-25b3-0c4a-f0e10c8dee20

WRITE NO RESPONSE:
5a87b4ef-3bfa-76a8-e642-92933c31434f

NOTIFY:
15005991-b131-3396-014c-664c9867b917

## Current web standard

Use this URL only from now on:
https://onlysky17.github.io/Clock/web/clock-app/hl17a-213-preview.html

Local canonical file:
web/clock-app/hl17a-213-preview.html

Previous HL16 page remains historical:
web/clock-app/hl16-213-panel.html

Do not use this page; it is not canonical and may be 404:
https://onlysky17.github.io/Clock/web/clock-app/eink-dev.html

## Current packer

Reusable pack script:
D:\EINK\tools\pack-hink.ps1

Expected output format:
STATUS: READY TO FLASH
FILE: ...
DEVICE: ...
RAW_SIZE: ...
RAW_CRC32: ...
SHA256: ...
HEADER: OK

## Next recommended task

Hold firmware refresh/framebuffer work until a good 2.13 panel/FPC is available.

Goal:
- Keep target only HINK213 2.13.
- Do not test refresh on damaged panel.
- Keep web-side canvas/framebuffer preparation only.
- Later firmware can accept chunk data only, without refresh.
- Refresh/draw text only when a good 2.13 panel is available.

Future firmware goals, not HL17B:
- Add safe commands for framebuffer metadata/chunk ACK only.
- No refresh command enabled by default.

### HL18A_CANDIDATE

Task:
Web-side BLE framebuffer dry-run page and safe protocol notes.

Candidate web page:
web/clock-app/hl18a-213-dryrun.html

Purpose:
Test BLE metadata/chunk transport for the existing 4736-byte HINK213 framebuffer package without touching real EPD refresh.

Safety lock:
- HL18A uses only E3 dry-run commands.
- Firmware must ACK metadata/chunk/status/reset only.
- Firmware must not call display(), EPD_2IN13_V2_DisplayPartBaseImage(), EPD_2IN13_V2_DisplayPart(), EPD_2IN13_V2_TurnOnDisplay(), EPD_2IN13_V2_TurnOnDisplayPart(), or any real refresh function from E3 commands.
- Forbidden refresh commands remain locked: E2 03, E2 04, E2 30, E2 31, E2 50.
- Do not push .bin firmware images.

Protocol shape:
- E3 00 widthLo widthHi heightLo heightHi xBytes totalLo totalHi = dry-run metadata.
- E3 01 seqLo seqHi len xor data... = dry-run chunk.
- E3 02 page = read one dry-run status byte.
- E3 03 = reset dry-run counters.
- Notify ACKs are intentionally 3 bytes to match the existing small notify pattern: E3 80 status, E3 81 status, E3 82 value, E3 83 status.

Status:
PREPARED / NOT LIVE until committed and pushed.

Note:
Canonical production web remains HL17A until HL18A is pushed and verified:
https://onlysky17.github.io/Clock/web/clock-app/hl17a-213-preview.html

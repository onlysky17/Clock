# CURRENT EINK FW STATE

## Golden firmware

File local:
D:\EINK\GOOD_CONNECT\HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin

SHA256:
C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452

Device:
HINK213-CLOCK

MAC:
18:BC:5A:7D:5A:83

## Confirmed

- BLE advertise OK
- nRF Connect connect OK
- GitHub Pages Web Bluetooth connect OK
- WRITE OK
- WRITE NO RESPONSE OK
- Notify OK
- Time command 7 byte OK

## Web / Docs Lock

State:
HL17A preview PASS/LIVE; HL17B docs cleanup only.

Canonical web page:
web/clock-app/hl17a-213-preview.html

Canonical URL:
https://onlysky17.github.io/Clock/web/clock-app/hl17a-213-preview.html

Scope:
- Target only HINK213 2.13 inch.
- Do not use web/clock-app/eink-dev.html.
- Do not push .bin firmware images to public GitHub.
- Do not run real EPD refresh/framebuffer while the current panel/FPC is broken.

HL17A web preview:
- Display preview is landscape 296x128.
- Raw buffer remains HINK213 128x296.
- Packed output remains 16 bytes per row, 296 rows, 4736 bytes total.
- Framebuffer send remains locked.

## Time packet

Format:
YY MM DD DOW HH MM SS

Example:
1A 07 09 04 0B 08 17

Meaning:
2026-07-09, DOW 04, 11:08:23

Notify ACK:
0B 08

Meaning:
HH MM = 11:08

## Main BLE UUID

Service:
18424398-7cbc-11e9-8f9e-2a86e4085a59

Write:
2d86686a-53dc-25b3-0c4a-f0e10c8dee20

Write No Response:
5a87b4ef-3bfa-76a8-e642-92933c31434f

Notify:
15005991-b131-3396-014c-664c9867b917

Indicate/Read:
9e1547ba-c365-57b5-2947-c5e1c1e1d528

## Deprecated

Do not continue HL03-HL10 as firmware base.

New direction:
Use HINK213-CLOCK connect-good as BLE golden baseline.
Find matching source/project for HINK213-CLOCK or P2_TIMEKEEPING_PASS, then customize from that base.

## HL18A Candidate — BLE framebuffer dry-run

State:
Prepared as offline/local patch. Not live until committed and pushed.

Candidate web page:
web/clock-app/hl18a-213-dryrun.html

Canonical remains:
https://onlysky17.github.io/Clock/web/clock-app/hl17a-213-preview.html

Dry-run safety:
- Uses E3 command family only.
- Accepts metadata/chunk/status/reset for transport test only.
- Does not write framebuffer to panel.
- Does not call EPD refresh.
- Does not enable E2 03, E2 04, E2 30, E2 31, E2 50.

Expected HINK213 metadata:
- Width: 128
- Height: 296
- X bytes: 16
- Total payload: 4736 bytes

3-byte ACK map:
- E3 80 status = metadata ACK
- E3 81 status = chunk ACK
- E3 82 value = status byte response
- E3 83 status = dry-run reset ACK

Status codes:
- 00 OK
- 01 invalid size
- 02 invalid checksum
- 03 sequence error
- 04 busy/locked
- 05 unsupported

## HL18B parked state - 2026-07-09 night

Status:
SOURCE PATCHED LOCALLY / NOT BUILT / NOT FLASHED.

Local patched source:
D:\EINK\6.0.18.1182.1\projects\target_apps\ble_examples\HINK213_CLOCK_P3_EPD_SMOKE\src\user_custs1_impl.c

Backup before HL18B:
D:\EINK\6.0.18.1182.1\projects\target_apps\ble_examples\HINK213_CLOCK_P3_EPD_SMOKE\src\user_custs1_impl.c.hl18b.bak

Patch saved in repo:
docs/firmware/patches/HL18B_E3_DRYRUN_user_custs1_impl.patch

Safety:
- E3 dry-run hook is before E2 EPD command path.
- No build done.
- No flash done.
- No .bin pushed.
- No real EPD refresh tested.
- No framebuffer written to panel.
- Continue at company with Keil build + flash tools only when ready.

## HL18B validated state - 2026-07-10

Status:
PASS END-TO-END.

Validated:
- Canonical source and SDK mirror SHA256 matched.
- Keil build completed with 0 errors and 0 warnings.
- Firmware packed and flashed locally.
- BLE pair/connect passed.
- E3 metadata, chunk, status and reset ACK passed.
- Full 4736-byte framebuffer dry-run transport passed.

Safety:
- No framebuffer written to panel RAM.
- No EPD refresh called from E3.
- No refresh test performed on damaged panel/FPC.
- No .bin pushed to GitHub.

Test record:
docs/firmware/HL18B_TEST_RESULT_2026-07-10.md

## HL19A / HL19B validated state - 2026-07-10

Status:
PASS END-TO-END.

HL19A:
- Clean 4736-byte BLE dry-run transfer passed.
- Disconnect/reconnect Query + Resume passed.
- Duplicate and skipped sequence guards passed.
- Mismatched chunk-size resume guard passed.
- Final state: 339 chunks, 4736 bytes, XOR F0.

HL19B:
- Deterministic lost-ACK simulation passed.
- Browser deliberately ignored a chunk ACK.
- Status-query recovery detected the accepted chunk and continued.
- Captured run recovered 2 ACK losses.
- Final state remained 339 chunks, 4736 bytes, XOR F0.

Safety:
- Firmware remained HL18B.
- No firmware rebuild/reflash for HL19A/HL19B.
- No panel RAM write.
- No EPD refresh.
- No .bin pushed.
- New spare board remained untouched.

Validation record:
docs/firmware/HL19_VALIDATION_RESULT_2026-07-10.md

Next:
HL20A firmware refresh kill-switch on the old board only.

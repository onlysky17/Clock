# HL20A REFRESH KILL-SWITCH VALIDATION — 2026-07-10

## Overall result

Status: PASS END-TO-END

Target:
- HINK213 2.13 inch only.
- Old test board only.
- New spare board remained untouched.

## Source and build

Canonical source SHA256:

`F76A308B86FDC2E2BA2EECA7F3845CAE56AC953307C07E8BCC24F69B8B37E334`

Canonical source and SDK mirror matched.

Keil rebuild:

- Program Size: Code=30736
- RO-data=3240
- RW-data=4
- ZI-data=8368
- 0 Error(s)
- 0 Warning(s)

## Runtime validation

Lock signature:

`E2 E0 00 00 00 00 00 -> E2 E0 A1`

Panel descriptor remained available:

`01 80 00 28 01 10`

Decoded:
- Driver ID: HINK213 2.13 BW
- Width: 128
- Height: 296
- X bytes: 16

Blocked panel-job commands:
- `02`
- `03`
- `04`
- `30` through `37`
- `50` through `54`

All blocked commands returned:

`E2 <subcommand> F0`

Final runtime result:

`PASS: ALL PANEL JOBS BLOCKED`

## Regression

- HL18B/HL19 E3 framebuffer dry-run remained functional.
- Descriptor D0 through D5 remained functional.
- BLE connectivity remained functional.
- No framebuffer was written to panel RAM.
- No EPD refresh was executed.
- No firmware `.bin` was pushed to GitHub.

## Canonical web

https://onlysky17.github.io/Clock/web/clock-app/hl20a-refresh-lock.html

## Safety state after HL20A

- Refresh-capable E2 commands are blocked at firmware dispatch.
- E3 dry-run remains available.
- The old damaged-panel board remains the active test board.
- The new spare board remains untouched.

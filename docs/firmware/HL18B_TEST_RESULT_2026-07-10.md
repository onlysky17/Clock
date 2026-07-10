# HL18B E3 FRAMEBUFFER DRY-RUN TEST RESULT — 2026-07-10

## Result

Status: PASS END-TO-END

## Source / Build

- Canonical source:
  firmware/active/HINK213_CLOCK_P3_EPD_SMOKE/src/user_custs1_impl.c
- Canonical source SHA256:
  8F3673B452478C64B55BCF7DD59D8D83EFB2CF6F976199690F87C5E8EFDA274C
- Canonical source and SDK mirror SHA256 matched.
- Keil build:
  0 Error(s), 0 Warning(s)
- Program size:
  Code=31860
  RO-data=3240
  RW-data=4
  ZI-data=8376

## Device Test

- Firmware packed and flashed locally.
- BLE pair/connect: PASS.
- E3 metadata ACK: PASS.
- E3 chunk ACK: PASS.
- E3 status/counter: PASS.
- E3 dry-run reset: PASS.
- Full packed payload dry-run: PASS.
- Packed framebuffer size: 4736 bytes.

## Safety Confirmation

- No framebuffer was written to panel RAM.
- No EPD refresh was called from the E3 path.
- No damaged panel/FPC refresh test was performed.
- No firmware .bin was pushed to GitHub.
- Target remains HINK213 2.13 inch only.

## Canonical Web

https://onlysky17.github.io/Clock/web/clock-app/hl18a-213-dryrun.html

## Git Milestone

Canonical HL18B source commit:
124ba0f — firmware: add HL18B E3 dry-run ACK

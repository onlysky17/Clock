# Clock

DA14585 2.13 inch E-Ink clock firmware and Web Bluetooth control workspace.

This repo is the clean sync copy from `D:\EINK`, made so the firmware can be continued on another machine without carrying raw board backups, donor dumps, or large archive files.

## Current Target

This workspace is currently focused on the DA14585 HINK213 2.13 inch e-ink BLE clock only.

Current milestones:

- HL14 EPD smoke: PASS
- HL16 panel descriptor: PASS
- HL16 web panel: PASS
- HL17A web/canvas preview: READY FOR WEB TEST

Do not work on 4.2 / 5.83 / 7.5 inch panels in this repo state.
Do not push `.bin` firmware images to public GitHub.
Do not run refresh/framebuffer tests while the current screen/FPC is damaged.

## Main Firmware

Open this Keil project:

```text
D:\EINK\6.0.18.1182.1\projects\target_apps\ble_examples\HINK213_CLOCK_P3_EPD_SMOKE
```

Current handoff:

```text
docs\handoff\EINK_HANDOFF_2026-07-09.md
```

## Flash Notes

Read these before burning a board:

- `docs\EINK_VIET_FLASH_CHECKLIST.md`
- `docs\FW_V2_BUILD_STEPS.md`

SmartSnippets/J-Link SPI pins used by this board:

```text
SPI_CLK: P0_0
SPI_EN : P0_3
SPI_DI : P0_5
SPI_DO : P0_6
```

Use offset `00000`, SPI flash size `40000`, and read/backup before erase or burn.

## Web Tool

Canonical Web Bluetooth page:

```text
https://onlysky17.github.io/Clock/web/clock-app/hl16-213-panel.html
```

Use `web\clock-app\hl16-213-panel.html` as the current page source.
Do not use `eink-dev.html`; it is not the canonical page.

## Not Tracked

Board backups, donor full-flash dumps, raw archives, and Keil build outputs are intentionally excluded from Git.

# Clock

DA14585 2.13 inch E-Ink clock firmware workspace.

This repo is the clean sync copy from `D:\EINK`, made so the firmware can be continued on another machine without carrying raw board backups, donor dumps, or large archive files.

## Main Firmware

Open this Keil project:

```text
firmware\FWV2\eink_viet_custom_fw\projects\target_apps\ble_examples\ble_app_ota\Keil_5\ble_app_ota.uvprojx
```

Current custom branch:

- BLE name: `EINK-VIET`
- Source root: `firmware\FWV2\eink_viet_custom_fw`
- Packaged test image: `firmware\FWV2\eink_viet_custom_pack_v2\fw_custom_spi_v2_256KB.bin`

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

The current web BLE control page is under:

```text
web\github_pages_eink_clock_v39
```

## Not Tracked

Board backups, donor full-flash dumps, raw archives, and Keil build outputs are intentionally excluded from Git.

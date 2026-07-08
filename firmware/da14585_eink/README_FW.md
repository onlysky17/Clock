# DA14585 E-Ink 2.13 Firmware

## Trạng thái hiện tại

- Firmware custom boot OK
- BLE name: EINK-VIET
- Nạp qua J-Link SWD bằng SmartSnippets Toolbox OK
- Không nạp raw Keil bin trực tiếp vào SPI flash

## Pin E-Paper

| Tín hiệu | Pin |
|---|---|
| BUSY | P2_0 |
| CS | P2_1 |
| RST | P0_7 |
| DC | P0_5 |
| SCLK | P0_0 |
| MOSI/SDI | P0_6 |
| Power comment | P2_3 |

## Quy trình build

1. Mở source bằng Keil MDK.
2. Build target DA14585.
3. Lấy raw bin `ble_app_ota_585_29.bin`.
4. Đóng gói thành SPI boot image `fw_custom_spi.bin`.
5. Nạp bằng SmartSnippets Toolbox.

## Quy trình nạp

SmartSnippets Toolbox:

- Device: DA14585-586
- Interface: JTAG/SWD
- Adapter: J-Link
- SPI Flash size: `40000`
- Offset: `00000`
- Action: Erase -> Burn & Verify -> Power-cycle

## Cấu trúc SPI image đúng

- `0x00000`: secondary bootloader, header `70 50`
- `0x02000`: app image 1, header `70 51`
- `0x14000`: app image 2, header `70 51`
- `0x38000`: product header, header `70 52`

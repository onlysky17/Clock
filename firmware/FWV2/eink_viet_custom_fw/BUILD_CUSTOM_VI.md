# EINK Vietnamese Custom Firmware

Day la fork source sach tu goi DA14585 2.13 inch goc TQ, giu lai driver man E-Ink, pinout va BLE protocol de build firmware moi tuy chinh.

## Da tuy chinh san

- Device name BLE: `EINK-VIET`.
- Man clock mac dinh doi `星期...` sang `Thu 2..Thu 7/CN` dang ASCII.
- Giu nguyen BLE UUID va command protocol de app/host cu van gui anh duoc.

## Pinout E-Ink 2.13 inch dang dung

| Tin hieu | DA14585 pin |
|---|---|
| EPD BUSY | P2_0 |
| EPD CS | P2_1 |
| EPD RST | P0_7 |
| EPD DC | P0_5 |
| EPD SCLK | P0_0 |
| EPD SDI/MOSI | P0_6 |
| EPD POWER | P2_3, theo comment source goc |

SPI flash ngoai OTA/SUOTA:

| Tin hieu | DA14585 pin |
|---|---|
| SPI flash CS | P0_3 |
| SPI flash CLK | P0_0 |
| SPI flash DO/MOSI | P0_6 |
| SPI flash DI/MISO | P0_5 |

Luu y: EPD DC va SPI flash MISO cung P0_5 theo source goc. Firmware goc van chay theo cach cau hinh lai pad/chuc nang khi can truy cap flash hoac EPD.

## Build bang Keil uVision

1. Mo file:

```text
projects/target_apps/ble_examples/ble_app_ota/Keil_5/ble_app_ota.uvprojx
```

2. Chon target `DA14585`.
3. Dung ARM Compiler 6 / ARMCLANG. Project goc khai bao `V6.16`.
4. Build target. Post-build trong project se goi:

```text
fromelf --bincombined --output=".\out_DA14585\Objects\@L.bin" "!L"
```

5. File bin sau build nam trong:

```text
projects/target_apps/ble_examples/ble_app_ota/Keil_5/out_DA14585/Objects/
```

## Nap bang J-Link/SWD

DA14585 khong co internal flash, nen file `.bin` sau build phai ghi vao SPI flash ngoai bang SmartSnippets Toolbox/CLI hoac DA14585 flash programmer qua J-Link. Khong dung `loadbin ..., 0x00000000` truc tiep neu J-Link khong co external flash loader.

Quy trinh:

1. Noi GND, SWCLK, SWDIO, RESET neu co.
2. SmartSnippets Toolbox: chon `DA14585-586`, interface `JTAG/SWD`, adapter `J-Link`.
3. Burn file `.bin` output vao SPI flash.
4. Reset/power-cycle board.

## Protocol BLE giu tu source goc

Service 1:

- `0x02 <offset_hi> <offset_lo>`: set vi tri ghi buffer.
- `0x03 0xff <offset_hi> <offset_lo> <data...>`: ghi chunk anh vao `epd_buffer`.
- `0x01`: tinh CRC va day buffer ra man.
- `0xAA`: save image header/buffer vao flash, hien dang comment phan ghi trong source goc.
- `0xAB`: reset.

Service 2:

- `0xDD <unix_be_u32>`: set thoi gian.
- `0xE2`: render lai man clock va refresh full.
- `0xAA`: reset.

## Huong tuy chinh tiep

- Neu can tieng Viet co dau tren man clock, them glyph UTF-8 vao `src/Fonts/font16CN.c` va goi `EPD_DrawUTF8(..., EPD_FontUTF8_16x16, ...)`.
- Neu can layout gia, logo, QR, barcode, nen viet module render rieng thay vi nhan toan bo bitmap qua BLE.
- Neu can app moi, co the giu UUID hien tai cho tuong thich hoac doi UUID trong `src/custom_profile/user_custs1_def.h`.

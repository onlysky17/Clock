# EINK-VIET flash checklist

Ngay 2026-07-08: da kiem tra goi `FWV2.rar` va nhanh custom trong `D:\EINK\FWV2`.

## Trang thai hien tai

- Source can tiep tuc sua: `D:\EINK\FWV2\eink_viet_custom_fw`
- Project Keil: `D:\EINK\FWV2\eink_viet_custom_fw\projects\target_apps\ble_examples\ble_app_ota\Keil_5\ble_app_ota.uvprojx`
- BLE name da doi tai `src\config\user_config.h`: `EINK-VIET`
- Build artifact hien co: `out_DA14585\Objects\ble_app_ota_585_29.bin`
- Build gan nhat: 0 Error(s), 12 Warning(s)

## File nen nap thu

Uu tien nap file full 256KB da pad:

```text
D:\EINK\FWV2\eink_viet_custom_pack_v2\fw_custom_spi_v2_256KB.bin
```

Thong tin file:

```text
Size   : 262144 bytes
SHA256 : 4E18700EE5956AD8EDD11290BAA1802E7CDF351E6895BC11F2B20D310A749C6A
0x00000: 70 50
0x02000: 70 51
0x14000: 70 51
0x38000: 70 52
Tail from 0x38018: FF
```

File goc trong pack van giu nguyen:

```text
D:\EINK\FWV2\eink_viet_custom_pack_v2\fw_custom_spi_v2.bin
Size   : 229400 bytes
SHA256 : 5EE1BDD1A3508C28F668CD823B120D1899F8E64E1FD0D58B430F9F58554D5121
```

Khong nap truc tiep raw Keil bin `ble_app_ota_585_29.bin` nhu full flash, vi DA14585 boot tu SPI flash ngoai can dung layout co header `pP/pQ/pR`.

## Day J-Link/SWD

- J-Link GND -> board GND
- J-Link SWDIO -> board SWDIO
- J-Link SWCLK -> board SWCLK
- J-Link VTref/pin 1 -> board VCC/BAT 3.0V den 3.3V
- RESET neu co thi noi them, khong bat buoc
- Khong noi pin 19/5V cua J-Link vao board

Board can nguon rieng 3.0V den 3.3V on dinh. Neu pin coin cell duoi 3V thi khong nen nap; thao/cach ly pin neu cap nguon ngoai de tranh back-feed.

## Truoc khi burn

1. Chi dung 1 board test.
2. SmartSnippets Toolbox: chon `DA14585-586`, interface `JTAG/SWD`, adapter `J-Link`.
3. Mo SPI Flash Programmer.
4. Read full SPI flash tu offset `00000`, size `40000`.
5. Luu backup voi ten kieu:

```text
D:\EINK\BACKUP_BEFORE_EINK_VIET\board01_before_eink_viet_20260708.bin
```

6. Neu doc lai 2 lan thi hash phai giong nhau moi burn.

## Burn

Trong SPI Flash Programmer:

- Offset in SPI Flash memory: `00000`
- SPI Flash memory size: `40000`
- Load file: `D:\EINK\FWV2\eink_viet_custom_pack_v2\fw_custom_spi_v2_256KB.bin`
- Erase
- Burn & Verify
- Khong dung OTP
- Khong dung lenh J-Link `loadbin ..., 0x00000000` neu khong co external SPI flash loader

Sau khi verify pass: tat nguon, cap lai nguon board.

## Test sau khi nap

1. Quet BLE, ten mong doi: `EINK-VIET`.
2. Connect bang app/web cu.
3. Sync gio bang command `DD <unix_be_u32>`.
4. Goi `E2` de render/refresh clock.
5. Gui thu mot anh nho bang protocol cu neu can test EPD.

## Neu fail

- Burn fail: kiem tra nguon 3.0V den 3.3V, GND chung, SWDIO/SWCLK, giam toc J-Link xuong 1000 kHz hoac 500 kHz.
- Burn pass nhung khong boot: restore donor Viet:

```text
D:\EINK\VN\DA14585_VIET_DONOR_FULL_CLONE_READY_256KB.bin
```

- Co BLE nhung man khong refresh: tam dung, chup log/trieu chung roi sua source `eink_viet_custom_fw`; khong nap hang loat.

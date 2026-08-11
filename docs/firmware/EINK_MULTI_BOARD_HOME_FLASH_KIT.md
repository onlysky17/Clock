# EINK Multi-board Home Flash Kit v1

## Muc tieu

Bo nay giup chuan bi va dong goi cung mot firmware cho nhieu board cung cau hinh. Script chi tu dong hoa cac buoc repo da chung minh an toan: kiem tra moi truong va pack anh SPI. Burn, SPI Verify, cold boot, BLE va kiem tra man e-ink van la `OWNER_GATE`.

Khong co lenh nao trong kit tu dong mo GUI, burn board, xoa flash, ghi OTP hoac tuyen bo ket qua vat ly.

## Hop dong tuong thich board

Chi tai su dung cung mot packed image khi tung board deu giong nhau o tat ca muc sau:

- MCU/target: DA14585-586, Keil target `DA14585`.
- Man: HINK213 e-ink 2.13 inch cung controller, do phan giai va profile.
- Cung wiring/pin mapping, nguon va revision phan cung.
- External SPI flash 256KB va cung layout:
  - image header `0x04000`;
  - firmware payload `0x04040`;
  - product/image table `0x38000`;
  - config/panel sectors theo golden template hien hanh.
- Khong co du lieu hieu chinh hoac danh tinh rieng tung board can duoc giu lai.

Repo khong chung minh moi board ngoai thuc te deu dap ung cac dieu tren. Truoc khi nhan ban hang loat, Owner phai backup full SPI board dau tien, xac nhan revision/panel/pin va so sanh cac vung config.

## Thanh phan va phu thuoc

### A. Git tracked

- Canonical source: `D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE`
- Bootstrap: `D:\EINK\Clock\tools\bootstrap-hink213-clock22-base.ps1`
- Packer: `D:\EINK\Clock\tools\pack-hink.ps1`
- Harness profile/policy: `D:\EINK\Clock\tools\harness\eink-profile.json`, `artifact-policy.ps1`
- Golden manifest: `D:\EINK\Clock\tools\HINK_GOLDEN_TEMPLATE_MANIFEST.json`
- Kit entry point: `D:\EINK\Clock\scripts\eink-home-flash.ps1`

### B. Local/package-only, khong Git track

- Golden template:
  `D:\EINK\Clock\tools\packages\HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin`
- Expected size: `262144` bytes.
- Expected SHA256:
  `C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452`
- Raw BIN, AXF, packed BIN, backup SPI va manifest cua tung dot nap.

### C. External tren may nha

- Windows PowerShell 5.1.
- Git.
- DA14585 SDK `D:\EINK\DA14585_SDK_6.0.22.1401`.
- Keil uVision 5 va ARMCLANG 6.24.
- SmartSnippets Toolbox, J-Link driver va programmer phu hop.

Do bootstrap hien hanh dung duong dan canonical co dinh, may nha can dat repo va SDK dung cac duong dan tren.

## Kiem tra moi truong

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "D:\EINK\Clock\scripts\eink-home-flash.ps1" `
  -Mode VerifyEnv
```

Ket qua tu dong mong doi: `ENVIRONMENT PASS`. SmartSnippets/J-Link duoc bao rieng la `OWNER_GATE` vi repo chua co CLI burn an toan da duoc chung minh.

## Sync va build

Sync canonical source sang SDK, khong hand-copy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "D:\EINK\Clock\tools\bootstrap-hink213-clock22-base.ps1"
```

Mo project Keil:

```text
D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\ble_app_peripheral.uvprojx
```

Chon target `DA14585` va Rebuild trong Keil. Repo chua chung minh mot lenh Keil CLI canonical, nen build van la `OWNER_GATE`.

Raw output du kien:

```text
D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\out_DA14585\Objects\ble_app_peripheral_585.bin
```

## Pack

Lenh truc tiep canonical:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "D:\EINK\Clock\tools\pack-hink.ps1" `
  -Raw "<ABSOLUTE_RAW_BIN>" `
  -Out "<ABSOLUTE_PACKED_256KB_BIN>" `
  -Name "HINK213-CLOCK"
```

Hoac dung entry point cua kit:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "D:\EINK\Clock\scripts\eink-home-flash.ps1" `
  -Mode Pack `
  -RawBinPath "<ABSOLUTE_RAW_BIN>" `
  -OutputPath "<ABSOLUTE_PACKED_256KB_BIN>" `
  -BleName "HINK213-CLOCK"
```

Kit kiem raw toi da `65528` bytes, packed dung `262144` bytes va in SHA256 cua raw/template/packed.

## Burn va verify tung board

Repo chi chung minh workflow SmartSnippets Toolbox, khong co CLI burn/verify headless an toan. Moi board phai lam thu cong:

1. Ket noi GND, SWDIO, SWCLK va VTref 3.0-3.3V; chon `DA14585-586`, `JTAG/SWD`, J-Link.
2. Vao SPI Flash Programmer.
3. Board dau tien: Read full SPI offset `00000`, size `40000` hai lan; luu backup va xac nhan hai SHA256 khop nhau.
4. Chon packed image 256KB, offset `00000`, size `40000`.
5. Erase, Burn & Verify. Khong ghi OTP.
6. Ghi lai ket qua `BURN PASS` va `SPI VERIFY PASS` chi khi SmartSnippets bao thanh cong.
7. Ngat programmer, power-cycle board.
8. Kiem BLE scan/connect tren dien thoai va trang canonical `https://onlysky17.github.io/Clock/test.html`.
9. SET_TIME/cap nhat man va kiem tra hinh e-ink thuc te.

Lap lai dung chuoi tren cho Board 2 den Board N. Khong bo qua verify va power-cycle giua cac board.

## Bang gate

- `ENVIRONMENT PASS`: script kiem tra duoc repo, SDK, Keil, compiler, golden template va hash.
- `PACK PASS`: packer va artifact policy dat.
- `BURN PASS`: Owner xac nhan tren SmartSnippets cho tung board.
- `SPI VERIFY PASS`: Owner xac nhan verify cho tung board.
- `COLD BOOT PASS`: Owner power-cycle va board khoi dong.
- `BLE PASS`: dien thoai scan/connect va luong BLE hoat dong.
- `VISUAL PASS`: noi dung e-ink dung, khong duplicate/black refresh bat thuong.

Khong suy dien gate sau tu gate truoc. Packed image thanh cong khong phai bang chung board da burn hoac da pass vat ly.

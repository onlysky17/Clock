# FW v2 Build Steps — DA14585 E-Ink THP Source

Mục tiêu: build firmware v2 từ source THP, đóng gói thành full 256KB `.bin`, flash thử 1 board rác.

## 0. Nguyên tắc
- Không làm trên 50 màn.
- Chỉ dùng 1 board test/rác.
- Nếu v2 fail, restore lại donor Việt:
  `D:\EINK\VN\DA14585_VIET_DONOR_FULL_CLONE_READY_256KB.bin`
- Khi flash file full 256KB:
  - Do not modify
  - Bootable unchecked
  - Offset `0x00000`
  - SPI size `40000`

## 1. Chuẩn bị folder
Tạo folder không dấu, không tiếng Trung:

`D:\EINK\FWV2\`

Copy/extract source vào:

`D:\EINK\FWV2\da14585_213_hema\`

Bên trong phải thấy:

`projects\target_apps\ble_examples\ble_app_ota\Keil_5\ble_app_ota.uvprojx`

Tránh build trực tiếp trong path có chữ Trung/space dài.

## 2. Tool cần có
- Keil uVision 5 / MDK-ARM
- ARM Compiler 5 / ARMCC5
- SmartSnippets Toolbox đã dùng nạp donor
- Python hoặc PowerShell để pad bin 256KB

Nếu Keil báo thiếu compiler, mở:
`Project > Manage > Project Items > Folders/Extensions`
hoặc cài thêm ARM Compiler 5.06.

## 3. Build source gốc trước
Mở:

`D:\EINK\FWV2\da14585_213_hema\projects\target_apps\ble_examples\ble_app_ota\Keil_5\ble_app_ota.uvprojx`

Trong Keil:
1. Chọn target: `DA14585`
2. Không chọn DA14586/DA14531.
3. Bấm `Rebuild`.

Output mong đợi:

`...\Keil_5\out_DA14585\Objects\ble_app_ota_585_29.bin`

Nếu không thấy `.bin`, vào:
`Options for Target > User`
bật post-build:

`fromelf --bincombined --output=".\out_DA14585\Objects\@L.bin" "!L"`

## 4. Pad output thành full 256KB
Chạy PowerShell:

```powershell
cd D:\EINK\FWV2
.\pad_to_256kb.ps1 `
  -InBin "D:\EINK\FWV2\da14585_213_hema\projects\target_apps\ble_examples\ble_app_ota\Keil_5\out_DA14585\Objects\ble_app_ota_585_29.bin" `
  -OutBin "D:\EINK\FWV2\fw_v2_original_256KB.bin"
```

File output phải đúng:
- Size `262144`
- Phần dư pad bằng `0xFF`

## 5. Flash thử source gốc
SmartSnippets:
- DA14585
- UART/SPI
- SPI Flash Programmer
- File: `D:\EINK\FWV2\fw_v2_original_256KB.bin`
- Offset: `0x00000`
- SPI size: `40000`
- Do not modify
- Bootable unchecked
- Burn only

Power-cycle rồi xem:
- Board boot không?
- BLE có hiện không?
- Màn có refresh không?

Nếu source gốc build/flash chưa boot thì chưa patch v2. Lúc đó phải xử lý image/build format trước.

## 6. Áp patch v2 candidate
Backup file gốc:

`...\src\user_custs1_impl.c`

Copy file:

`user_custs1_impl_v2_candidate.c`

đè vào:

`D:\EINK\FWV2\da14585_213_hema\projects\target_apps\ble_examples\ble_app_ota\src\user_custs1_impl.c`

Sau đó Rebuild target `DA14585`.

## 7. Pad v2
```powershell
cd D:\EINK\FWV2
.\pad_to_256kb.ps1 `
  -InBin "D:\EINK\FWV2\da14585_213_hema\projects\target_apps\ble_examples\ble_app_ota\Keil_5\out_DA14585\Objects\ble_app_ota_585_29.bin" `
  -OutBin "D:\EINK\FWV2\fw_v2_candidate_256KB.bin"
```

## 8. Flash v2 candidate
SmartSnippets setting y chang:
- Do not modify
- Bootable unchecked
- Offset `0x00000`
- SPI size `40000`
- Burn only

Power-cycle.

## 9. Test bằng web Smart Hub
Mở `eink_control_smart_hub_v13.html`.

Test thứ tự:
1. Connect nhanh.
2. RESCUE.
3. Đồng hồ.
4. Lịch.
5. Countdown sample.

Command cần pass:
- `DD...` sync giờ
- `E1 02` hoặc `E102`
- `E1 01` hoặc `E101`
- `E2`
- `D6 ...`

## 10. Nếu v2 fail
Đừng debug lung tung. Ghi lỗi theo nhóm:

### A. Burn không được
- Kiểm tra file size 262144
- Kiểm tra Do not modify / Bootable unchecked
- Kiểm tra VCC/GND/UART

### B. Burn pass nhưng không boot
- Có thể output image format chưa đúng
- Restore donor Việt 256KB để cứu board
- So lại first bytes của bin

### C. Boot BLE có nhưng màn không hiện
- EPD init/panel/rotation khác
- Sửa EPD driver/layout sau

### D. Màn hiện nhưng web không điều khiển được
- BLE service/characteristic hoặc command handler chưa giống donor
- Sửa `user_custs1_def.*` và `user_custs1_impl.c`

## 11. Restore donor Việt
Nếu cần restore:

SmartSnippets:
- File: `D:\EINK\VN\DA14585_VIET_DONOR_FULL_CLONE_READY_256KB.bin`
- Offset `0x00000`
- SPI size `40000`
- Do not modify
- Bootable unchecked
- Burn only

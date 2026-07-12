$ErrorActionPreference = "Stop"

$proj = "D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE"

$required = @(
  "$proj\Keil_5\ble_app_peripheral.uvprojx",
  "$proj\src\user_peripheral.c",
  "$proj\src\user_custs1_impl.c",
  "$proj\src\epd\epd.c",
  "$proj\src\epd\epd_hw.c",
  "$proj\src\epd\epd_gui.c",
  "$proj\src\epd\epd.h"
)

foreach ($p in $required) {
  if (-not (Test-Path $p)) {
    throw "Missing: $p"
  }
}

Write-Host "VERIFY PASS: HINK213_CLOCK_22_BASE files exist." -ForegroundColor Green
Write-Host "Open in Keil:"
Write-Host "$proj\Keil_5\ble_app_peripheral.uvprojx"

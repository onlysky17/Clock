$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$src = Join-Path $repoRoot "firmware\active\HINK213_CLOCK_22_BASE"
$dst = "D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE"

if (-not (Test-Path $src)) {
  throw "Missing repo project source: $src"
}

if (-not (Test-Path "D:\EINK\DA14585_SDK_6.0.22.1401")) {
  throw "Missing SDK 6.0.22.1401. Install/copy SDK to D:\EINK\DA14585_SDK_6.0.22.1401 first."
}

New-Item -ItemType Directory -Force -Path $dst | Out-Null
robocopy $src $dst /MIR /XD .git /XF *.bak *.uvguix.* | Out-Host

Write-Host ""
Write-Host "BOOTSTRAP DONE:" -ForegroundColor Green
Write-Host $dst
Write-Host "Open in Keil:"
Write-Host "$dst\Keil_5\ble_app_peripheral.uvprojx"

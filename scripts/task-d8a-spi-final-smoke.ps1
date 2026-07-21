[CmdletBinding()]
param(
    [string]$PackagePath = "D:\EINK\Clock\_incoming\D8A_SPI_FINAL_2026-07-21"
)

$ErrorActionPreference = "Stop"
$RepoRoot = (git rev-parse --show-toplevel).Trim() -replace "\\", "/"
if ($RepoRoot -ne "D:/EINK/Clock") { throw "Wrong repo: $RepoRoot" }
$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path

$Required = @(
    "D8A_RAW_ble_app_peripheral_585.bin",
    "D8A_ble_app_peripheral_585.axf",
    "D8A_FINAL_PACKED_256KB.bin",
    "D8A_GOLDEN_BASE_256KB.bin",
    "D8A_MANIFEST_SHA256.txt",
    "verify-d8a-package.ps1",
    "README_D8A_SPI_BURN.txt"
)
foreach ($Name in $Required) {
    if (-not (Test-Path -LiteralPath (Join-Path $PackagePath $Name) -PathType Leaf)) { throw "Missing $Name" }
}

$Raw = Join-Path $PackagePath "D8A_RAW_ble_app_peripheral_585.bin"
$Axf = Join-Path $PackagePath "D8A_ble_app_peripheral_585.axf"
$Packed = Join-Path $PackagePath "D8A_FINAL_PACKED_256KB.bin"
$Golden = Join-Path $PackagePath "D8A_GOLDEN_BASE_256KB.bin"
$Manifest = Get-Content -LiteralPath (Join-Path $PackagePath "D8A_MANIFEST_SHA256.txt") -Raw
$SdkObjects = "D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\out_DA14585\Objects"

if ((Get-Item $Raw).Length -ne 47620) { throw "Raw size mismatch" }
if ((Get-FileHash $Raw -Algorithm SHA256).Hash -ne "D0466BA329FFAF81B8278FA25239B8A7ACCF78072E7B688E5F1182438B0CA75F") { throw "Raw hash mismatch" }
if ((Get-FileHash $Axf -Algorithm SHA256).Hash -ne "E71FED7B8E4E1978BCAF3676B932A298A478D7F3DD6AC9CE669D21B90764609D") { throw "AXF hash mismatch" }
if ((Get-FileHash (Join-Path $SdkObjects "ble_app_peripheral_585.bin") -Algorithm SHA256).Hash -ne (Get-FileHash $Raw -Algorithm SHA256).Hash) { throw "SDK raw mismatch" }
if ((Get-Item $Packed).Length -ne 262144) { throw "Packed size mismatch" }
if ((Get-FileHash $Packed -Algorithm SHA256).Hash -ne "CDDB3BFE79B49564119D6936597D0D8CBE70D21E67A4CAF9A3D58DED62125ADE") { throw "Packed hash mismatch" }
if ((Get-FileHash $Golden -Algorithm SHA256).Hash -ne "C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452") { throw "Golden hash mismatch" }

foreach ($Needle in @("FIRMWARE_ID D8A1", "SOURCE_ID D8A00001", "Code=42340", "READY FOR OWNER SPI PHYSICAL GATE - NOT YET BURNED")) {
    if ($Manifest -notmatch [regex]::Escape($Needle)) { throw "Manifest missing $Needle" }
}

$Verify = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PackagePath "verify-d8a-package.ps1") -PackagePath $PackagePath
if (($Verify -join "`n") -notmatch "D8A package verify PASS") { throw "Verify failed" }

$Tracked = git ls-files
foreach ($Name in $Required) {
    if ($Tracked -contains "_incoming/D8A_SPI_FINAL_2026-07-21/$Name") { throw "Artifact tracked: $Name" }
}

$Status = git status --short --untracked-files=all
foreach ($Line in $Status) {
    if ($Line -match '^\s*(M|A|D|\?\?)\s+(firmware/|web/|test\.html)') { throw "Runtime source changed: $Line" }
}

Write-Host "TASK D8A SPI final smoke PASS"

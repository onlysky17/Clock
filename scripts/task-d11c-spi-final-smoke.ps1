[CmdletBinding()]
param(
    [string]$PackagePath = "D:\EINK\Clock\_incoming\D11C_SPI_FINAL_2026-07-22"
)

$ErrorActionPreference = "Stop"
$RepoRoot = (git rev-parse --show-toplevel).Trim() -replace "\\", "/"
if ($RepoRoot -ne "D:/EINK/Clock") { throw "Wrong repo: $RepoRoot" }
$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path

$Required = @(
    "D11C_RAW_ble_app_peripheral_585.bin",
    "D11C_ble_app_peripheral_585.axf",
    "D11C_FINAL_PACKED_256KB.bin",
    "D11C_GOLDEN_BASE_256KB.bin",
    "D11C_MANIFEST_SHA256.txt",
    "verify-d11c-package.ps1",
    "README_D11C_SPI_BURN.txt"
)
foreach ($Name in $Required) {
    if (-not (Test-Path -LiteralPath (Join-Path $PackagePath $Name) -PathType Leaf)) { throw "Missing $Name" }
}

$Raw = Join-Path $PackagePath "D11C_RAW_ble_app_peripheral_585.bin"
$Axf = Join-Path $PackagePath "D11C_ble_app_peripheral_585.axf"
$Packed = Join-Path $PackagePath "D11C_FINAL_PACKED_256KB.bin"
$Golden = Join-Path $PackagePath "D11C_GOLDEN_BASE_256KB.bin"
$Manifest = Get-Content -LiteralPath (Join-Path $PackagePath "D11C_MANIFEST_SHA256.txt") -Raw
$SdkRoot = "D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE"
$SdkObjects = Join-Path $SdkRoot "Keil_5\out_DA14585\Objects"
$CanonicalSource = "D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE\src\user_custs1_impl.c"
$SdkSource = Join-Path $SdkRoot "src\user_custs1_impl.c"

if ((Get-Item $Raw).Length -ne 48380) { throw "Raw size mismatch" }
if ((Get-FileHash $Raw -Algorithm SHA256).Hash -ne "6ACDE0EED8728C8F16B0D92F7DB14502B36069459D5D99B8FAEE5F93B4EA22CE") { throw "Raw hash mismatch" }
if ((Get-FileHash $Axf -Algorithm SHA256).Hash -ne "A13B9A67160BE357780B7C90090A24D74C82B431DA6F9B5EEC97AA3242FC7C42") { throw "AXF hash mismatch" }
if ((Get-FileHash (Join-Path $SdkObjects "ble_app_peripheral_585.bin") -Algorithm SHA256).Hash -ne (Get-FileHash $Raw -Algorithm SHA256).Hash) { throw "SDK raw mismatch" }
if ((Get-FileHash $CanonicalSource -Algorithm SHA256).Hash -ne (Get-FileHash $SdkSource -Algorithm SHA256).Hash) { throw "Canonical/SDK source mismatch" }
if ((Get-Item $Packed).Length -ne 262144) { throw "Packed size mismatch" }
if ((Get-FileHash $Packed -Algorithm SHA256).Hash -ne "0A8C78B071FA5F16775F34D3643BE2644EE0274287FA82DFA3D859F113D43197") { throw "Packed hash mismatch" }
if ((Get-FileHash $Golden -Algorithm SHA256).Hash -ne "C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452") { throw "Golden hash mismatch" }
if ((Get-FileHash $Packed -Algorithm SHA256).Hash -eq (Get-FileHash $Golden -Algorithm SHA256).Hash) { throw "Packed image equals golden" }
if (-not ([IO.File]::ReadAllBytes($Packed) | Where-Object { $_ -ne 0xFF } | Select-Object -First 1)) { throw "Packed image is all FF" }

$RawBytes = [IO.File]::ReadAllBytes($Raw)
$PackedBytes = [IO.File]::ReadAllBytes($Packed)
for ($i = 0; $i -lt $RawBytes.Length; $i++) {
    if ($PackedBytes[0x4040 + $i] -ne $RawBytes[$i]) { throw "Packed payload mismatch at $i" }
}

foreach ($Needle in @(
    "D11B_MERGE 63d6063a33d7b4905a0114fbaa7f1aa8909001ed",
    "FIRMWARE_ID D8A1",
    "SOURCE_ID D8A00001",
    "BUILD Code=43100 RO=3592 RW=552 ZI=22932 Errors=0 Warnings=0",
    "READY FOR OWNER SPI PHYSICAL GATE - NOT YET BURNED",
    "https://onlysky17.github.io/Clock/test.html"
)) {
    if ($Manifest -notmatch [regex]::Escape($Needle)) { throw "Manifest missing $Needle" }
}

$Symdef = Get-Content -LiteralPath (Join-Path $SdkObjects "ble_app_peripheral_585_symdef.txt") -Raw
if ($Symdef -match "sfont16|asc2_1608|Font16|font16") { throw "Legacy font symbol present" }

$Verify = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PackagePath "verify-d11c-package.ps1") -PackagePath $PackagePath
if (($Verify -join "`n") -notmatch "D11C package verify PASS") { throw "Verify failed" }

$Tracked = git ls-files
foreach ($Name in $Required) {
    if ($Tracked -contains "_incoming/D11C_SPI_FINAL_2026-07-22/$Name") { throw "Artifact tracked: $Name" }
}

$Status = git status --short --untracked-files=all
foreach ($Line in $Status) {
    if ($Line -match '^\s*(M|A|D|\?\?)\s+(firmware/|web/|test\.html)') { throw "Runtime source changed: $Line" }
}

Write-Host "TASK D11C SPI final smoke PASS"

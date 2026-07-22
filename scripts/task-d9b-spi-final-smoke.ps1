[CmdletBinding()]
param(
    [string]$PackagePath = "D:\EINK\Clock\_incoming\D9B_SPI_FINAL_2026-07-22"
)

$ErrorActionPreference = "Stop"
$RepoRoot = (git rev-parse --show-toplevel).Trim() -replace "\\", "/"
if ($RepoRoot -ne "D:/EINK/Clock") { throw "Wrong repo: $RepoRoot" }
$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path

$Required = @(
    "D9B_RAW_ble_app_peripheral_585.bin",
    "D9B_ble_app_peripheral_585.axf",
    "D9B_FINAL_PACKED_256KB.bin",
    "D9B_GOLDEN_BASE_256KB.bin",
    "D9B_MANIFEST_SHA256.txt",
    "verify-d9b-package.ps1",
    "README_D9B_SPI_BURN.txt"
)
foreach ($Name in $Required) {
    if (-not (Test-Path -LiteralPath (Join-Path $PackagePath $Name) -PathType Leaf)) { throw "Missing $Name" }
}

$Raw = Join-Path $PackagePath "D9B_RAW_ble_app_peripheral_585.bin"
$Axf = Join-Path $PackagePath "D9B_ble_app_peripheral_585.axf"
$Packed = Join-Path $PackagePath "D9B_FINAL_PACKED_256KB.bin"
$Golden = Join-Path $PackagePath "D9B_GOLDEN_BASE_256KB.bin"
$Manifest = Get-Content -LiteralPath (Join-Path $PackagePath "D9B_MANIFEST_SHA256.txt") -Raw
$SdkObjects = "D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\out_DA14585\Objects"

if ((Get-Item $Raw).Length -ne 47924) { throw "Raw size mismatch" }
if ((Get-FileHash $Raw -Algorithm SHA256).Hash -ne "212911C6C68E8EC2060A63B8ADCE65BD44E055B6822B5B6B236AC694F326F824") { throw "Raw hash mismatch" }
if ((Get-FileHash $Axf -Algorithm SHA256).Hash -ne "9CFBE543E1BA3ACD588D6DA721A6021DBC82BD23FF87D9D016FA0AF305FDA402") { throw "AXF hash mismatch" }
if ((Get-FileHash (Join-Path $SdkObjects "ble_app_peripheral_585.bin") -Algorithm SHA256).Hash -ne (Get-FileHash $Raw -Algorithm SHA256).Hash) { throw "SDK raw mismatch" }
if ((Get-Item $Packed).Length -ne 262144) { throw "Packed size mismatch" }
if ((Get-FileHash $Packed -Algorithm SHA256).Hash -ne "51D90603363B9660CC43686E68E93FCAA9668ECB3985FF1CE292A58DB55DD8B2") { throw "Packed hash mismatch" }
if ((Get-FileHash $Golden -Algorithm SHA256).Hash -ne "C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452") { throw "Golden hash mismatch" }
if ((Get-FileHash $Packed -Algorithm SHA256).Hash -eq (Get-FileHash $Golden -Algorithm SHA256).Hash) { throw "Packed image equals golden" }
if (-not ([IO.File]::ReadAllBytes($Packed) | Where-Object { $_ -ne 0xFF } | Select-Object -First 1)) { throw "Packed image is all FF" }

foreach ($Needle in @("D9A_IMPLEMENTATION 63936eb8a9e2324fac9447319f5e789e1fdd85f7", "FIRMWARE_ID D8A1", "SOURCE_ID D8A00001", "Code=42644", "READY FOR OWNER SPI PHYSICAL GATE - NOT YET BURNED", "https://onlysky17.github.io/Clock/test.html")) {
    if ($Manifest -notmatch [regex]::Escape($Needle)) { throw "Manifest missing $Needle" }
}

$Verify = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PackagePath "verify-d9b-package.ps1") -PackagePath $PackagePath
if (($Verify -join "`n") -notmatch "D9B package verify PASS") { throw "Verify failed" }

$Tracked = git ls-files
foreach ($Name in $Required) {
    if ($Tracked -contains "_incoming/D9B_SPI_FINAL_2026-07-22/$Name") { throw "Artifact tracked: $Name" }
}

$Status = git status --short --untracked-files=all
foreach ($Line in $Status) {
    if ($Line -match '^\s*(M|A|D|\?\?)\s+(firmware/|web/|test\.html)') { throw "Runtime source changed: $Line" }
}

Write-Host "TASK D9B SPI final smoke PASS"

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackagePath
)

$ErrorActionPreference = "Stop"

$RepoRoot = (git rev-parse --show-toplevel).Trim()
if ($RepoRoot -replace "\\","/" -ne "D:/EINK/Clock") {
    throw "Wrong repo root: $RepoRoot"
}

$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
$ExpectedPackage = "D:\EINK\Clock\_incoming\D18B_AGENDA_SPI_FINAL_20260728_161153"
if ($PackagePath -ne $ExpectedPackage) {
    throw "Unexpected package path: $PackagePath"
}

$Required = @(
    "D18B_RAW_ble_app_peripheral_585.bin",
    "D18B_ble_app_peripheral_585.axf",
    "D18B_FINAL_PACKED_256KB.bin",
    "D18B_GOLDEN_BASE_256KB.bin",
    "D18B_MANIFEST_SHA256.txt",
    "verify-d18b-package.ps1",
    "README_D18B_SPI_BURN.txt"
)

foreach ($Name in $Required) {
    if (-not (Test-Path -LiteralPath (Join-Path $PackagePath $Name) -PathType Leaf)) {
        throw "Missing package file: $Name"
    }
}

$Raw = Join-Path $PackagePath "D18B_RAW_ble_app_peripheral_585.bin"
$Axf = Join-Path $PackagePath "D18B_ble_app_peripheral_585.axf"
$Packed = Join-Path $PackagePath "D18B_FINAL_PACKED_256KB.bin"
$Golden = Join-Path $PackagePath "D18B_GOLDEN_BASE_256KB.bin"
$Manifest = Join-Path $PackagePath "D18B_MANIFEST_SHA256.txt"
$Verify = Join-Path $PackagePath "verify-d18b-package.ps1"

function Assert-FileHashAndSize {
    param([string]$Path, [int64]$Size, [string]$Hash)

    if ((Get-Item -LiteralPath $Path).Length -ne $Size) {
        throw "Size mismatch: $Path"
    }
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Hash) {
        throw "SHA256 mismatch: $Path"
    }
}

Assert-FileHashAndSize $Raw 50552 "586DB6FFFAD3B5121982B291E9A32032C73C1878DF199872C414E69C7C434063"
Assert-FileHashAndSize $Axf 572784 "38F0A74BBDE610F6FCB45A6BBA04C49A68890970693C0D93E32DB40DD51BA5FA"
Assert-FileHashAndSize $Golden 262144 "C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452"
Assert-FileHashAndSize $Packed 262144 "5790AA976BBC7A57DF63873DCE192F57C606B63A10EDBBD4FFCEE52F9D15F44A"

if ((Get-Item -LiteralPath $Raw).Length -ge 65528) {
    throw "Raw BIN exceeds packer limit."
}

$ManifestText = Get-Content -LiteralPath $Manifest -Raw
foreach ($Needle in @(
    "REPO_HEAD 5f037aee90d539c146c8bc7f6db85af003d8a029",
    "BUILD Code=45232 RO=3632 RW=552 ZI=22956 Errors=0 Warnings=0",
    "STATUS READY FOR OWNER SPI PHYSICAL GATE - NOT YET BURNED",
    "PACKED_SHA256 5790AA976BBC7A57DF63873DCE192F57C606B63A10EDBBD4FFCEE52F9D15F44A",
    "CANONICAL_URL https://onlysky17.github.io/Clock/test.html"
)) {
    if ($ManifestText -notmatch [regex]::Escape($Needle)) {
        throw "Manifest missing required metadata: $Needle"
    }
}

$VerifyOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Verify -PackagePath $PackagePath
if (($VerifyOutput -join "`n") -notmatch "D18B package verify PASS") {
    throw "Package verify script did not PASS."
}

$Firmware = Get-Content -LiteralPath "D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE\src\user_custs1_impl.c" -Raw
foreach ($Needle in @(
    "#define HINK_EPD_PRIME_RECOVERY_TICKS 100UL",
    "#define HINK_D13D_WEATHER_X 6U",
    "hink_d13b_draw_daily_briefing",
    "hink_d2_daily_handle"
)) {
    if ($Firmware -notmatch [regex]::Escape($Needle)) {
        throw "Firmware agenda baseline missing: $Needle"
    }
}

$Packer = Get-Content -LiteralPath "D:\EINK\Clock\tools\pack-hink.ps1" -Raw
foreach ($Needle in @(
    '$FlashSize = 0x40000',
    '$ImageHeaderOffset = 0x04000',
    '$ImagePayloadOffset = 0x04040',
    '$ProductHeaderOffset = 0x38000'
)) {
    if ($Packer -notmatch [regex]::Escape($Needle)) {
        throw "Packer layout changed: $Needle"
    }
}

$TestHtml = Get-Content -LiteralPath "D:\EINK\Clock\test.html" -Raw
if ($TestHtml -notmatch "web/clock-app/hl24a-canvas-e5.html") {
    throw "Canonical test.html target changed."
}

$Tracked = git ls-files
foreach ($Name in $Required) {
    if ($Tracked -contains "_incoming/D18B_AGENDA_SPI_FINAL_20260728_161153/$Name") {
        throw "Package artifact is tracked by Git: $Name"
    }
}

$Allowed = @(
    "docs/firmware/TASK_D18B_AGENDA_FIRMWARE_SPI_FINAL.md",
    "scripts/task-d18b-agenda-firmware-spi-final-smoke.ps1"
)
$Dirty = @(git status --short --untracked-files=all)
foreach ($Line in $Dirty) {
    $Path = $Line.Substring(3).Replace("\", "/")
    if ($Allowed -notcontains $Path) {
        throw "Unexpected dirty path: $Path"
    }
}

Write-Host "TASK D18B agenda firmware SPI final smoke PASS"

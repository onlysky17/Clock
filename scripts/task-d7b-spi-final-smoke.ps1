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
$ExpectedPackage = "D:\EINK\Clock\_incoming\D7B_FIX5_SPI_FINAL_2026-07-21"
if ($PackagePath -ne $ExpectedPackage) {
    throw "Unexpected package path: $PackagePath"
}

$Required = @(
    "D7B_RAW_ble_app_peripheral_585.bin",
    "D7B_ble_app_peripheral_585.axf",
    "D7B_FINAL_PACKED_256KB.bin",
    "D7B_GOLDEN_BASE_256KB.bin",
    "D7B_MANIFEST_SHA256.txt",
    "verify-d7b-package.ps1",
    "README_D7B_SPI_BURN.txt"
)

foreach ($Name in $Required) {
    $Path = Join-Path $PackagePath $Name
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing package file: $Name"
    }
}

$Raw = Join-Path $PackagePath "D7B_RAW_ble_app_peripheral_585.bin"
$Axf = Join-Path $PackagePath "D7B_ble_app_peripheral_585.axf"
$Packed = Join-Path $PackagePath "D7B_FINAL_PACKED_256KB.bin"
$Golden = Join-Path $PackagePath "D7B_GOLDEN_BASE_256KB.bin"
$Manifest = Join-Path $PackagePath "D7B_MANIFEST_SHA256.txt"
$Verify = Join-Path $PackagePath "verify-d7b-package.ps1"

$SdkRaw = "D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\out_DA14585\Objects\ble_app_peripheral_585.bin"
$SdkAxf = "D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\out_DA14585\Objects\ble_app_peripheral_585.axf"
$GoldenSource = "D:\EINK\Clock\tools\packages\HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin"

function Assert-FileHashAndSize {
    param(
        [string]$Path,
        [int64]$Size,
        [string]$Hash
    )

    $Item = Get-Item -LiteralPath $Path
    if ($Item.Length -ne $Size) {
        throw "Size mismatch for $Path. Expected $Size, got $($Item.Length)"
    }

    $Actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($Actual -ne $Hash) {
        throw "SHA256 mismatch for $Path. Expected $Hash, got $Actual"
    }
}

Assert-FileHashAndSize -Path $Golden -Size 262144 -Hash "C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452"
Assert-FileHashAndSize -Path $GoldenSource -Size 262144 -Hash "C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452"

if ((Get-Item -LiteralPath $Packed).Length -ne 262144) {
    throw "Packed image must be 262144 bytes."
}

if ((Get-Item -LiteralPath $Raw).Length -ge 65528) {
    throw "Raw BIN exceeds packer limit."
}

$SdkRawHash = (Get-FileHash -LiteralPath $SdkRaw -Algorithm SHA256).Hash
$PkgRawHash = (Get-FileHash -LiteralPath $Raw -Algorithm SHA256).Hash
if ($SdkRawHash -ne $PkgRawHash) {
    throw "Package raw BIN does not match fresh SDK build."
}

$SdkAxfHash = (Get-FileHash -LiteralPath $SdkAxf -Algorithm SHA256).Hash
$PkgAxfHash = (Get-FileHash -LiteralPath $Axf -Algorithm SHA256).Hash
if ($SdkAxfHash -ne $PkgAxfHash) {
    throw "Package AXF does not match fresh SDK build."
}

$ManifestText = Get-Content -LiteralPath $Manifest -Raw
foreach ($Name in @("D7B_RAW_ble_app_peripheral_585.bin","D7B_ble_app_peripheral_585.axf","D7B_FINAL_PACKED_256KB.bin","D7B_GOLDEN_BASE_256KB.bin","verify-d7b-package.ps1","README_D7B_SPI_BURN.txt")) {
    if ($ManifestText -notmatch [regex]::Escape("FILE $Name")) {
        throw "Manifest missing file row: $Name"
    }
}

foreach ($Needle in @(
    "REPO_HEAD",
    "FIX5_COMMIT e9a32950a7093ff31d0a06720fb74d9f9c5cff82",
    "KEIL_TARGET DA14585",
    "KEIL_COMPILER ARMCLANG 6.24",
    "BUILD Code=42192 RO=3592 RW=552 ZI=22928 Errors=0 Warnings=0",
    "STATUS READY FOR OWNER SPI PHYSICAL GATE - NOT YET BURNED",
    "PACK_COMMAND"
)) {
    if ($ManifestText -notmatch [regex]::Escape($Needle)) {
        throw "Manifest missing required metadata: $Needle"
    }
}

$VerifyOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Verify -PackagePath $PackagePath
if (($VerifyOutput -join "`n") -notmatch "D7B package verify PASS") {
    throw "Package verify script did not PASS."
}

[byte[]]$RawBytes = [IO.File]::ReadAllBytes($Raw)
[byte[]]$PackedBytes = [IO.File]::ReadAllBytes($Packed)
[byte[]]$GoldenBytes = [IO.File]::ReadAllBytes($Golden)

$PayloadOffset = 0x4040
for ($i = 0; $i -lt $RawBytes.Length; $i++) {
    if ($PackedBytes[$PayloadOffset + $i] -ne $RawBytes[$i]) {
        throw "Packed payload mismatch at raw offset $i"
    }
}

$AllFF = $true
foreach ($Byte in $PackedBytes) {
    if ($Byte -ne 0xFF) {
        $AllFF = $false
        break
    }
}
if ($AllFF) {
    throw "Packed image is all FF."
}

if ((Get-FileHash -LiteralPath $Packed -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $Golden -Algorithm SHA256).Hash) {
    throw "Packed image must differ from golden base."
}

$Tracked = git ls-files
foreach ($Name in $Required) {
    if ($Tracked -contains "_incoming/D7B_FIX5_SPI_FINAL_2026-07-21/$Name") {
        throw "Package artifact is tracked by Git: $Name"
    }
}

$Status = git status --short --untracked-files=all
foreach ($Line in $Status) {
    if ($Line -match '^\s*(M|A|D|\?\?)\s+firmware/') {
        throw "Firmware source must not be modified."
    }
    if ($Line -match '^\s*(M|A|D|\?\?)\s+web/') {
        throw "Web source must not be modified."
    }
    if ($Line -match '^\s*(M|A|D|\?\?)\s+test\.html$') {
        throw "test.html must not be modified."
    }
}

$TestHtml = Get-Content -LiteralPath "D:\EINK\Clock\test.html" -Raw
if ($TestHtml -notmatch "web/clock-app/hl24a-canvas-e5.html") {
    throw "Canonical test.html target changed."
}

$Docs = Get-ChildItem -LiteralPath "D:\EINK\Clock\docs" -Recurse -File | Select-String -Pattern "https://onlysky17.github.io/Clock/test.html"
if (-not $Docs) {
    throw "Canonical web URL missing from docs."
}

Write-Host "TASK D7B SPI final smoke PASS"

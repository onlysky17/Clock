[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Raw,

    [Parameter(Mandatory = $true)]
    [string]$Out,

    [Parameter(Mandatory = $true)]
    [string]$Name,

    [string]$Template = "D:\EINK\GOOD_CONNECT\HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin",

    [string]$Manifest = "D:\EINK\Clock\tools\HINK_GOLDEN_TEMPLATE_MANIFEST.json"
)

$ErrorActionPreference = "Stop"

$FlashSize = 0x40000
$ImageHeaderOffset = 0x04000
$ImagePayloadOffset = 0x04040
$ProductHeaderOffset = 0x38000
$MaxRawSize = 0x10000
$FallbackExpectedHash = "C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452"


function Read-U32LE {
    param([byte[]]$Bytes, [int]$Offset)
    return [uint32](
        ([uint32]$Bytes[$Offset]) -bor
        ([uint32]$Bytes[$Offset + 1] -shl 8) -bor
        ([uint32]$Bytes[$Offset + 2] -shl 16) -bor
        ([uint32]$Bytes[$Offset + 3] -shl 24)
    )
}

function Read-U32BE {
    param([byte[]]$Bytes, [int]$Offset)
    return [uint32](
        ([uint32]$Bytes[$Offset] -shl 24) -bor
        ([uint32]$Bytes[$Offset + 1] -shl 16) -bor
        ([uint32]$Bytes[$Offset + 2] -shl 8) -bor
        ([uint32]$Bytes[$Offset + 3])
    )
}

function Get-Crc32 {
    param([byte[]]$Bytes, [int]$Offset, [int]$Count)

    [uint32]$crc = [uint32]::MaxValue

    for ($i = $Offset; $i -lt ($Offset + $Count); $i++) {
        $crc = [uint32]($crc -bxor [uint32]$Bytes[$i])

        for ($bit = 0; $bit -lt 8; $bit++) {
            if (($crc -band [uint32]1) -ne 0) {
                $crc = [uint32](($crc -shr 1) -bxor [uint32]3988292384)
            }
            else {
                $crc = [uint32]($crc -shr 1)
            }
        }
    }

    return [uint32]($crc -bxor [uint32]::MaxValue)
}

function Test-HinkFullImage {
    param([Parameter(Mandatory=$true)][string]$Path)

    $FlashSize = 0x40000
    $ImageHeaderOffset = 0x04000
    $PayloadOffset = 0x04040
    $ProductHeaderOffset = 0x38000
    $MaxPayload = 0x10000

    $item = Get-Item -LiteralPath $Path
    if ($item.Length -ne $FlashSize) {
        return $null
    }

    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($Path)

    $sig50 = ($bytes[0] -eq 0x70 -and $bytes[1] -eq 0x50)
    $sig51 = ($bytes[$ImageHeaderOffset] -eq 0x70 -and
              $bytes[$ImageHeaderOffset + 1] -eq 0x51)
    $sig52 = ($bytes[$ProductHeaderOffset] -eq 0x70 -and
              $bytes[$ProductHeaderOffset + 1] -eq 0x52)
    $validFlag = ($bytes[$ImageHeaderOffset + 2] -eq 0xAA)

    $endian = $null
    [uint32]$payloadSize = 0
    [uint32]$storedCrc = 0
    [uint32]$computedCrc = 0

    $sizeLE = Read-U32LE $bytes ($ImageHeaderOffset + 4)
    $crcLE = Read-U32LE $bytes ($ImageHeaderOffset + 8)

    if (($sizeLE -gt 0) -and
        ($sizeLE -le $MaxPayload) -and
        (($PayloadOffset + $sizeLE) -lt $ProductHeaderOffset)) {
        $candidate = Get-Crc32 $bytes $PayloadOffset ([int]$sizeLE)

        if ($candidate -eq $crcLE) {
            $endian = "LE"
            $payloadSize = $sizeLE
            $storedCrc = $crcLE
            $computedCrc = $candidate
        }
    }

    if (-not $endian) {
        $sizeBE = Read-U32BE $bytes ($ImageHeaderOffset + 4)
        $crcBE = Read-U32BE $bytes ($ImageHeaderOffset + 8)

        if (($sizeBE -gt 0) -and
            ($sizeBE -le $MaxPayload) -and
            (($PayloadOffset + $sizeBE) -lt $ProductHeaderOffset)) {
            $candidate = Get-Crc32 $bytes $PayloadOffset ([int]$sizeBE)

            if ($candidate -eq $crcBE) {
                $endian = "BE"
                $payloadSize = $sizeBE
                $storedCrc = $crcBE
                $computedCrc = $candidate
            }
        }
    }

    $ascii = [System.Text.Encoding]::ASCII.GetString($bytes)
    $names = [regex]::Matches(
        $ascii,
        '(?:EINK|HINK)[A-Z0-9_-]{2,24}'
    ) |
        ForEach-Object Value |
        Sort-Object Length -Descending -Unique

    $nameText = ($names -join ",")
    $valid = $sig50 -and $sig51 -and $sig52 -and $validFlag -and ($null -ne $endian)

    $score = 0
    if ($valid) { $score += 1000 }
    if ($nameText -match 'HINK213-CLOCK') { $score += 500 }
    elseif ($nameText -match 'HINK213') { $score += 300 }
    elseif ($nameText -match '(HINK|EINK)') { $score += 100 }

    if ($Path -match 'GOOD_CONNECT') { $score += 80 }
    if ($Path -match 'DONOR') { $score += 20 }

    return [PSCustomObject]@{
        Valid = $valid
        Score = $score
        FullName = $item.FullName
        SHA256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        PayloadSize = [int]$payloadSize
        PayloadCRC = if ($endian) { "{0:X8}" -f $storedCrc } else { "" }
        Endian = if ($endian) { $endian } else { "" }
        Names = $nameText
        Sig7050 = $sig50
        Sig7051 = $sig51
        Sig7052 = $sig52
        ValidFlagAA = $validFlag
    }
}


if (-not (Test-Path -LiteralPath $Raw -PathType Leaf)) {
    throw "Raw BIN not found: $Raw"
}
if (-not (Test-Path -LiteralPath $Template -PathType Leaf)) {
    throw "Golden template not found: $Template"
}

$rawItem = Get-Item -LiteralPath $Raw
if (($rawItem.Length -le 0) -or ($rawItem.Length -gt $MaxRawSize)) {
    throw "Raw BIN size is invalid: $($rawItem.Length)"
}

$templateCheck = Test-HinkFullImage -Path $Template
if (-not $templateCheck.Valid) {
    throw "Golden template failed structural/header/CRC validation."
}

$expectedHash = $FallbackExpectedHash
if (Test-Path -LiteralPath $Manifest) {
    $manifestData = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
    if (-not $manifestData.SHA256) {
        throw "Golden manifest does not contain SHA256."
    }
    $expectedHash = [string]$manifestData.SHA256
}

if ($templateCheck.SHA256 -ne $expectedHash) {
    throw @"
Golden template SHA256 mismatch.
Current : $($templateCheck.SHA256)
Expected: $expectedHash
Template: $Template
Manifest: $Manifest
"@
}

[byte[]]$templateBytes = [System.IO.File]::ReadAllBytes($Template)
[byte[]]$rawBytes = [System.IO.File]::ReadAllBytes($Raw)

$rawAscii = [System.Text.Encoding]::ASCII.GetString($rawBytes)
if ($rawAscii.IndexOf($Name, [System.StringComparison]::Ordinal) -lt 0) {
    throw "BLE name '$Name' was not found inside the raw BIN."
}

[uint32]$newCrc = Get-Crc32 $rawBytes 0 $rawBytes.Length
[byte[]]$outputBytes = New-Object byte[] $templateBytes.Length
[System.Array]::Copy($templateBytes, 0, $outputBytes, 0, $templateBytes.Length)

$oldSize = [int]$templateCheck.PayloadSize
$clearLength = [Math]::Max($oldSize, $rawBytes.Length)

if (($ImagePayloadOffset + $clearLength) -ge $ProductHeaderOffset) {
    throw "New payload would overlap the product header."
}

for ($i = 0; $i -lt $clearLength; $i++) {
    $outputBytes[$ImagePayloadOffset + $i] = 0xFF
}

[System.Array]::Copy($rawBytes, 0, $outputBytes, $ImagePayloadOffset, $rawBytes.Length)

function Write-U32LE {
    param([byte[]]$Bytes, [int]$Offset, [uint32]$Value)
    $Bytes[$Offset] = [byte]($Value -band 0xFF)
    $Bytes[$Offset + 1] = [byte](($Value -shr 8) -band 0xFF)
    $Bytes[$Offset + 2] = [byte](($Value -shr 16) -band 0xFF)
    $Bytes[$Offset + 3] = [byte](($Value -shr 24) -band 0xFF)
}

function Write-U32BE {
    param([byte[]]$Bytes, [int]$Offset, [uint32]$Value)
    $Bytes[$Offset] = [byte](($Value -shr 24) -band 0xFF)
    $Bytes[$Offset + 1] = [byte](($Value -shr 16) -band 0xFF)
    $Bytes[$Offset + 2] = [byte](($Value -shr 8) -band 0xFF)
    $Bytes[$Offset + 3] = [byte]($Value -band 0xFF)
}

if ($templateCheck.Endian -eq "LE") {
    Write-U32LE $outputBytes ($ImageHeaderOffset + 4) ([uint32]$rawBytes.Length)
    Write-U32LE $outputBytes ($ImageHeaderOffset + 8) $newCrc
}
else {
    Write-U32BE $outputBytes ($ImageHeaderOffset + 4) ([uint32]$rawBytes.Length)
    Write-U32BE $outputBytes ($ImageHeaderOffset + 8) $newCrc
}

$outParent = Split-Path -Parent $Out
New-Item -ItemType Directory -Force -Path $outParent | Out-Null

$temp = "$Out.tmp"
if (Test-Path -LiteralPath $temp) {
    Remove-Item -LiteralPath $temp -Force
}

[System.IO.File]::WriteAllBytes($temp, $outputBytes)

$verify = Test-HinkFullImage -Path $temp
if (-not $verify.Valid) {
    Remove-Item -LiteralPath $temp -Force
    throw "Packed output failed structural/header/CRC verification."
}

if ($verify.PayloadSize -ne $rawBytes.Length) {
    Remove-Item -LiteralPath $temp -Force
    throw "Packed output payload size mismatch."
}

if ($verify.PayloadCRC -ne ("{0:X8}" -f $newCrc)) {
    Remove-Item -LiteralPath $temp -Force
    throw "Packed output payload CRC mismatch."
}

if (Test-Path -LiteralPath $Out) {
    Remove-Item -LiteralPath $Out -Force
}
Move-Item -LiteralPath $temp -Destination $Out -Force

Write-Host ""
Write-Host "STATUS: READY TO FLASH" -ForegroundColor Green
Write-Host "FILE: $Out"
Write-Host "DEVICE: $Name"
Write-Host "RAW_SIZE: $($rawBytes.Length)"
Write-Host "RAW_CRC32: $('{0:X8}' -f $newCrc)"
Write-Host "TEMPLATE_SHA256: $($templateCheck.SHA256)"
Write-Host "OUTPUT_SHA256: $((Get-FileHash -LiteralPath $Out -Algorithm SHA256).Hash)"
Write-Host "HEADER: OK"
Write-Host "LAYOUT: 7050@00000 7051@04000 PAYLOAD@04040 7052@38000"

[CmdletBinding()]
param(
    [string]$SearchRoot = "D:\EINK",
    [string]$RepoRoot = "D:\EINK\Clock",
    [string]$GoldenTarget = "D:\EINK\GOOD_CONNECT\HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin"
)

$ErrorActionPreference = "Stop"

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

    [uint32]$crc = 0xFFFFFFFF

    for ($i = $Offset; $i -lt ($Offset + $Count); $i++) {
        $crc = [uint32]($crc -bxor [uint32]$Bytes[$i])

        for ($bit = 0; $bit -lt 8; $bit++) {
            if (($crc -band [uint32]1) -ne 0) {
                $crc = [uint32](($crc -shr 1) -bxor [uint32]0xEDB88320)
            }
            else {
                $crc = [uint32]($crc -shr 1)
            }
        }
    }

    return [uint32]($crc -bxor [uint32]0xFFFFFFFF)
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


$all = Get-ChildItem -LiteralPath $SearchRoot `
    -Recurse `
    -File `
    -Filter "*.bin" `
    -ErrorAction SilentlyContinue |
    Where-Object Length -eq 262144 |
    ForEach-Object {
        try { Test-HinkFullImage -Path $_.FullName } catch { $null }
    } |
    Where-Object { $_ -and $_.Valid }

$unique = @($all | Group-Object SHA256 | ForEach-Object {
    $_.Group |
        Sort-Object -Property @{Expression={ if ($_.FullName -match 'GOOD_CONNECT') {0} else {1} };Descending=$false}, @{Expression={$_.FullName};Descending=$false} |
        Select-Object -First 1
})

$preferred = @($unique | Where-Object { $_.Names -match 'HINK213-CLOCK' })

if ($preferred.Count -ne 1) {
    Write-Host "Recovery requires exactly one unique valid HINK213-CLOCK image." -ForegroundColor Yellow
    Write-Host "Found: $($preferred.Count)"
    if ($preferred.Count -gt 0) {
        $preferred | Format-List SHA256,PayloadSize,PayloadCRC,Names,FullName
    }
    throw "Automatic recovery refused. Run scan-hink-templates.ps1 and review the report."
}

$candidate = $preferred[0]

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $GoldenTarget) | Out-Null
Copy-Item -LiteralPath $candidate.FullName -Destination $GoldenTarget -Force

$copied = Test-HinkFullImage -Path $GoldenTarget
if (-not $copied.Valid -or $copied.SHA256 -ne $candidate.SHA256) {
    throw "Copied golden template failed verification."
}

$manifestPath = Join-Path $RepoRoot "tools\HINK_GOLDEN_TEMPLATE_MANIFEST.json"
$manifest = [ordered]@{
    Schema = 1
    Target = $GoldenTarget
    SHA256 = $copied.SHA256
    PayloadSize = $copied.PayloadSize
    PayloadCRC = $copied.PayloadCRC
    Endian = $copied.Endian
    Names = $copied.Names
    RecoveredFrom = $candidate.FullName
    RecoveredAt = (Get-Date).ToString("o")
}

$manifest |
    ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host ""
Write-Host "RECOVERY PASS" -ForegroundColor Green
Write-Host "GOLDEN: $GoldenTarget"
Write-Host "SHA256: $($copied.SHA256)"
Write-Host "PAYLOAD_SIZE: $($copied.PayloadSize)"
Write-Host "PAYLOAD_CRC: $($copied.PayloadCRC)"
Write-Host "NAMES: $($copied.Names)"
Write-Host "MANIFEST: $manifestPath"

$ErrorActionPreference = "Stop"

$SearchRoot = "D:\EINK"
$ReportDir = "D:\EINK\Clock\_incoming\HINK_TEMPLATE_SCAN"

function Read-U32LE {
    param(
        [byte[]]$B,
        [int]$O
    )

    [uint32]$v = 0
    $v += [uint32]$B[$O]
    $v += [uint32]$B[$O + 1] * 256
    $v += [uint32]$B[$O + 2] * 65536
    $v += [uint32]$B[$O + 3] * 16777216
    return $v
}

function Read-U32BE {
    param(
        [byte[]]$B,
        [int]$O
    )

    [uint32]$v = 0
    $v += [uint32]$B[$O] * 16777216
    $v += [uint32]$B[$O + 1] * 65536
    $v += [uint32]$B[$O + 2] * 256
    $v += [uint32]$B[$O + 3]
    return $v
}

function Get-Crc32 {
    param(
        [byte[]]$B,
        [int]$Offset,
        [int]$Count
    )

    [uint32]$crc = [uint32]::MaxValue
    [uint32]$poly = [uint32]3988292384

    for ($i = $Offset; $i -lt ($Offset + $Count); $i++) {
        $crc = [uint32]($crc -bxor [uint32]$B[$i])

        for ($bit = 0; $bit -lt 8; $bit++) {
            if (($crc -band [uint32]1) -ne 0) {
                $crc = [uint32](($crc -shr 1) -bxor $poly)
            }
            else {
                $crc = [uint32]($crc -shr 1)
            }
        }
    }

    return [uint32]($crc -bxor [uint32]::MaxValue)
}

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

$files = @(
    Get-ChildItem `
        -LiteralPath $SearchRoot `
        -Recurse `
        -File `
        -Filter "*.bin" `
        -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Length -eq 262144
    }
)

$results = New-Object System.Collections.ArrayList

foreach ($file in $files) {
    try {
        [byte[]]$b = [System.IO.File]::ReadAllBytes($file.FullName)

        $sig50 = (
            $b[0x00000] -eq 0x70 -and
            $b[0x00001] -eq 0x50
        )

        $sig51 = (
            $b[0x04000] -eq 0x70 -and
            $b[0x04001] -eq 0x51
        )

        $sig52 = (
            $b[0x38000] -eq 0x70 -and
            $b[0x38001] -eq 0x52
        )

        $flagAA = $b[0x04002] -eq 0xAA

        $endian = ""
        [uint32]$payloadSize = 0
        [uint32]$storedCrc = 0
        [uint32]$computedCrc = 0

        [uint32]$sizeLE = Read-U32LE $b 0x04004
        [uint32]$crcLE = Read-U32LE $b 0x04008

        if (
            $sizeLE -gt 0 -and
            $sizeLE -le 65536 -and
            (0x04040 + $sizeLE) -lt 0x38000
        ) {
            [uint32]$testCrc = Get-Crc32 $b 0x04040 ([int]$sizeLE)

            if ($testCrc -eq $crcLE) {
                $endian = "LE"
                $payloadSize = $sizeLE
                $storedCrc = $crcLE
                $computedCrc = $testCrc
            }
        }

        if ($endian -eq "") {
            [uint32]$sizeBE = Read-U32BE $b 0x04004
            [uint32]$crcBE = Read-U32BE $b 0x04008

            if (
                $sizeBE -gt 0 -and
                $sizeBE -le 65536 -and
                (0x04040 + $sizeBE) -lt 0x38000
            ) {
                [uint32]$testCrc = Get-Crc32 $b 0x04040 ([int]$sizeBE)

                if ($testCrc -eq $crcBE) {
                    $endian = "BE"
                    $payloadSize = $sizeBE
                    $storedCrc = $crcBE
                    $computedCrc = $testCrc
                }
            }
        }

        $ascii = [System.Text.Encoding]::ASCII.GetString($b)
        $nameList = New-Object System.Collections.ArrayList

        foreach (
            $match in [regex]::Matches(
                $ascii,
                "(?:EINK|HINK)[A-Z0-9_-]{2,24}"
            )
        ) {
            [void]$nameList.Add($match.Value)
        }

        $names = (
            $nameList |
            Sort-Object -Unique
        ) -join ","

        $valid = (
            $sig50 -and
            $sig51 -and
            $sig52 -and
            $flagAA -and
            $endian -ne "" -and
            $storedCrc -eq $computedCrc
        )

        $row = New-Object PSObject

        Add-Member -InputObject $row -MemberType NoteProperty `
            -Name Valid -Value $valid

        Add-Member -InputObject $row -MemberType NoteProperty `
            -Name Names -Value $names

        Add-Member -InputObject $row -MemberType NoteProperty `
            -Name PayloadSize -Value ([int]$payloadSize)

        Add-Member -InputObject $row -MemberType NoteProperty `
            -Name PayloadCRC -Value ("{0:X8}" -f $storedCrc)

        Add-Member -InputObject $row -MemberType NoteProperty `
            -Name Endian -Value $endian

        Add-Member -InputObject $row -MemberType NoteProperty `
            -Name SHA256 -Value (
                Get-FileHash `
                    -LiteralPath $file.FullName `
                    -Algorithm SHA256
            ).Hash

        Add-Member -InputObject $row -MemberType NoteProperty `
            -Name FullName -Value $file.FullName

        [void]$results.Add($row)
    }
    catch {
        Write-Warning (
            "SCAN FAILED: " +
            $file.FullName +
            " | " +
            $_.Exception.Message
        )
    }
}

$csv = Join-Path $ReportDir "hink-template-scan.csv"

$results |
    Export-Csv `
        -LiteralPath $csv `
        -NoTypeInformation `
        -Encoding UTF8

$validResults = @(
    $results |
    Where-Object {
        $_.Valid -eq $true
    }
)

$uniqueValid = New-Object System.Collections.ArrayList

foreach ($group in ($validResults | Group-Object SHA256)) {
    [void]$uniqueValid.Add($group.Group[0])
}

$preferred = @(
    $uniqueValid |
    Where-Object {
        $_.Names -match "HINK213-CLOCK"
    }
)

Write-Host ""
Write-Host "HINK TEMPLATE SCAN" -ForegroundColor Cyan
Write-Host "Report: $csv"
Write-Host ""

$results |
    Format-Table `
        Valid,
        PayloadSize,
        PayloadCRC,
        Endian,
        Names,
        FullName `
        -AutoSize

Write-Host ""
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "256KB BIN files : $($files.Count)"
Write-Host "Valid images     : $($validResults.Count)"
Write-Host "Unique hashes    : $($uniqueValid.Count)"
Write-Host "HINK213-CLOCK    : $($preferred.Count)"

if ($preferred.Count -eq 1) {
    Write-Host ""
    Write-Host "UNIQUE CANDIDATE FOUND" -ForegroundColor Green
    $preferred[0] |
        Format-List `
            SHA256,
            PayloadSize,
            PayloadCRC,
            Endian,
            Names,
            FullName
}
elseif ($preferred.Count -gt 1) {
    Write-Host ""
    Write-Host "MULTIPLE CANDIDATES - STOP" -ForegroundColor Yellow

    $preferred |
        Format-List `
            SHA256,
            PayloadSize,
            PayloadCRC,
            Endian,
            Names,
            FullName
}
else {
    Write-Host ""
    Write-Host "NO HINK213-CLOCK CANDIDATE FOUND" -ForegroundColor Yellow

    $uniqueValid |
        Format-List `
            SHA256,
            PayloadSize,
            PayloadCRC,
            Endian,
            Names,
            FullName
}
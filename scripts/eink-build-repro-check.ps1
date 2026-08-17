[CmdletBinding()]
param(
    [string]$ProfilePath = (Join-Path $PSScriptRoot '..\tools\harness\eink-profile.json')
)

$ErrorActionPreference = 'Stop'

function Write-Blocked {
    param([Parameter(Mandatory = $true)][string]$Reason)
    Write-Output 'EINK HARNESS: BLOCKED'
    Write-Output 'ACTION: BUILD-REPRO-CHECK'
    Write-Output "REASON: $Reason"
}

function Invoke-GitText {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git @Arguments 2>$null | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }
    if ($exitCode -ne 0) { return $null }
    return ($output -join "`n").Trim()
}

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Invoke-BuildAndSnapshot {
    param(
        [Parameter(Mandatory = $true)][int]$Index,
        [Parameter(Mandatory = $true)][string]$EvidenceDir,
        [Parameter(Mandatory = $true)]$Profile
    )

    $runner = Join-Path $PSScriptRoot 'eink.ps1'
    $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner build 2>&1 | ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE
    [System.IO.File]::WriteAllLines(
        (Join-Path $EvidenceDir "build-$Index.output.txt"),
        $output,
        [System.Text.UTF8Encoding]::new($false)
    )

    if ($exitCode -ne 0 -or -not ($output -match '^NEXT_STATE: RAW_FIRMWARE_VERIFIED$')) {
        throw "BUILD_${Index}_FAILED"
    }

    $rawPath = [string]$Profile.toolchain.rawBin
    if (-not (Test-Path -LiteralPath $rawPath -PathType Leaf)) {
        throw "BUILD_${Index}_RAW_BIN_MISSING"
    }

    $snapshot = Join-Path $EvidenceDir "build-$Index.bin"
    Copy-Item -LiteralPath $rawPath -Destination $snapshot -Force
    $file = Get-Item -LiteralPath $snapshot
    $hash = Get-Sha256Hex -Path $snapshot

    return [pscustomobject]@{
        Index = $Index
        Path = $snapshot
        Size = [int64]$file.Length
        Sha256 = $hash
    }
}

$profile = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json
$expectedWorkspace = [System.IO.Path]::GetFullPath([string]$profile.workspace.canonicalPath).TrimEnd('\')
$actualWorkspace = [System.IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\')
if (-not [string]::Equals($actualWorkspace, $expectedWorkspace, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Output 'SAI PROJECT/WORKSPACE'
    exit 1
}

$gitRoot = Invoke-GitText -Arguments @('rev-parse', '--show-toplevel')
if ([string]::IsNullOrWhiteSpace($gitRoot) -or
    -not [string]::Equals(([System.IO.Path]::GetFullPath($gitRoot).TrimEnd('\')), $expectedWorkspace, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Output 'SAI PROJECT/WORKSPACE'
    exit 1
}

$origin = Invoke-GitText -Arguments @('remote', 'get-url', 'origin')
if ($origin -ne [string]$profile.workspace.origin) {
    Write-Blocked -Reason 'WRONG_REMOTE'
    exit 1
}

$trackedDirty = @(& git status --porcelain=v1 --untracked-files=all 2>$null | Where-Object { $_ -and -not $_.StartsWith('?? ') })
if ($trackedDirty.Count -gt 0) {
    Write-Blocked -Reason 'DIRTY_TRACKED_TREE'
    $trackedDirty | ForEach-Object { Write-Output "DIRTY: $_" }
    exit 1
}

$branch = Invoke-GitText -Arguments @('branch', '--show-current')
$head = Invoke-GitText -Arguments @('rev-parse', 'HEAD')
$root = Join-Path $expectedWorkspace '_incoming\EINK_HARNESS_BUILD_REPRO'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$evidenceDir = Join-Path $root $stamp
[void](New-Item -ItemType Directory -Path $evidenceDir -Force)
$summaryPath = Join-Path $evidenceDir 'build-repro.txt'

try {
    Write-Output 'EINK HARNESS v0.7 BUILD REPRODUCIBILITY CHECK'
    Write-Output 'This is NON-DESTRUCTIVE: two clean firmware builds only; no SPI burn.'
    Write-Output 'BUILD 1/2...'
    $first = Invoke-BuildAndSnapshot -Index 1 -EvidenceDir $evidenceDir -Profile $profile
    Write-Output "BUILD1_SIZE: $($first.Size)"
    Write-Output "BUILD1_SHA256: $($first.Sha256)"

    Write-Output 'BUILD 2/2...'
    $second = Invoke-BuildAndSnapshot -Index 2 -EvidenceDir $evidenceDir -Profile $profile
    Write-Output "BUILD2_SIZE: $($second.Size)"
    Write-Output "BUILD2_SHA256: $($second.Sha256)"

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('ACTION: BUILD-REPRO-CHECK')
    $lines.Add("BRANCH: $branch")
    $lines.Add("HEAD: $head")
    $lines.Add("BUILD1_SIZE: $($first.Size)")
    $lines.Add("BUILD1_SHA256: $($first.Sha256)")
    $lines.Add("BUILD2_SIZE: $($second.Size)")
    $lines.Add("BUILD2_SHA256: $($second.Sha256)")

    if ($first.Size -ne $second.Size -or $first.Sha256 -ne $second.Sha256) {
        $a = [System.IO.File]::ReadAllBytes($first.Path)
        $b = [System.IO.File]::ReadAllBytes($second.Path)
        $limit = [Math]::Min($a.Length, $b.Length)
        $diffCount = 0
        $firstOffsets = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $limit; $i++) {
            if ($a[$i] -ne $b[$i]) {
                $diffCount++
                if ($firstOffsets.Count -lt 32) {
                    $firstOffsets.Add(('0x{0:X6}:{1:X2}->{2:X2}' -f $i, $a[$i], $b[$i]))
                }
            }
        }
        $diffCount += [Math]::Abs($a.Length - $b.Length)
        $lines.Add("DIFF_BYTES: $diffCount")
        $lines.Add("FIRST_DIFFS: $($firstOffsets -join ', ')")
        $lines.Add('NEXT_STATE: BUILD_REPRODUCIBILITY_BLOCKED')
        [System.IO.File]::WriteAllLines($summaryPath, $lines, [System.Text.UTF8Encoding]::new($false))

        Write-Blocked -Reason 'NONDETERMINISTIC_RAW_FIRMWARE'
        Write-Output "DIFF_BYTES: $diffCount"
        Write-Output "FIRST_DIFFS: $($firstOffsets -join ', ')"
        Write-Output "EVIDENCE_DIR: $evidenceDir"
        Write-Output "EVIDENCE_FILE: $summaryPath"
        Write-Output 'NEXT_STATE: BUILD_REPRODUCIBILITY_BLOCKED'
        exit 2
    }

    $lines.Add('DIFF_BYTES: 0')
    $lines.Add('NEXT_STATE: BUILD_REPRODUCIBILITY_VERIFIED')
    [System.IO.File]::WriteAllLines($summaryPath, $lines, [System.Text.UTF8Encoding]::new($false))

    Write-Output 'EINK HARNESS: PASS'
    Write-Output 'ACTION: BUILD-REPRO-CHECK'
    Write-Output 'DIFF_BYTES: 0'
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    Write-Output "EVIDENCE_FILE: $summaryPath"
    Write-Output 'NEXT_STATE: BUILD_REPRODUCIBILITY_VERIFIED'
    exit 0
}
catch {
    $reason = $_.Exception.Message
    [System.IO.File]::WriteAllLines(
        $summaryPath,
        @('ACTION: BUILD-REPRO-CHECK', "BRANCH: $branch", "HEAD: $head", "REASON: $reason", 'NEXT_STATE: BUILD_REPRODUCIBILITY_BLOCKED'),
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Blocked -Reason $reason
    Write-Output "EVIDENCE_DIR: $evidenceDir"
    Write-Output "EVIDENCE_FILE: $summaryPath"
    Write-Output 'NEXT_STATE: BUILD_REPRODUCIBILITY_BLOCKED'
    exit 1
}

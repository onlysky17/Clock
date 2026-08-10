[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RawBinPath,
    [string]$PackedBinPath,
    [switch]$RequirePacked,
    [string]$ProfilePath = (Join-Path $PSScriptRoot 'eink-profile.json')
)

$ErrorActionPreference = 'Stop'
$profile = Get-Content -LiteralPath $ProfilePath -Raw | ConvertFrom-Json
$errors = [System.Collections.Generic.List[string]]::new()

function Get-ArtifactInfo {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{ path = $item.FullName; size_bytes = $item.Length }
}

$raw = Get-ArtifactInfo $RawBinPath
if ($null -eq $raw) {
    $errors.Add('RAW_BIN_MISSING')
} elseif ($raw.size_bytes -gt [int64]$profile.artifactPolicy.rawBinMaxBytes) {
    $errors.Add('RAW_BIN_EXCEEDS_65528')
}

$packed = Get-ArtifactInfo $PackedBinPath
if ($RequirePacked -and $null -eq $packed) {
    $errors.Add('PACKED_SPI_BIN_MISSING')
} elseif ($null -ne $packed -and $packed.size_bytes -ne [int64]$profile.artifactPolicy.packedSpiBytes) {
    $errors.Add('PACKED_SPI_SIZE_INVALID')
}

$result = [ordered]@{
    result = if ($errors.Count -eq 0) { 'PASS' } else { 'FAIL' }
    errors = @($errors)
    raw = $raw
    packed = $packed
    raw_max_bytes = [int64]$profile.artifactPolicy.rawBinMaxBytes
    packed_expected_bytes = [int64]$profile.artifactPolicy.packedSpiBytes
}
$result | ConvertTo-Json -Depth 4
if ($errors.Count -gt 0) { exit 1 }

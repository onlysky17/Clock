param(
  [Parameter(Mandatory=$true)][string]$InBin,
  [Parameter(Mandatory=$true)][string]$OutBin,
  [int]$Size = 262144
)

if (!(Test-Path $InBin)) {
  Write-Host "ERROR: input not found: $InBin" -ForegroundColor Red
  exit 1
}

$data = [System.IO.File]::ReadAllBytes($InBin)
if ($data.Length -gt $Size) {
  Write-Host "ERROR: input size $($data.Length) > target $Size" -ForegroundColor Red
  exit 1
}

$out = New-Object byte[] $Size
for ($i=0; $i -lt $Size; $i++) { $out[$i] = 0xFF }
[Array]::Copy($data, 0, $out, 0, $data.Length)
[System.IO.File]::WriteAllBytes($OutBin, $out)

$hash = Get-FileHash $OutBin -Algorithm SHA256
Write-Host "OK padded:"
Write-Host "  In : $InBin"
Write-Host "  In size : $($data.Length)"
Write-Host "  Out: $OutBin"
Write-Host "  Out size: $Size"
Write-Host "  SHA256: $($hash.Hash)"

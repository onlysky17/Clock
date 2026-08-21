[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 5175
)

$ErrorActionPreference = 'Stop'

$repoRoot = (
    Resolve-Path (
        Join-Path $PSScriptRoot '..'
    )
).Path

$serverPath = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$url = "http://127.0.0.1:$Port/"

if (-not (Test-Path -LiteralPath $serverPath -PathType Leaf)) {
    Write-Output 'HARNESS CONTROL CENTER: BLOCKED'
    Write-Output 'REASON: SERVER_SCRIPT_MISSING'
    exit 1
}

function Test-ControlCenter {
    try {
        $status = Invoke-RestMethod `
            -Uri ($url + 'api/status') `
            -Method Get `
            -TimeoutSec 1

        return (
            [string]$status.hubId -eq 'harness-control-center' -and
            [string]$status.version -eq '0.3' -and
            @($status.projects.id) -contains 'eink'
        )
    }
    catch {
        return $false
    }
}

if (Test-ControlCenter) {
    Start-Process $url

    Write-Output 'HARNESS CONTROL CENTER: PASS'
    Write-Output 'RESULT: ALREADY_RUNNING'
    Write-Output "URL: $url"
    exit 0
}

$arguments = @(
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    "`"$serverPath`"",
    '-Port',
    [string]$Port,
    '-NoBrowser'
)

$process = Start-Process `
    -FilePath 'powershell.exe' `
    -ArgumentList $arguments `
    -WindowStyle Minimized `
    -PassThru

$ready = $false

for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 500

    if ($process.HasExited) {
        break
    }

    if (Test-ControlCenter) {
        $ready = $true
        break
    }
}

if (-not $ready) {
    Write-Output 'HARNESS CONTROL CENTER: BLOCKED'
    Write-Output 'REASON: SERVER_START_FAILED'
    Write-Output "PROCESS_ID: $($process.Id)"
    exit 1
}

Start-Process $url

Write-Output 'HARNESS CONTROL CENTER: PASS'
Write-Output "URL: $url"
Write-Output "SERVER_PID: $($process.Id)"
Write-Output 'BIND: 127.0.0.1 ONLY'
Write-Output 'NEXT_STATE: CONTROL_CENTER_RUNNING'

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (
    Resolve-Path (
        Join-Path $PSScriptRoot '..'
    )
).Path

$launcher = Join-Path $repoRoot 'scripts\eink-control-center.ps1'
$server = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$index = Join-Path $repoRoot 'tools\harness\control-center\index.html'
$registry = Join-Path $repoRoot 'tools\harness\control-center\projects.json'

foreach ($path in @($launcher, $server, $index, $registry)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing required file: $path"
    }
}

foreach ($scriptPath in @($launcher, $server)) {
    $tokens = $null
    $errors = $null

    [void][Management.Automation.Language.Parser]::ParseFile(
        $scriptPath,
        [ref]$tokens,
        [ref]$errors
    )

    if (@($errors).Count -gt 0) {
        throw (
            "PowerShell syntax error in $scriptPath`n" +
            (
                @($errors) |
                ForEach-Object { $_.Message }
            ) -join "`n"
        )
    }
}

$utf8Strict = New-Object Text.UTF8Encoding($false, $true)
$serverText = [IO.File]::ReadAllText($server, $utf8Strict)
$indexText = [IO.File]::ReadAllText($index, $utf8Strict)
$launcherText = [IO.File]::ReadAllText($launcher, $utf8Strict)
$registryText = [IO.File]::ReadAllText($registry, $utf8Strict)

foreach ($marker in @(
    '[Net.IPAddress]::Loopback',
    '/api/status',
    '/api/projects/',
    'Get-HubStatus',
    'Get-ElectronicStatus',
    'Invoke-HarnessCoreRequest',
    'Invoke-ElectronicCoreAction',
    'Test-ProjectActionAllowed',
    '/api/state',
    '/api/task/create',
    '/api/evidence/upload',
    '/api/task/run',
    '/api/task/recover',
    '/api/review',
    '/api/project/rediscover',
    '/api/core/restart',
    '/api/prepare',
    '/api/burn',
    '/api/shutdown',
    'X-Eink-Control-Token',
    'control-center-lock.json',
    'control-center-prepare-state.json',
    'eink-control-center-prepare-trust-v1',
    'LATEST_PREPARE_TRUST_STATE_MISSING_NO_FALLBACK',
    'Get-WorkspaceFingerprint',
    'workspaceFingerprint',
    'packedSha256',
    'PREPARE_PASS_LOCKED_ARTIFACT',
    'PREPARE_PASS_TRUST_NOT_DURABLE_BURN_DISABLED',
    'Get-ValidBurnVerification',
    'Get-ApprovedFilesFingerprint',
    'Invoke-PhysicalPassAction',
    'Invoke-PhysicalFailAction',
    'New-ValidatedStateBackup',
    "@('add', '--') + `$approved",
    'AUTO_MERGE: DISABLED',
    'eink-spi-burn.ps1',
    'OWNER_BURN_CONFIRMATION_REQUIRED'
)) {
    if (-not $serverText.Contains($marker)) {
        throw "Server marker missing: $marker"
    }
}

if ($serverText -match 'Access-Control-Allow-Origin\s*:\s*\*') {
    throw 'Wildcard CORS must not be enabled.'
}

if (
    $serverText.Contains('$Body.command') -or
    $serverText.Contains('$Body.path')
) {
    throw 'Browser-provided command/path fields are forbidden.'
}

foreach ($marker in @(
    'projectTabs',
    'electronicView',
    'PAUSED / READ-ONLY',
    'CREATE & RUN',
    'FAIL & AUTO FIX',
    'OWNER PASS',
    'PHYSICAL PASS',
    'PHYSICAL FAIL',
    'OPEN PR',
    'prepareButton',
    'burnButton',
    'stateBadge',
    'artifactSha',
    'Live Log',
    '/api/projects/eink/actions/prepare',
    '/api/projects/eink/actions/burn'
)) {
    if (-not $indexText.Contains($marker)) {
        throw "UI marker missing: $marker"
    }
}

$registryObject = $registryText | ConvertFrom-Json

if (
    [int]$registryObject.version -ne 2 -or
    @($registryObject.projects.id) -notcontains 'eink' -or
    @($registryObject.projects.id) -notcontains 'electronic'
) {
    throw 'Multiproject registry is incomplete.'
}

$einkProfile = @(
    $registryObject.projects |
    Where-Object { [string]$_.id -eq 'eink' }
) | Select-Object -First 1

if (
    [string]$einkProfile.finalize.taskId -ne
        'EINK-HARNESS-CONTROL-CENTER-V0.3-FINALIZE' -or
    @($einkProfile.finalize.approvedFiles).Count -ne 6 -or
    @($einkProfile.actions.id) -notcontains 'physical-pass' -or
    @($einkProfile.actions.id) -notcontains 'physical-fail'
) {
    throw 'EINK v0.3 finalize profile is invalid.'
}

if (
    $serverText -match '(?im)git\s+add\s+\.' -or
    $serverText.Contains("@('add', '.')")
) {
    throw 'Broad git add is forbidden in finalize path.'
}

$electronicProfile = @(
    $registryObject.projects |
    Where-Object { [string]$_.id -eq 'electronic' }
) | Select-Object -First 1

if (
    -not $electronicProfile.brainOptional -or
    -not [bool]$electronicProfile.paused -or
    -not [bool]$electronicProfile.readOnly -or
    [string]$electronicProfile.adapter -ne 'harness-core' -or
    [string]$electronicProfile.core.baseUrl -ne 'http://127.0.0.1:5174'
) {
    throw 'Electronic Harness Core adapter profile is invalid.'
}

if (@($electronicProfile.actions).Count -ne 0) {
    throw 'Electronic PAUSED profile must expose no actions.'
}

foreach ($text in @($serverText, $indexText, $launcherText, $registryText)) {
    $mojibakeSmartPunctuation = (
        ([char]0x00E2).ToString() +
        ([char]0x20AC).ToString()
    )

    if (
        $text.Contains([char]0x00C3) -or
        $text.Contains([char]0x00C2) -or
        $text.Contains($mojibakeSmartPunctuation) -or
        $text.Contains([char]0xFFFD)
    ) {
        throw 'UTF-8/mojibake validation failed.'
    }
}

if (-not $launcherText.Contains('127.0.0.1')) {
    throw 'Launcher must use loopback URL.'
}

$port = Get-Random -Minimum 19000 -Maximum 29000
$url = "http://127.0.0.1:$port/"

$arguments = @(
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    "`"$server`"",
    '-Port',
    [string]$port,
    '-NoBrowser'
)

$process = $null

try {
    $process = Start-Process `
        -FilePath 'powershell.exe' `
        -ArgumentList $arguments `
        -WindowStyle Hidden `
        -PassThru

    $status = $null

    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 250

        if ($process.HasExited) {
            break
        }

        try {
            $status = Invoke-RestMethod `
                -Uri ($url + 'api/status') `
                -Method Get `
                -TimeoutSec 1

            break
        }
        catch {
        }
    }

    if (-not $status) {
        throw 'Control Center status API did not start.'
    }

    if (
        [string]$status.hubId -ne 'harness-control-center' -or
        [string]$status.version -ne '0.4' -or
        @($status.projects.id) -notcontains 'eink' -or
        @($status.projects.id) -notcontains 'electronic'
    ) {
        throw 'Unexpected multiproject Hub status.'
    }

    if ([string]::IsNullOrWhiteSpace([string]$status.sessionToken)) {
        throw 'Session token missing.'
    }

    $page = Invoke-WebRequest `
        -Uri $url `
        -UseBasicParsing `
        -TimeoutSec 2

    if (
        $page.StatusCode -ne 200 -or
        -not $page.Content.Contains('Harness Control Center')
    ) {
        throw 'Control Center HTML route failed.'
    }

    $headers = @{
        'X-Eink-Control-Token' = [string]$status.sessionToken
    }

    $einkStatus = Invoke-RestMethod `
        -Uri ($url + 'api/projects/eink/status') `
        -Method Get `
        -TimeoutSec 3

    if (
        [string]$einkStatus.adapter -ne 'eink' -or
        [bool]$einkStatus.readOnly -or
        [bool]$einkStatus.physicalReviewEnabled
    ) {
        throw 'EINK adapter status failed.'
    }

    if (
        $einkStatus.prepareTrust -and
        [string]$einkStatus.prepareTrust.status -ne 'PASS' -and
        (
            [bool]$einkStatus.readyToBurn -or
            $null -ne $einkStatus.artifact
        )
    ) {
        throw 'EINK stale artifact fallback must remain disabled.'
    }

    $electronicStatus = Invoke-RestMethod `
        -Uri ($url + 'api/projects/electronic/status') `
        -Method Get `
        -TimeoutSec 5

    if (
        [string]$electronicStatus.adapter -ne 'harness-core' -or
        -not [bool]$electronicStatus.readOnly -or
        -not [bool]$electronicStatus.paused -or
        @($electronicStatus.actions).Count -ne 0
    ) {
        throw 'Electronic paused read-only reference status failed.'
    }

    $arbitraryActionBlocked = $false

    try {
        [void](Invoke-RestMethod `
            -Uri ($url + 'api/projects/electronic/actions/run-command') `
            -Method Post `
            -Headers $headers `
            -ContentType 'application/json' `
            -Body '{"command":"whoami","path":"C:\\"}')
    }
    catch {
        $arbitraryActionBlocked = (
            [int]$_.Exception.Response.StatusCode -eq 403
        )
    }

    if (-not $arbitraryActionBlocked) {
        throw 'Arbitrary browser action was not blocked.'
    }

    $missingTokenBlocked = $false

    try {
        [void](Invoke-RestMethod `
            -Uri ($url + 'api/projects/eink/actions/burn') `
            -Method Post `
            -ContentType 'application/json' `
            -Body '{}')
    }
    catch {
        $missingTokenBlocked = (
            [int]$_.Exception.Response.StatusCode -eq 403
        )
    }

    if (-not $missingTokenBlocked) {
        throw 'Write action without session token was not blocked.'
    }

    $headBeforeGateTest = (& git -C $repoRoot rev-parse HEAD).Trim()
    $physicalPassBlocked = Invoke-RestMethod `
        -Uri ($url + 'api/projects/eink/actions/physical-pass') `
        -Method Post `
        -Headers $headers `
        -ContentType 'application/json' `
        -Body '{"feedback":"must remain gated","evidence":[]}'

    if (
        [string]$physicalPassBlocked.lastResult -ne 'BLOCKED' -or
        [bool]$physicalPassBlocked.physicalReviewEnabled -or
        (& git -C $repoRoot rev-parse HEAD).Trim() -ne $headBeforeGateTest
    ) {
        throw 'Physical PASS was not safely gated before SPI_BURN_VERIFIED.'
    }

    $shutdown = Invoke-RestMethod `
        -Uri ($url + 'api/shutdown') `
        -Method Post `
        -Headers $headers `
        -ContentType 'application/json' `
        -Body '{}'

    if ([string]$shutdown.result -ne 'STOPPING') {
        throw 'Shutdown API failed.'
    }

    Write-Output 'HARNESS CONTROL CENTER V0.4 SMOKE: PASS'
    Write-Output 'LOOPBACK_BIND: PASS'
    Write-Output 'STATUS_API: PASS'
    Write-Output 'MULTIPROJECT_REGISTRY: PASS'
    Write-Output 'EINK_ADAPTER: PASS'
    Write-Output 'EINK_STALE_ARTIFACT_FALLBACK: BLOCKED'
    Write-Output 'PHYSICAL_GATE_BEFORE_BURN: BLOCKED'
    Write-Output 'ELECTRONIC_REFERENCE_TAB: PAUSED_READ_ONLY'
    Write-Output 'ELECTRONIC_ACTIONS: BLOCKED'
    Write-Output 'ARBITRARY_ACTION: BLOCKED'
    Write-Output 'STATIC_UI: PASS'
    Write-Output 'UTF8_UI: PASS'
    Write-Output 'WRITE_TOKEN: PRESENT'
    Write-Output 'MISSING_WRITE_TOKEN: BLOCKED'
    Write-Output 'WILDCARD_CORS: DISABLED'
    Write-Output 'DESTRUCTIVE_BURN: NOT PERFORMED'
}
finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process `
            -Id $process.Id `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$server = Join-Path $repoRoot 'tools\harness\control-center\server.ps1'
$registry = Join-Path $repoRoot 'tools\harness\control-center\projects.json'
$registryObject = [IO.File]::ReadAllText(
    $registry,
    (New-Object Text.UTF8Encoding($false, $true))
) | ConvertFrom-Json
$einkProfile = @(
    $registryObject.projects |
    Where-Object { [string]$_.id -eq 'eink' }
) | Select-Object -First 1
$approved = @(
    $einkProfile.finalize.approvedFiles |
    ForEach-Object { ([string]$_).Replace('\', '/') } |
    Sort-Object
)

if (
    [string]$einkProfile.finalize.taskId -ne
        'EINK-HARNESS-CONTROL-CENTER-V0.3-FINALIZE' -or
    $approved.Count -ne 6
) {
    throw 'Acceptance requires the exact v0.3 finalize profile.'
}

function Invoke-TestGit {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Workspace,

        [Parameter(Mandatory=$true)]
        [string[]]$Arguments
    )

    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git -C $Workspace @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }

    if ($exitCode -ne 0) {
        throw "git $($Arguments -join ' ') failed: $($output -join ' ')"
    }

    @($output | ForEach-Object { $_.ToString() })
}

function Write-Utf8Text {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$Text
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }
    [IO.File]::WriteAllText(
        $Path,
        $Text,
        (New-Object Text.UTF8Encoding($false))
    )
}

function Invoke-JsonPost {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,

        [Parameter(Mandatory=$true)]
        [string]$Token,

        [Parameter(Mandatory=$true)]
        $Body
    )

    Invoke-RestMethod `
        -Uri $Url `
        -Method Post `
        -Headers @{ 'X-Eink-Control-Token' = $Token } `
        -ContentType 'application/json' `
        -Body ($Body | ConvertTo-Json -Depth 8) `
        -TimeoutSec 30
}

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $tempBase (
    'eink-harness-v03-' + [Guid]::NewGuid().ToString('N')
)
$workspace = Join-Path $testRoot 'workspace'
$remote = Join-Path $testRoot 'remote.git'
$fixturePath = Join-Path $testRoot 'post-burn-fixture.json'
$branch = 'task-d/acceptance-fixture'
$port = Get-Random -Minimum 30000 -Maximum 39000
$url = "http://127.0.0.1:$port/"
$process = $null

try {
    [void](New-Item -ItemType Directory -Path $workspace -Force)

    [void](Invoke-TestGit -Workspace $workspace -Arguments @('init', '-b', $branch))
    [void](Invoke-TestGit -Workspace $workspace -Arguments @('config', 'user.name', 'Harness Acceptance'))
    [void](Invoke-TestGit -Workspace $workspace -Arguments @('config', 'user.email', 'harness-acceptance@example.invalid'))

    Write-Utf8Text -Path (Join-Path $workspace '.gitignore') -Text "_incoming/`n"
    Write-Utf8Text `
        -Path (Join-Path $workspace 'tools/harness/eink-profile.json') `
        -Text '{"artifactPolicy":{"packedSpiBytes":262144},"spiBurn":{"confirmationToken":"FIXTURE_ONLY"}}'

    foreach ($relativePath in $approved) {
        Write-Utf8Text `
            -Path (Join-Path $workspace $relativePath) `
            -Text "baseline $relativePath`n"
    }

    Write-Utf8Text -Path (Join-Path $workspace 'outside-tracked.txt') -Text "unchanged`n"
    [void](Invoke-TestGit -Workspace $workspace -Arguments @('add', '--', '.gitignore', 'tools/harness/eink-profile.json', 'outside-tracked.txt'))
    [void](Invoke-TestGit -Workspace $workspace -Arguments (@('add', '--') + $approved))
    [void](Invoke-TestGit -Workspace $workspace -Arguments @('commit', '-m', 'acceptance baseline'))

    [void](Invoke-TestGit `
        -Workspace $testRoot `
        -Arguments @('init', '--bare', $remote))
    [void](Invoke-TestGit -Workspace $workspace -Arguments @('remote', 'add', 'origin', $remote))
    [void](Invoke-TestGit -Workspace $workspace -Arguments @('push', '-u', 'origin', $branch))

    $baselineHead = @(
        Invoke-TestGit -Workspace $workspace -Arguments @('rev-parse', 'HEAD')
    )[-1].Trim()

    foreach ($relativePath in $approved) {
        Write-Utf8Text `
            -Path (Join-Path $workspace $relativePath) `
            -Text "v0.3 accepted change $relativePath`n"
    }

    Write-Utf8Text `
        -Path (Join-Path $workspace 'do-not-stage-owner-file.txt') `
        -Text "must remain untracked`n"

    $artifactPath = Join-Path $workspace '_incoming/fixture/packed.bin'
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $artifactPath) -Force)
    [IO.File]::WriteAllBytes($artifactPath, [byte[]](0..255))
    Write-Utf8Text -Path $fixturePath -Text (
        [ordered]@{
            schema = 'eink-control-center-post-burn-fixture-v1'
            simulated = $true
            autoBindCurrentWorkspace = $true
            artifactPath = $artifactPath
        } | ConvertTo-Json
    )

    $productionPortGuard = Start-Process `
        -FilePath 'powershell.exe' `
        -ArgumentList @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', $server,
            '-Port', '5175',
            '-NoBrowser',
            '-AcceptanceMode',
            '-AcceptanceWorkspace', $workspace,
            '-AcceptanceFixturePath', $fixturePath
        ) `
        -WindowStyle Hidden `
        -Wait `
        -PassThru

    if ($productionPortGuard.ExitCode -eq 0) {
        throw 'Acceptance fixture was not rejected on production port 5175.'
    }

    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $server,
        '-Port', [string]$port,
        '-NoBrowser',
        '-AcceptanceMode',
        '-AcceptanceWorkspace', $workspace,
        '-AcceptanceFixturePath', $fixturePath
    )
    $process = Start-Process `
        -FilePath 'powershell.exe' `
        -ArgumentList $arguments `
        -WindowStyle Hidden `
        -PassThru

    $status = $null
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 250
        if ($process.HasExited) { break }
        try {
            $status = Invoke-RestMethod `
                -Uri ($url + 'api/projects/eink/status') `
                -TimeoutSec 1
            break
        }
        catch {
        }
    }

    if (
        -not $status -or
        [string]$status.state -ne 'SPI_BURN_VERIFIED' -or
        -not [bool]$status.physicalReviewEnabled -or
        -not [bool]$status.burnVerification.simulated
    ) {
        throw 'Simulated post-burn fixture did not enter the isolated Owner gate.'
    }

    $fingerprintProbePath = Join-Path $workspace $approved[0]
    $fingerprintProbeText = [IO.File]::ReadAllText(
        $fingerprintProbePath,
        [Text.Encoding]::UTF8
    )
    Write-Utf8Text `
        -Path $fingerprintProbePath `
        -Text ($fingerprintProbeText + "post-burn mutation probe`n")
    $mutatedStatus = Invoke-RestMethod `
        -Uri ($url + 'api/projects/eink/status') `
        -TimeoutSec 3

    if ([bool]$mutatedStatus.physicalReviewEnabled) {
        throw 'Approved task file mutation did not invalidate the physical gate.'
    }

    Write-Utf8Text -Path $fingerprintProbePath -Text $fingerprintProbeText
    $restoredStatus = Invoke-RestMethod `
        -Uri ($url + 'api/projects/eink/status') `
        -TimeoutSec 3

    if (-not [bool]$restoredStatus.physicalReviewEnabled) {
        throw 'Physical gate did not recover after restoring the exact approved file.'
    }

    $token = [string]$status.sessionToken
    $fail = Invoke-JsonPost `
        -Url ($url + 'api/projects/eink/actions/physical-fail') `
        -Token $token `
        -Body @{
            feedback = 'Acceptance fixture physical fail'
            evidence = @()
        }

    $headAfterFail = @(
        Invoke-TestGit -Workspace $workspace -Arguments @('rev-parse', 'HEAD')
    )[-1].Trim()
    $stagedAfterFail = @(Invoke-TestGit -Workspace $workspace -Arguments @('diff', '--cached', '--name-only'))
    $remoteAfterFail = @(
        & git --git-dir=$remote rev-parse "refs/heads/$branch" 2>&1
    )[-1].ToString().Trim()

    if (
        [string]$fail.state -ne 'PHYSICAL_FAIL' -or
        [bool]$fail.ownerFinalize.resolved -or
        $headAfterFail -ne $baselineHead -or
        $stagedAfterFail.Count -ne 0 -or
        $remoteAfterFail -ne $baselineHead
    ) {
        throw 'PHYSICAL FAIL changed Git state or resolved the task.'
    }

    $pass = Invoke-JsonPost `
        -Url ($url + 'api/projects/eink/actions/physical-pass') `
        -Token $token `
        -Body @{
            feedback = 'Acceptance fixture physical pass'
            evidence = @()
        }

    $finalHead = @(
        Invoke-TestGit -Workspace $workspace -Arguments @('rev-parse', 'HEAD')
    )[-1].Trim()
    $committedFiles = @(
        Invoke-TestGit `
            -Workspace $workspace `
            -Arguments @('diff-tree', '--no-commit-id', '--name-only', '-r', 'HEAD') |
        Where-Object { $_ } |
        Sort-Object
    )
    $remoteHead = @(
        & git --git-dir=$remote rev-parse "refs/heads/$branch" 2>&1
    )[-1].ToString().Trim()
    $untracked = @(
        Invoke-TestGit `
            -Workspace $workspace `
            -Arguments @('ls-files', '--others', '--exclude-standard')
    )
    $scopeDiff = @(Compare-Object -ReferenceObject $approved -DifferenceObject $committedFiles)
    $backupExists = (
        -not [string]::IsNullOrWhiteSpace(
            [string]$pass.ownerFinalize.backupPath
        ) -and
        (Test-Path `
            -LiteralPath $pass.ownerFinalize.backupPath `
            -PathType Container)
    )

    if (
        [string]$pass.state -ne 'OPEN_PR' -or
        [string]$pass.ownerFinalize.decision -ne 'PHYSICAL_PASS' -or
        -not [bool]$pass.ownerFinalize.resolved -or
        [string]$pass.ownerFinalize.prState -ne 'OPEN' -or
        [string]$pass.ownerFinalize.prUrl -ne
            'https://example.invalid/eink-harness-acceptance/pull/1' -or
        [string]$pass.ownerFinalize.commitSha -ne $finalHead -or
        $finalHead -eq $baselineHead -or
        $remoteHead -ne $finalHead -or
        $scopeDiff.Count -ne 0 -or
        $untracked -notcontains 'do-not-stage-owner-file.txt' -or
        -not $backupExists
    ) {
        $diagnostic = [ordered]@{
            responseState = [string]$pass.state
            lastResult = [string]$pass.lastResult
            lastLog = [string]$pass.lastLog
            decision = [string]$pass.ownerFinalize.decision
            resolved = [bool]$pass.ownerFinalize.resolved
            prState = [string]$pass.ownerFinalize.prState
            prUrl = [string]$pass.ownerFinalize.prUrl
            commitSha = [string]$pass.ownerFinalize.commitSha
            finalHead = $finalHead
            baselineHead = $baselineHead
            remoteHead = $remoteHead
            committedFiles = $committedFiles
            scopeDiff = $scopeDiff
            untracked = $untracked
            backupPath = [string]$pass.ownerFinalize.backupPath
            backupExists = $backupExists
        }
        throw ('PHYSICAL PASS finalize acceptance failed: ' + (
            $diagnostic | ConvertTo-Json -Depth 6 -Compress
        ))
    }

    $shutdown = Invoke-JsonPost `
        -Url ($url + 'api/shutdown') `
        -Token $token `
        -Body @{}

    if ([string]$shutdown.result -ne 'STOPPING') {
        throw 'Acceptance server shutdown failed.'
    }

    Write-Output 'EINK CONTROL CENTER V0.3 FINALIZE ACCEPTANCE: PASS'
    Write-Output 'SIMULATED_POST_BURN_FIXTURE: ISOLATED'
    Write-Output 'PRODUCTION_PORT_FIXTURE_GUARD: PASS'
    Write-Output 'PRODUCTION_HARDWARE_RESULT: NOT FAKED'
    Write-Output 'POST_BURN_APPROVED_FILE_MUTATION: BLOCKED'
    Write-Output 'PHYSICAL_FAIL_UNRESOLVED: PASS'
    Write-Output 'PHYSICAL_FAIL_GIT_MUTATION: NONE'
    Write-Output 'PHYSICAL_PASS_BACKUP: PASS'
    Write-Output 'EXACT_STAGE_APPROVED_FILES_ONLY: PASS'
    Write-Output 'BROAD_GIT_ADD: FORBIDDEN'
    Write-Output 'COMMIT_LOCAL_FIXTURE: PASS'
    Write-Output 'PUSH_LOCAL_BARE_REMOTE: PASS'
    Write-Output 'OPEN_PR_STATE: PASS'
    Write-Output 'AUTO_MERGE: NOT PERFORMED'
    Write-Output 'AUTO_BURN: NOT PERFORMED'
}
finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }

    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    if (
        $resolvedTestRoot.StartsWith(
            $tempBase,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Split-Path -Leaf $resolvedTestRoot).StartsWith('eink-harness-v03-')
    ) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

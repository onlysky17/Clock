[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runnerPath = Join-Path $repoRoot 'scripts\eink.ps1'
$homeFlashPath = Join-Path $repoRoot 'scripts\eink-home-flash.ps1'
$nextActionPath = Join-Path $repoRoot 'docs\agent\NEXT_ACTION.md'
$testFileName = '.eink-harness-v02-dirty-test.tmp'
$testFilePath = Join-Path $repoRoot $testFileName
$temporaryIndex = Join-Path ([System.IO.Path]::GetTempPath()) ("eink-harness-index-{0}" -f [guid]::NewGuid().ToString('N'))
$temporaryHomeStub = Join-Path ([System.IO.Path]::GetTempPath()) ("eink-home-stub-{0}.ps1" -f [guid]::NewGuid().ToString('N'))
$originalIndexEnvironment = $env:GIT_INDEX_FILE

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Invoke-Runner {
    param([string[]]$Arguments)

    $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runnerPath @Arguments 2>&1 | ForEach-Object { $_.ToString() })
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Text = ($output -join [Environment]::NewLine)
    }
}

try {
    Assert-True (Test-Path -LiteralPath $runnerPath -PathType Leaf) 'Missing canonical runner.'
    Assert-True (Test-Path -LiteralPath $homeFlashPath -PathType Leaf) 'Missing home flash implementation.'
    Assert-True (Test-Path -LiteralPath $nextActionPath -PathType Leaf) 'Missing NEXT_ACTION.md.'

    $runnerSource = Get-Content -LiteralPath $runnerPath -Raw
    Assert-True ($runnerSource -match 'tools\\harness\\workspace-guard\.ps1') 'Runner does not reuse workspace-guard.ps1.'
    Assert-True ($runnerSource -match 'tools\\harness\\task-state\.ps1') 'Runner does not reuse task-state.ps1.'
    Assert-True ($runnerSource -match 'eink-home-flash\.ps1') 'Runner does not delegate HOME-VERIFY.'
    Assert-True ($runnerSource -match "'-Mode', 'VerifyEnv'") 'HOME-VERIFY does not use VerifyEnv.'
    Assert-True ($runnerSource -match "@\('fetch', 'origin'\)") 'SYNC does not fetch origin.'
    Assert-True ($runnerSource -match "@\('switch', 'main'\)") 'SYNC does not switch to main.'
    Assert-True ($runnerSource -match "@\('pull', '--ff-only', 'origin', 'main'\)") 'SYNC does not use ff-only pull.'
    Assert-True ($runnerSource -notmatch '(?i)Start-Process|Invoke-Item|explorer\.exe|ShellExecute|UseShellExecute') 'Runner contains a GUI launch path.'
    Assert-True ($runnerSource -notmatch "'-Mode', 'Pack'") 'Runner must not invoke pack mode.'

    $statusResult = Invoke-Runner -Arguments @('status')
    Assert-True ($statusResult.ExitCode -eq 0) "STATUS failed: $($statusResult.Text)"
    Assert-True ($statusResult.Text -match 'EINK HARNESS: PASS') 'STATUS did not report PASS.'
    Assert-True ($statusResult.Text -match 'ACTION: STATUS') 'STATUS action marker missing.'

    $syncResult = Invoke-Runner -Arguments @('sync', '-DryRun')
    Assert-True ($syncResult.ExitCode -eq 0) "SYNC dry run failed: $($syncResult.Text)"
    Assert-True ($syncResult.Text -match 'SYNC_RESULT: ALREADY_CURRENT_DRY_RUN') 'SYNC dry run was not a current-main no-op.'

    Copy-Item -LiteralPath (Join-Path $repoRoot '.git\index') -Destination $temporaryIndex
    [System.IO.File]::WriteAllText($testFilePath, 'dirty gate test', [System.Text.UTF8Encoding]::new($false))
    $env:GIT_INDEX_FILE = $temporaryIndex
    & git -C $repoRoot add -- $testFileName
    Assert-True ($LASTEXITCODE -eq 0) 'Unable to prepare alternate-index dirty state.'

    $dirtyResult = Invoke-Runner -Arguments @('status')
    Assert-True ($dirtyResult.ExitCode -ne 0) 'STATUS did not block a dirty tracked tree.'
    Assert-True ($dirtyResult.Text -match 'REASON: DIRTY_TRACKED_TREE') 'Dirty tree block reason is incorrect.'

    if ($null -eq $originalIndexEnvironment) {
        Remove-Item Env:GIT_INDEX_FILE -ErrorAction SilentlyContinue
    }
    else {
        $env:GIT_INDEX_FILE = $originalIndexEnvironment
    }

    $nextResult = Invoke-Runner -Arguments @('next')
    Assert-True ($nextResult.ExitCode -ne 0) 'NEXT should stop for Owner selection when unresolved.'
    Assert-True ($nextResult.Text -match 'REASON: OWNER_SELECTION_REQUIRED') 'NEXT unresolved reason is incorrect.'
    Assert-True ($nextResult.Text -match 'NEXT_STATE: PAUSED_OWNER_ACTION') 'NEXT unresolved state is incorrect.'

    $stubContent = @'
param([string]$Mode)
if ($Mode -ne 'VerifyEnv') { exit 9 }
Write-Output 'STUB HOME VERIFY: PASS'
exit 0
'@
    [System.IO.File]::WriteAllText($temporaryHomeStub, $stubContent, [System.Text.UTF8Encoding]::new($false))

    $homeResult = Invoke-Runner -Arguments @('home-verify', '-HomeFlashScriptPath', $temporaryHomeStub)
    Assert-True ($homeResult.ExitCode -eq 0) "HOME-VERIFY delegation failed: $($homeResult.Text)"
    Assert-True ($homeResult.Text -match 'HOME_VERIFY: PASS') 'HOME-VERIFY success marker missing.'
    Assert-True ($homeResult.Text -notmatch '(?i)flash|burn|pack') 'HOME-VERIFY output suggests a physical or pack action.'

    Write-Output 'EINK HARNESS V0.2 SMOKE: PASS'
    Write-Output 'STATUS: PASS'
    Write-Output 'SYNC_DRY_RUN: PASS'
    Write-Output 'DIRTY_TRACKED_BLOCK: PASS'
    Write-Output 'NEXT_UNRESOLVED: PASS'
    Write-Output 'HOME_VERIFY_DELEGATION: PASS'
    Write-Output 'NO_FLASH_INVOCATION: PASS'
}
finally {
    if ($null -eq $originalIndexEnvironment) {
        Remove-Item Env:GIT_INDEX_FILE -ErrorAction SilentlyContinue
    }
    else {
        $env:GIT_INDEX_FILE = $originalIndexEnvironment
    }

    foreach ($path in @($testFilePath, $temporaryIndex, $temporaryHomeStub)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }
}

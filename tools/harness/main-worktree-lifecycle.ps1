$ErrorActionPreference = 'Stop'

function Invoke-EinkHarnessLifecycleGit {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string[]]$Arguments
    )

    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(
            & git -c ("safe.directory={0}" -f ([IO.Path]::GetFullPath($RepoRoot))) `
                -C $RepoRoot @Arguments 2>&1 |
                ForEach-Object { $_.ToString() }
        )
        [pscustomobject]@{
            ExitCode = [int]$LASTEXITCODE
            Output = @($output)
        }
    }
    finally {
        $ErrorActionPreference = $previous
    }
}

function Get-EinkHarnessLifecycleGitValue {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [Parameter(Mandatory=$true)][string]$FailureReason
    )

    $result = Invoke-EinkHarnessLifecycleGit -RepoRoot $RepoRoot -Arguments $Arguments
    if ($result.ExitCode -ne 0 -or $result.Output.Count -eq 0) {
        throw $FailureReason
    }
    ([string]$result.Output[-1]).Trim()
}

function Get-EinkHarnessWorktreeRecords {
    param([Parameter(Mandatory=$true)][string]$RepoRoot)

    $result = Invoke-EinkHarnessLifecycleGit `
        -RepoRoot $RepoRoot `
        -Arguments @('worktree','list','--porcelain')
    if ($result.ExitCode -ne 0) { throw 'WORKTREE_LIST_FAILED' }

    $records = New-Object 'Collections.Generic.List[object]'
    $current = $null
    foreach ($line in @($result.Output) + @('')) {
        if ([string]::IsNullOrWhiteSpace([string]$line)) {
            if ($current) {
                $records.Add([pscustomobject]$current)
                $current = $null
            }
            continue
        }
        if ($line.StartsWith('worktree ')) {
            $current = [ordered]@{
                Path = [IO.Path]::GetFullPath($line.Substring(9).Trim())
                Head = ''
                Branch = ''
                Detached = $false
            }
        }
        elseif ($current -and $line.StartsWith('HEAD ')) {
            $current.Head = $line.Substring(5).Trim()
        }
        elseif ($current -and $line.StartsWith('branch ')) {
            $current.Branch = $line.Substring(7).Trim()
        }
        elseif ($current -and $line -eq 'detached') {
            $current.Detached = $true
        }
    }
    @($records | ForEach-Object { $_ })
}

function Get-EinkHarnessLifecycleContext {
    param([Parameter(Mandatory=$true)][string]$RepoRoot)

    $resolved = [IO.Path]::GetFullPath((Resolve-Path $RepoRoot).Path).TrimEnd('\')
    $common = Get-EinkHarnessLifecycleGitValue `
        -RepoRoot $resolved `
        -Arguments @('rev-parse','--git-common-dir') `
        -FailureReason 'GIT_COMMON_DIR_UNAVAILABLE'
    if (-not [IO.Path]::IsPathRooted($common)) {
        $common = Join-Path $resolved $common
    }
    $common = [IO.Path]::GetFullPath($common).TrimEnd('\')
    if ([IO.Path]::GetFileName($common) -ne '.git') {
        throw 'UNSUPPORTED_GIT_COMMON_DIR'
    }
    $canonical = [IO.Path]::GetDirectoryName($common).TrimEnd('\')
    [pscustomobject]@{
        RequestedRoot = $resolved
        CanonicalRoot = $canonical
        CommonGitDir = $common
        RuntimePath = ($canonical + '_HARNESS_RUNTIME')
        RuntimeAdminDir = Join-Path $common (
            'worktrees\' + [IO.Path]::GetFileName($canonical + '_HARNESS_RUNTIME')
        )
        OwnerMarkerPath = Join-Path $common 'eink-harness\worktree-owners\main-runtime.json'
    }
}

function Test-EinkHarnessReservedRuntimeIdentity {
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)]$Record
    )

    if (-not ([string]$Record.Path).Equals(
        [string]$Context.RuntimePath,
        [StringComparison]::OrdinalIgnoreCase
    )) { return $false }
    if (-not (Test-Path -LiteralPath $Context.RuntimePath -PathType Container)) {
        return $false
    }
    $pointer = Join-Path $Context.RuntimePath '.git'
    if (-not (Test-Path -LiteralPath $pointer -PathType Leaf)) { return $false }
    $line = ([IO.File]::ReadAllText($pointer, [Text.Encoding]::UTF8)).Trim()
    if (-not $line.StartsWith('gitdir: ', [StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }
    $actualAdmin = [IO.Path]::GetFullPath($line.Substring(8).Trim()).TrimEnd('\')
    $expectedAdmin = [IO.Path]::GetFullPath($Context.RuntimeAdminDir).TrimEnd('\')
    $actualAdmin.Equals($expectedAdmin, [StringComparison]::OrdinalIgnoreCase)
}

function Read-EinkHarnessRuntimeOwnerMarker {
    param([Parameter(Mandatory=$true)]$Context)

    if (-not (Test-Path -LiteralPath $Context.OwnerMarkerPath -PathType Leaf)) {
        return $null
    }
    try {
        [IO.File]::ReadAllText(
            $Context.OwnerMarkerPath,
            [Text.Encoding]::UTF8
        ) | ConvertFrom-Json
    }
    catch {
        throw 'HARNESS_RUNTIME_OWNER_MARKER_INVALID'
    }
}

function Test-EinkHarnessRuntimeOwnerMarker {
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)]$Marker
    )

    $Marker -and
        [string]$Marker.schema -eq 'eink-harness-runtime-owner-v1' -and
        ([string]$Marker.canonicalRoot).Equals(
            [string]$Context.CanonicalRoot,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        ([string]$Marker.worktreePath).Equals(
            [string]$Context.RuntimePath,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        ([string]$Marker.adminGitDir).Equals(
            [string]$Context.RuntimeAdminDir,
            [StringComparison]::OrdinalIgnoreCase
        )
}

function Write-EinkHarnessRuntimeOwnerMarker {
    param([Parameter(Mandatory=$true)]$Context)

    $parent = Split-Path -Parent $Context.OwnerMarkerPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }
    $marker = [ordered]@{
        schema = 'eink-harness-runtime-owner-v1'
        canonicalRoot = [string]$Context.CanonicalRoot
        worktreePath = [string]$Context.RuntimePath
        adminGitDir = [string]$Context.RuntimeAdminDir
        ownershipBasis = 'RESERVED_PATH_AND_EXACT_GIT_ADMIN_POINTER'
        createdUtc = [DateTime]::UtcNow.ToString('o')
    }
    $temporary = $Context.OwnerMarkerPath + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText(
            $temporary,
            ($marker | ConvertTo-Json -Depth 4),
            [Text.UTF8Encoding]::new($false)
        )
        Move-Item -LiteralPath $temporary -Destination $Context.OwnerMarkerPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
    [pscustomobject]$marker
}

function Invoke-EinkHarnessMainWorktreeLifecycle {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [switch]$FetchOrigin,
        [switch]$AllowLegacyReservedRuntimeAdoption
    )

    $context = Get-EinkHarnessLifecycleContext -RepoRoot $RepoRoot
    $log = New-Object 'Collections.Generic.List[string]'
    $records = @(Get-EinkHarnessWorktreeRecords -RepoRoot $context.CanonicalRoot)
    $runtime = @($records | Where-Object {
        ([string]$_.Path).Equals(
            [string]$context.RuntimePath,
            [StringComparison]::OrdinalIgnoreCase
        )
    })
    if ($runtime.Count -gt 1) { throw 'HARNESS_RUNTIME_WORKTREE_DUPLICATE' }

    $runtimeOwned = $false
    $runtimeDetached = $false
    if ($runtime.Count -eq 1) {
        if (-not (Test-EinkHarnessReservedRuntimeIdentity -Context $context -Record $runtime[0])) {
            throw 'HARNESS_RUNTIME_IDENTITY_MISMATCH'
        }
        $marker = Read-EinkHarnessRuntimeOwnerMarker -Context $context
        if (-not $marker) {
            if (-not $AllowLegacyReservedRuntimeAdoption) {
                throw 'HARNESS_RUNTIME_OWNER_MARKER_MISSING'
            }
            $marker = Write-EinkHarnessRuntimeOwnerMarker -Context $context
            $log.Add('RUNTIME_OWNER_MARKER: ADOPTED_RESERVED_LEGACY_RUNTIME')
        }
        if (-not (Test-EinkHarnessRuntimeOwnerMarker -Context $context -Marker $marker)) {
            throw 'HARNESS_RUNTIME_OWNER_MARKER_MISMATCH'
        }
        $runtimeOwned = $true

        if ([string]$runtime[0].Branch -eq 'refs/heads/main') {
            $dirty = Invoke-EinkHarnessLifecycleGit `
                -RepoRoot $context.RuntimePath `
                -Arguments @('status','--porcelain=v1','--untracked-files=no')
            if ($dirty.ExitCode -ne 0 -or @($dirty.Output | Where-Object { $_ }).Count -gt 0) {
                throw 'HARNESS_RUNTIME_TRACKED_TREE_DIRTY'
            }
            $before = Get-EinkHarnessLifecycleGitValue `
                -RepoRoot $context.RuntimePath `
                -Arguments @('rev-parse','HEAD') `
                -FailureReason 'HARNESS_RUNTIME_HEAD_UNAVAILABLE'
            $detach = Invoke-EinkHarnessLifecycleGit `
                -RepoRoot $context.RuntimePath `
                -Arguments @('switch','--detach','HEAD')
            if ($detach.ExitCode -ne 0) { throw 'HARNESS_RUNTIME_DETACH_FAILED' }
            $after = Get-EinkHarnessLifecycleGitValue `
                -RepoRoot $context.RuntimePath `
                -Arguments @('rev-parse','HEAD') `
                -FailureReason 'HARNESS_RUNTIME_HEAD_UNAVAILABLE'
            if ($before -ne $after) { throw 'HARNESS_RUNTIME_DETACH_CHANGED_HEAD' }
            $runtimeDetached = $true
            $log.Add("RUNTIME_MAIN_RELEASED: $($context.RuntimePath)")
            $records = @(Get-EinkHarnessWorktreeRecords -RepoRoot $context.CanonicalRoot)
        }
        else {
            $log.Add('RUNTIME_MAIN_RELEASED: ALREADY_NOT_ON_MAIN')
        }
    }
    else {
        $log.Add('RUNTIME_WORKTREE: ABSENT')
    }

    if ($FetchOrigin) {
        $fetch = Invoke-EinkHarnessLifecycleGit `
            -RepoRoot $context.CanonicalRoot `
            -Arguments @('fetch','origin')
        if ($fetch.ExitCode -ne 0) { throw 'HARNESS_MAIN_FETCH_ORIGIN_FAILED' }
        $log.Add('FETCH_ORIGIN: PASS')
    }

    $mainHead = Get-EinkHarnessLifecycleGitValue `
        -RepoRoot $context.CanonicalRoot `
        -Arguments @('rev-parse','--verify','refs/heads/main') `
        -FailureReason 'MAIN_REF_MISSING'
    $originMainHead = Get-EinkHarnessLifecycleGitValue `
        -RepoRoot $context.CanonicalRoot `
        -Arguments @('rev-parse','--verify','refs/remotes/origin/main') `
        -FailureReason 'ORIGIN_MAIN_REF_MISSING'
    $mainUpdated = $false
    if ($mainHead -ne $originMainHead) {
        $ancestor = Invoke-EinkHarnessLifecycleGit `
            -RepoRoot $context.CanonicalRoot `
            -Arguments @('merge-base','--is-ancestor',$mainHead,$originMainHead)
        if ($ancestor.ExitCode -ne 0) { throw 'HARNESS_MAIN_NON_FAST_FORWARD' }

        $holders = @($records | Where-Object { [string]$_.Branch -eq 'refs/heads/main' })
        if ($holders.Count -gt 1) { throw 'MAIN_WORKTREE_OWNERSHIP_AMBIGUOUS' }
        if ($holders.Count -eq 1) {
            if (-not ([string]$holders[0].Path).Equals(
                [string]$context.CanonicalRoot,
                [StringComparison]::OrdinalIgnoreCase
            )) {
                throw 'MAIN_HELD_BY_UNMANAGED_WORKTREE'
            }
            $dirtyMain = Invoke-EinkHarnessLifecycleGit `
                -RepoRoot $context.CanonicalRoot `
                -Arguments @('status','--porcelain=v1','--untracked-files=no')
            if ($dirtyMain.ExitCode -ne 0 -or @($dirtyMain.Output | Where-Object { $_ }).Count -gt 0) {
                throw 'CANONICAL_MAIN_TRACKED_TREE_DIRTY'
            }
            $pull = Invoke-EinkHarnessLifecycleGit `
                -RepoRoot $context.CanonicalRoot `
                -Arguments @('pull','--ff-only','origin','main')
            if ($pull.ExitCode -ne 0) { throw 'HARNESS_MAIN_FF_ONLY_PULL_FAILED' }
        }
        else {
            $update = Invoke-EinkHarnessLifecycleGit `
                -RepoRoot $context.CanonicalRoot `
                -Arguments @('update-ref','refs/heads/main',$originMainHead,$mainHead)
            if ($update.ExitCode -ne 0) { throw 'HARNESS_MAIN_COMPARE_AND_SWAP_FAILED' }
        }
        $mainUpdated = $true
        $mainHead = Get-EinkHarnessLifecycleGitValue `
            -RepoRoot $context.CanonicalRoot `
            -Arguments @('rev-parse','--verify','refs/heads/main') `
            -FailureReason 'MAIN_REF_MISSING'
    }
    if ($mainHead -ne $originMainHead) { throw 'HARNESS_MAIN_NOT_EQUAL_ORIGIN_MAIN' }
    $log.Add('MAIN_EQUALS_ORIGIN_MAIN: PASS')

    [pscustomobject][ordered]@{
        Passed = $true
        CanonicalRoot = [string]$context.CanonicalRoot
        RuntimeWorktree = [string]$context.RuntimePath
        RuntimeOwned = $runtimeOwned
        RuntimeDetached = $runtimeDetached
        MainUpdated = $mainUpdated
        MainHead = $mainHead
        OriginMainHead = $originMainHead
        OwnerMarkerPath = [string]$context.OwnerMarkerPath
        Log = @($log)
    }
}

<#
.SYNOPSIS
Lane helper for the parallel sprint (docs/engineering/SPRINT.md): dependency status read
from the integration branch, lane worktree setup, and landing a lane branch.

.DESCRIPTION
The integration branch is whatever branch the primary tree (the first entry of
`git worktree list`) has checked out. Every lane, trunk included, works in its own git
worktree on its own lane/<name> branch, so no two agents ever share a branch or a working
tree. Nobody edits or commits in the primary tree: it stays clean and only `land`
fast-forwards it. Merges only, never a rebase (CONVENTIONS "Git").

status <ID> [<ID> ...]  Prints each ticket's Status line as it is on the integration branch.
                        With a ticket path instead of IDs, checks every ID on that ticket's
                        "Depends on" line. Exits 0 only when every ticket is done.
setup <lane>            Creates the worktree <primary>-<lane> on branch lane/<lane> from the
                        integration branch. Does nothing when it already exists.
sync                    Merges the integration branch into the current lane branch.
land                    From a lane worktree with everything committed: merges the
                        integration branch in, runs tools/test.ps1 (the existing suite), then a
                        300-frame headless boot of the main scene. A red suite, or any
                        SCRIPT ERROR, parse error, failed script load or ERROR line in either,
                        stops the landing. Then it fast-forwards the primary tree to the lane
                        branch, retrying while another lane lands first. During the sprint
                        this gate is the only automated check: nobody writes new tests.

.EXAMPLE
tools/lane.ps1 setup oc-a

.EXAMPLE
tools/lane.ps1 status .scratch/enemies/issues/02-dev-prefabs-and-enemy-actor.md

.EXAMPLE
tools/lane.ps1 land
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('status', 'setup', 'sync', 'land')]
    [string]$Command,
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Rest = @(),
    [switch]$SkipTests,
    [int]$Retries = 6,
    [int]$RetrySeconds = 20
)

$ErrorActionPreference = 'Continue'
$idPattern = '\b(F\d+-\d{2}|D-\d{2})\b'

function Get-PrimaryTree {
    foreach ($line in (git worktree list --porcelain)) {
        if ($line -like 'worktree *') { return $line.Substring(9) }
    }
    return $null
}

function Get-BaseBranch([string]$Primary) {
    $branch = (git -C $Primary rev-parse --abbrev-ref HEAD).Trim()
    if ($branch -eq 'HEAD' -or $branch -like 'lane/*') {
        Write-Host "lane: the primary tree ($Primary) is on '$branch', which cannot be the integration branch. Ask the user to check out the integration branch there."
        exit 1
    }
    return $branch
}

function Get-TicketPath([string]$Base, [string]$Id) {
    $hits = @(git grep -l -e "^# $Id " $Base -- .scratch 2>$null)
    if ($hits.Count -eq 0) { return $null }
    return $hits[0].Substring($Base.Length + 1)
}

function Get-BaseStatus([string]$Base, [string]$Path) {
    foreach ($line in (git show "${Base}:$Path" 2>$null)) {
        if ($line -like 'Status:*') { return $line.Substring('Status:'.Length).Trim() }
    }
    return '(no Status line)'
}

function Invoke-Status([string]$Base) {
    $ids = @()
    foreach ($arg in $Rest) {
        if ($arg -like '*.md') {
            if (-not (Test-Path -LiteralPath $arg)) {
                Write-Host "lane: no such ticket file: $arg"
                exit 2
            }
            $depends = Select-String -LiteralPath $arg -Pattern '^Depends on:' | Select-Object -First 1
            if ($depends) {
                $ids += [regex]::Matches($depends.Line, $idPattern) | ForEach-Object { $_.Value }
            }
        } else {
            $ids += $arg
        }
    }
    if ($ids.Count -eq 0) {
        Write-Host 'lane: no ticket IDs to check.'
        exit 0
    }
    Write-Host "lane: status on $Base"
    $allDone = $true
    foreach ($id in ($ids | Select-Object -Unique)) {
        $path = Get-TicketPath $Base $id
        if (-not $path) {
            Write-Host ('{0,-7} not found on {1}' -f $id, $Base)
            $allDone = $false
            continue
        }
        $status = Get-BaseStatus $Base $path
        if ($status -notlike 'done*') { $allDone = $false }
        Write-Host ('{0,-7} {1,-40} {2}' -f $id, $status, $path)
    }
    if ($allDone) { exit 0 }
    exit 1
}

function Invoke-Setup([string]$Primary, [string]$Base) {
    if ($Rest.Count -lt 1) {
        Write-Host 'lane: setup needs a lane name, for example: tools/lane.ps1 setup glm-a'
        exit 2
    }
    $lane = $Rest[0]
    $path = "$Primary-$lane"
    if (Test-Path -LiteralPath $path) {
        Write-Host "lane: $path already exists."
        exit 0
    }
    git -C $Primary show-ref --verify --quiet "refs/heads/lane/$lane"
    if ($LASTEXITCODE -eq 0) {
        git -C $Primary worktree add $path "lane/$lane"
    } else {
        git -C $Primary worktree add -b "lane/$lane" $path $Base
    }
    if ($LASTEXITCODE -eq 0) { Write-Host "lane: worktree $path on lane/$lane (from $Base). Open your agent there." }
    exit $LASTEXITCODE
}

function Assert-LaneBranch {
    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    if ($branch -notlike 'lane/*') {
        Write-Host "lane: current branch is '$branch'. Run this from your lane worktree (branch lane/<name>), never from the primary tree; see docs/engineering/SPRINT.md."
        exit 2
    }
    return $branch
}

function Invoke-MergeBase([string]$Base) {
    git merge --no-edit $Base
    if ($LASTEXITCODE -ne 0) {
        Write-Host "lane: merging $Base stopped on a conflict. Resolve it (keep both sides of any HANDOFF_LOG.md or README.md entry), commit the merge, then run land again."
        exit 1
    }
}

$errorPattern = 'SCRIPT ERROR|Parse Error|Failed to load script|ERROR:'

function Invoke-Tests {
    $output = & (Join-Path $PSScriptRoot 'test.ps1') *>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    $scriptErrors = @($output | Where-Object { $_ -match $errorPattern })
    if ($code -ne 0 -or $scriptErrors.Count -gt 0) {
        Write-Host "lane: the suite is not green (exit $code, $($scriptErrors.Count) error line(s)). Fix them before landing; if an old test fails only because your ticket intentionally changed that behavior, delete or minimally adjust it and name it in your handoff entry."
        exit 1
    }
}

function Invoke-BootSmoke {
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    $output = & (Join-Path $PSScriptRoot 'godot.ps1') --headless --path $root --quit-after 300 *>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $bootErrors = @($output | Where-Object { $_ -match $errorPattern })
    if ($code -ne 0 -or $bootErrors.Count -gt 0) {
        $output | ForEach-Object { Write-Host $_ }
        Write-Host "lane: the main scene does not boot cleanly (exit $code, $($bootErrors.Count) error line(s)). Fix them before landing."
        exit 1
    }
    Write-Host 'lane: boot smoke clean (main scene, 300 frames, headless).'
}

function Invoke-Land([string]$Primary, [string]$Base) {
    $branch = Assert-LaneBranch
    $dirty = git status --porcelain
    if ($dirty) {
        Write-Host 'lane: commit your work before landing. Uncommitted:'
        $dirty | ForEach-Object { Write-Host "  $_" }
        exit 2
    }
    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        Invoke-MergeBase $Base
        if (-not $SkipTests) {
            Invoke-Tests
            Invoke-BootSmoke
        }
        if ((Get-BaseBranch $Primary) -ne $Base) {
            Write-Host "lane: the primary tree switched away from $Base during the landing. Ask the user; nothing landed."
            exit 1
        }
        $primaryDirty = git -C $Primary status --porcelain --untracked-files=no
        if ($primaryDirty) {
            Write-Host "lane: the primary tree ($Primary) has uncommitted changes, which no lane should make. Ask the user; nothing landed."
            $primaryDirty | ForEach-Object { Write-Host "  $_" }
            exit 1
        }
        git -C $Primary merge --ff-only $branch
        if ($LASTEXITCODE -eq 0) {
            Write-Host "lane: landed $branch on $Base."
            exit 0
        }
        Write-Host "lane: $Base moved while the tests ran (another lane landed); merging it again in $RetrySeconds s ($attempt of $Retries)."
        Start-Sleep -Seconds $RetrySeconds
    }
    Write-Host 'lane: could not land after every retry. Your commits are safe on the lane branch; run land again later.'
    exit 1
}

$primaryTree = Get-PrimaryTree
$baseBranch = Get-BaseBranch $primaryTree
switch ($Command) {
    'status' { Invoke-Status $baseBranch }
    'setup' { Invoke-Setup $primaryTree $baseBranch }
    'sync' {
        Assert-LaneBranch | Out-Null
        Invoke-MergeBase $baseBranch
        exit 0
    }
    'land' { Invoke-Land $primaryTree $baseBranch }
}

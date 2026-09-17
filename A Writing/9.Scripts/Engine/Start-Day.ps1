#requires -Version 5.1
<#
    Start-Day.ps1
    The first thing you run. It brings the working copy up to date with GitHub
    so that nothing you do today is written on top of yesterday's work from
    another machine.

        1  find the repository - the folder above "A Writing" that holds .git
        2  report what is uncommitted here, if anything
        3  fetch, then pull with --rebase so local commits sit on top of the
           remote ones rather than making a merge bubble
        4  say what came down

    A dirty working copy is not an error. --autostash puts your changes aside,
    rebases, and puts them back. If that leaves a conflict the script stops and
    says so; it never resolves one for you and it never force-pushes.

    Nothing is committed or pushed here. That is End-Day.ps1.

    Usage
        Run\Start-Day.bat
#>

[CmdletBinding()]
param(
    [switch]$NoPause
)

$ErrorActionPreference = 'Continue'

$me      = Split-Path -Parent $MyInvocation.MyCommand.Path
$scripts = Split-Path -Parent $me
$base    = Split-Path -Parent $scripts

function Banner([string]$t) {
    Write-Host ''
    Write-Host ('=' * 70)
    Write-Host ("  {0}" -f $t)
    Write-Host ('=' * 70)
}

function Close-Out {
    if (-not $NoPause) {
        Write-Host ''
        Write-Host 'Press Enter to close...'
        [void](Read-Host)
    }
}

Banner ("Start of day   {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))

# --- git present? -------------------------------------------------------------

$git = (Get-Command git -EA SilentlyContinue)
if (-not $git) {
    Write-Host ''
    Write-Host '  git is not on PATH. Install Git for Windows, or open this from'
    Write-Host '  Git Bash, and run again.'
    Close-Out
    return
}

# --- the repository -----------------------------------------------------------

function Find-RepoRoot([string]$start) {
    $d = $start
    for ($i = 0; $i -lt 6; $i++) {
        if (Test-Path -LiteralPath (Join-Path $d '.git')) { return $d }
        $p = Split-Path -Parent $d
        if (-not $p -or $p -eq $d) { break }
        $d = $p
    }
    return $null
}

$repo = Find-RepoRoot $base
if (-not $repo) {
    Write-Host ''
    Write-Host ('  No .git found at or above {0}' -f $base)
    Write-Host '  Nothing to pull. If this copy should be in the repository, clone it'
    Write-Host '  or run  git init  there first.'
    Close-Out
    return
}

Write-Host ''
Write-Host ('  Repository : {0}' -f $repo)
Push-Location -LiteralPath $repo
try {
    $remote = (& git remote get-url origin 2>&1 | Out-String).Trim()
    $branch = (& git rev-parse --abbrev-ref HEAD 2>&1 | Out-String).Trim()
    Write-Host ('  Remote     : {0}' -f $remote)
    Write-Host ('  Branch     : {0}' -f $branch)

    # --- what is uncommitted --------------------------------------------------

    $status = @(& git status --porcelain 2>&1 | Where-Object { $_ -ne '' })
    Write-Host ''
    if ($status.Count -eq 0) {
        Write-Host '-- working copy is clean'
    } else {
        Write-Host ("-- {0} uncommitted change(s) here - they will be set aside and put back" -f $status.Count)
        foreach ($s in ($status | Select-Object -First 15)) { Write-Host ("   {0}" -f $s) }
        if ($status.Count -gt 15) { Write-Host ('   ... and {0} more' -f ($status.Count - 15)) }
    }

    # --- fetch and pull -------------------------------------------------------

    Write-Host ''
    Write-Host '-- fetching'
    & git fetch --prune 2>&1 | ForEach-Object { Write-Host ("   {0}" -f $_) }

    $behind = (& git rev-list --count ("HEAD..origin/" + $branch) 2>&1 | Out-String).Trim()
    $ahead  = (& git rev-list --count (("origin/" + $branch) + "..HEAD") 2>&1 | Out-String).Trim()
    if ($behind -match '^\d+$' -and $ahead -match '^\d+$') {
        Write-Host ''
        Write-Host ('   behind origin/{0} by {1}, ahead by {2}' -f $branch, $behind, $ahead)
        if ([int]$behind -eq 0) {
            Write-Host '   already up to date - nothing to bring down'
            Write-Host ''
            Write-Host 'Ready. Work away; run Run\End-Day.bat when you finish.'
            Close-Out
            return
        }
    }

    Write-Host ''
    Write-Host '-- pulling'
    $out = & git pull --rebase --autostash 2>&1
    $ok  = ($LASTEXITCODE -eq 0)
    $out | ForEach-Object { Write-Host ("   {0}" -f $_) }

    Write-Host ''
    if ($ok) {
        Write-Host '-- what came down'
        & git --no-pager log --oneline -10 2>&1 | ForEach-Object { Write-Host ("   {0}" -f $_) }
        Write-Host ''
        Write-Host 'Ready. Work away; run Run\End-Day.bat when you finish.'
    } else {
        Write-Host '-- THE PULL DID NOT FINISH'
        Write-Host ''
        Write-Host '   Most often this is a conflict between something you changed here and'
        Write-Host '   something changed on the other machine. Nothing has been lost: your'
        Write-Host '   work is either in the working copy or in the autostash.'
        Write-Host ''
        Write-Host '   To see where you are     : git status'
        Write-Host '   To abandon the rebase    : git rebase --abort'
        Write-Host '   To recover a stash       : git stash list   then   git stash pop'
        Write-Host ''
        Write-Host '   Sort that out before running End-Day.bat.'
    }
} finally {
    Pop-Location
}

Close-Out

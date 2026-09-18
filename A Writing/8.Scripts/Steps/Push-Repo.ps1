#requires -Version 5.1
<#
    Push-Repo.ps1
    Commit what has changed, pull, push. Nothing else.

    The order is the whole point. A rebase will not run on a dirty working copy,
    so the commit has to come first; and pulling before pushing means your
    commits end up on top of anything that arrived from another machine rather
    than in a merge bubble.

    Nothing is ever force-pushed. If the pull stops on a conflict, so does this,
    and it says what to type. Your work is committed locally either way.

    Usage
        Run\Push-Repo.bat
        powershell -File Steps\Push-Repo.ps1 -Message "Rewrote 2.2"

    Exit code 0 means committed and pushed, or nothing to do. Anything else
    means it stopped, and the reason is on screen.
#>

param(
    [string]$Message
)

$ErrorActionPreference = 'Continue'

# --- where is the repository? -------------------------------------------------
# It is the first folder at or above the scripts folder that holds a .git.

$dir  = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$repo = $null
for ($i = 0; $i -lt 6; $i++) {
    if (Test-Path -LiteralPath (Join-Path $dir '.git')) { $repo = $dir; break }
    $up = Split-Path -Parent $dir
    if (-not $up -or $up -eq $dir) { break }
    $dir = $up
}

if (-not (Get-Command git -EA SilentlyContinue)) {
    Write-Host 'git is not on PATH. Install Git for Windows and try again.'
    exit 1
}
if (-not $repo) {
    Write-Host 'No .git folder at or above the scripts folder - there is no repository here.'
    exit 1
}

Push-Location -LiteralPath $repo
try {
    $branch = (& git rev-parse --abbrev-ref HEAD 2>&1 | Out-String).Trim()
    Write-Host ''
    Write-Host ('Repository : {0}' -f $repo)
    Write-Host ('Branch     : {0}' -f $branch)
    Write-Host ('Remote     : {0}' -f (& git remote get-url origin 2>&1 | Out-String).Trim())

    # --- 1  commit ------------------------------------------------------------

    $changes = @(& git status --porcelain 2>&1 | Where-Object { $_ -ne '' })

    Write-Host ''
    if ($changes.Count -eq 0) {
        Write-Host '1. Nothing to commit.'
    } else {
        Write-Host ('1. Committing {0} change(s):' -f $changes.Count)
        foreach ($c in ($changes | Select-Object -First 20)) { Write-Host ('     {0}' -f $c) }
        if ($changes.Count -gt 20) { Write-Host ('     ... and {0} more' -f ($changes.Count - 20)) }

        if (-not $Message) { $Message = 'Update {0}' -f (Get-Date -Format 'yyyy-MM-dd') }

        & git add -A
        & git commit -m $Message | ForEach-Object { Write-Host ('     {0}' -f $_) }
        if ($LASTEXITCODE -ne 0) {
            Write-Host ''
            Write-Host '   The commit did not go through. Nothing has been pushed.'
            exit 1
        }
    }

    # --- 2  pull --------------------------------------------------------------

    Write-Host ''
    Write-Host '2. Pulling (rebase, with your uncommitted work set aside and put back):'
    & git pull --rebase --autostash 2>&1 | ForEach-Object { Write-Host ('     {0}' -f $_) }

    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host '   The pull stopped, so nothing has been pushed. Your work is committed'
        Write-Host '   here and is not lost. Usually this is a conflict with a change made'
        Write-Host '   on another machine.'
        Write-Host ''
        Write-Host '     git status            see where you are'
        Write-Host '     git rebase --abort    put everything back as it was'
        Write-Host '     git stash list        if --autostash set something aside'
        exit 1
    }

    # --- 3  push --------------------------------------------------------------

    Write-Host ''
    Write-Host '3. Pushing:'
    & git push 2>&1 | ForEach-Object { Write-Host ('     {0}' -f $_) }

    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host '   The push was refused. The usual causes are no network or no stored'
        Write-Host '   credentials for GitHub.'
        exit 1
    }

    Write-Host ''
    Write-Host 'Done. Local and GitHub match.'
    exit 0
}
finally {
    Pop-Location
}

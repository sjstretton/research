#requires -Version 5.1
<#
    Push-Repo.ps1
    Commit what has changed, then push. Nothing else.

    WHY IT LOOKS AT GITHUB IN BETWEEN
    Not because the pull is wanted for its own sake. It is there because a push
    is refused outright when the remote holds a commit you do not have - from
    another machine, from an edit made on github.com, from a clone you forgot
    about - and then you are pulling anyway, halfway through, with the push
    already failed. So this asks first: git fetch, then a count of what is on
    GitHub and not here. On the ordinary day that count is zero and no rebase
    runs at all - it says so and goes straight to the push. The rebase only
    happens when there is genuinely something to rebase onto, and then it is
    doing the job that stops the push being rejected.

    The commit comes first because a rebase will not run on a dirty working
    copy, and --rebase rather than a merge so your commits sit on top of
    whatever came from elsewhere instead of making a merge bubble.

    Nothing is ever force-pushed. If the rebase stops on a conflict, so does
    this, and it says what to type. Your work is committed locally either way.

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

# git writes ordinary progress to stderr. With 2>&1 PowerShell wraps those lines
# as error records, which print as "System.Management.Automation.RemoteException"
# unless they are turned back into strings first. Everything git says goes
# through here.
function Show($lines) {
    foreach ($l in @($lines)) {
        $t = if ($l -is [System.Management.Automation.ErrorRecord]) { $l.Exception.Message } else { [string]$l }
        $t = ($t -replace "\x1b\[[0-9;]*[A-Za-z]", '') -replace "\r", ''
        foreach ($one in ($t -split "`n")) {
            if ($one.Trim() -ne '') { Write-Host ('     {0}' -f $one.TrimEnd()) }
        }
    }
}

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
        Show (& git commit -m $Message 2>&1)
        if ($LASTEXITCODE -ne 0) {
            Write-Host ''
            Write-Host '   The commit did not go through. Nothing has been pushed.'
            exit 1
        }
    }

    # --- 2  is there anything on GitHub that is not here? ---------------------
    # Asking first means the rebase only runs when it has something to do. On
    # the normal day - one machine, nothing pushed from anywhere else - there is
    # nothing to bring down and this step just says so.

    Write-Host ''
    Write-Host '2. Checking GitHub:'
    Show (& git fetch --quiet 2>&1)

    $behind = (& git rev-list --count ("HEAD..origin/" + $branch) 2>&1 | Out-String).Trim()

    if ($behind -notmatch '^\d+$') {
        Write-Host '     could not reach GitHub - trying the push anyway.'
    }
    elseif ([int]$behind -eq 0) {
        Write-Host '     nothing there that is not here. No rebase needed.'
    }
    else {
        Write-Host ('     {0} commit(s) here to bring down first - rebasing your work on top.' -f $behind)
        Show (& git pull --rebase 2>&1)

        if ($LASTEXITCODE -ne 0) {
            Write-Host ''
            Write-Host '   The rebase stopped, so nothing has been pushed. Your work is'
            Write-Host '   committed here and is not lost. This means the same lines were'
            Write-Host '   changed here and on another machine, and only you can say which'
            Write-Host '   version wins.'
            Write-Host ''
            Write-Host '     git status            see where you are'
            Write-Host '     git rebase --abort    put everything back as it was'
            exit 1
        }
    }

    # --- 3  push --------------------------------------------------------------

    Write-Host ''
    Write-Host '3. Pushing:'
    Show (& git push 2>&1)

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

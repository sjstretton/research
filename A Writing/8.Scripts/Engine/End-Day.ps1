#requires -Version 5.1
<#
    End-Day.ps1
    The last thing you run. Three things, in the only order that works:

      1  WORKFLOW   Run-All.ps1 - folder names, stale derivatives, a .qmd and a
                    .docx for every paper, publish, render, link check, tidy.
                    The site has to be rebuilt before it can be uploaded, and
                    the files have to be settled before they are committed.

      2  GIT        Steps\Push-Repo.ps1 - commit what changed here, then pull,
                    then push. That order matters: a rebase will not run on a
                    dirty working copy, so the local commit has to come first.
                    The pull is --rebase, so your commits end up on top of
                    anything that came from another machine rather than in a
                    merge bubble. The same script runs on its own from
                    Run\Push-Repo.bat.

      3  FTP        upload the rendered _site to the web server. Last, because
                    it is the only step that puts anything in front of the
                    public, and it should carry the version that was just
                    committed.

    Any step can fail without stopping the ones that do not depend on it, except
    that a failed workflow stops the upload - there is no sense putting a
    half-built site live. A git conflict stops the push and says what to do; it
    is never resolved automatically and nothing is ever force-pushed.

    Switches
        -SkipWorkflow          go straight to git and FTP
        -SkipGit               build and upload, commit nothing
        -SkipFtp               build and commit, upload nothing
        -Message "..."         commit message (default: "Update <date>")
        -Full                  the long workflow, including the structural steps
#>

[CmdletBinding()]
param(
    [switch]$SkipWorkflow,
    [switch]$SkipGit,
    [switch]$SkipFtp,
    [switch]$Full,
    [string]$Message,
    [switch]$NoPause
)

$ErrorActionPreference = 'Continue'

$me      = Split-Path -Parent $MyInvocation.MyCommand.Path
$scripts = Split-Path -Parent $me
$base    = Split-Path -Parent $scripts

$reportDir = Join-Path $scripts 'Reports'
if (-not (Test-Path -LiteralPath $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$transcript = Join-Path $reportDir ("EndDay-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
try { Start-Transcript -LiteralPath $transcript -Force | Out-Null } catch { }

$results = New-Object System.Collections.Generic.List[object]
function Note($step, $status, $note) {
    $results.Add([pscustomobject]@{ Step=$step; Status=$status; Note=$note }) | Out-Null
}
function Banner([string]$t) {
    Write-Host ''
    Write-Host ('=' * 70)
    Write-Host ("  {0}" -f $t)
    Write-Host ('=' * 70)
}

Banner ("End of day   {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Write-Host ("  {0}" -f $base)

# --- 1  the workflow ----------------------------------------------------------

$workflowOk = $true
$runAll = Join-Path $me 'Run-All.ps1'
if ($SkipWorkflow) {
    Note 'Workflow' 'skipped' '-SkipWorkflow'
} elseif (-not (Test-Path -LiteralPath $runAll)) {
    Note 'Workflow' 'missing' 'Run-All.ps1 not in Engine\'
    $workflowOk = $false
} else {
    Banner 'step 1 of 3   Run-All.ps1'
    try {
        if ($Full) { & $runAll -Apply -Full } else { & $runAll -Apply }
        Note 'Workflow' 'ok' ''
    } catch {
        Write-Host ("   FAILED: {0}" -f $_.Exception.Message)
        Note 'Workflow' 'FAILED' $_.Exception.Message
        $workflowOk = $false
    }
}

# --- 2  git -------------------------------------------------------------------
# One copy of this logic: Steps\Push-Repo.ps1, which also runs on its own from
# Run\Push-Repo.bat.

$push = Join-Path $scripts 'Steps\Push-Repo.ps1'
if ($SkipGit) {
    Note 'Git' 'skipped' '-SkipGit'
} elseif (-not (Test-Path -LiteralPath $push)) {
    Note 'Git' 'missing' 'Push-Repo.ps1 not in Steps\'
} else {
    Banner 'step 2 of 3   commit, pull, push'
    try {
        if ($Message) { & $push -Message $Message } else { & $push }
        if ($LASTEXITCODE -eq 0) { Note 'Git' 'ok' 'committed and pushed' }
        else { Note 'Git' 'FAILED' 'see the messages above' }
    } catch {
        Write-Host ("   FAILED: {0}" -f $_.Exception.Message)
        Note 'Git' 'FAILED' $_.Exception.Message
    }
}

# --- 3  ftp -------------------------------------------------------------------

$ftp = Join-Path $scripts 'Steps\Publish-Ftp.ps1'
if ($SkipFtp) {
    Note 'FTP' 'skipped' '-SkipFtp'
} elseif (-not $workflowOk) {
    Write-Host ''
    Write-Host '-- upload skipped: the workflow did not finish, so the site may be half built.'
    Note 'FTP' 'not run' 'the workflow failed'
} elseif (-not (Test-Path -LiteralPath $ftp)) {
    Note 'FTP' 'missing' 'Publish-Ftp.ps1 not in Steps\'
} else {
    Banner 'step 3 of 3   upload the site'
    try {
        & $ftp -Apply
        if ($LASTEXITCODE -eq 0) { Note 'FTP' 'ok' '' } else { Note 'FTP' 'FAILED' ('exit ' + $LASTEXITCODE) }
    } catch {
        Write-Host ("   FAILED: {0}" -f $_.Exception.Message)
        Note 'FTP' 'FAILED' $_.Exception.Message
    }
}

# --- summary ------------------------------------------------------------------
# Written by hand: with input redirected the host reports no console width and
# Format-Table prints nothing at all.

Banner 'Summary'
Write-Host ("{0,-10} {1,-10} {2}" -f 'Step', 'Result', 'Note')
Write-Host ("{0,-10} {1,-10} {2}" -f ('-' * 10), ('-' * 10), ('-' * 30))
foreach ($r in $results) { Write-Host ("{0,-10} {1,-10} {2}" -f $r.Step, $r.Status, $r.Note) }

$bad = @($results | Where-Object { $_.Status -eq 'FAILED' -or $_.Status -eq 'missing' })
Write-Host ''
if ($bad.Count -eq 0) {
    $did = @()
    if (-not $SkipWorkflow) { $did += 'built' }
    if (-not $SkipGit)      { $did += 'committed and pushed' }
    if (-not $SkipFtp -and $workflowOk) { $did += 'uploaded' }
    if ($did.Count -eq 0) { Write-Host 'Nothing to do - every step was skipped.' }
    else { Write-Host ('Done for the day: {0}.' -f ($did -join ', ')) }
} else {
    Write-Host ("{0} step(s) need attention - see above." -f $bad.Count)
}

try { Stop-Transcript | Out-Null } catch { }
Write-Host ''
Write-Host ("Log: {0}" -f $transcript)

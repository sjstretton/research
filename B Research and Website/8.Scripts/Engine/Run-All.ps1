#requires -Version 5.1
<#
    Run-All.ps1
    The maintenance workflow, in the order the steps depend on each other.

      1  Rename-Folders      folder names to <number>.CamelCase
      2  Sync-Masters        retire derivatives older than their master
      3  Convert-Documents   every paper gets a .qmd and a .docx
      4  Run-Website         publish, render, link check
      5  Tidy-Scripts        put the scripts folder back to the layout

    That is the daily run. Three more steps exist and are not in it:

        Reorganize-Papers   files into the standard slots, rebuild the index
        Rename-Files        filename convention, flatten media folders
        Repair-Encoding     undo double-encoded UTF-8

    They did their work when the tree was first put in order. On a settled tree
    they are no-ops that still walk every file and can still move one, which is
    the wrong trade for a run you do every day. -Full puts them back, and
    Run\Organise.bat is that run: worth doing after importing a batch of new
    material, and not otherwise.

    Rename-Folders is structural: if it fails the run stops, because the later
    steps would act on a half-moved tree. Everything after it is recorded and
    the run carries on.

    Every step lives in Steps\ as a .ps1. This file and Run-Website.ps1 are
    the only orchestrators; nothing else calls the steps.

    Usage
        Run\Master-All.bat     the real run, after one confirmation
        Run\Preview-All.bat    the same in preview - changes nothing
        Run\Organise.bat       the long run, with the three structural steps
#>

[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$SkipWebsite,
    [switch]$NoTidy,
    [switch]$Full,
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = 'Continue'

$me      = Split-Path -Parent $MyInvocation.MyCommand.Path
$scripts = Split-Path -Parent $me
$base    = Split-Path -Parent $scripts
$mode    = if ($Apply) { 'APPLY' } else { 'PREVIEW' }

$reportDir = Join-Path $scripts 'Reports'
if (-not (Test-Path -LiteralPath $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$transcript = Join-Path $reportDir ("RunAll-{0}-{1}.txt" -f $mode, (Get-Date -Format 'yyyyMMdd-HHmmss'))
try { Start-Transcript -LiteralPath $transcript -Force | Out-Null } catch { }

$Steps = New-Object System.Collections.Generic.List[object]
$Steps.Add([pscustomobject]@{ Rel='Steps\Rename-Folders.ps1';    Critical=$true;  What='folder names to <number>.CamelCase' }) | Out-Null
if ($Full) {
    $Steps.Add([pscustomobject]@{ Rel='Steps\Reorganize-Papers.ps1'; Critical=$true;  What='files into the standard slots, rebuild the index' }) | Out-Null
    $Steps.Add([pscustomobject]@{ Rel='Steps\Rename-Files.ps1';      Critical=$true;  What='filename convention, flatten media folders' }) | Out-Null
    $Steps.Add([pscustomobject]@{ Rel='Steps\Repair-Encoding.ps1';   Critical=$false; What='undo double-encoded characters' }) | Out-Null
}
$Steps.Add([pscustomobject]@{ Rel='Steps\Sync-Masters.ps1';      Critical=$false; What='retire derivatives older than their master' }) | Out-Null
$Steps.Add([pscustomobject]@{ Rel='Steps\Convert-Documents.ps1'; Critical=$false; What='give every paper a .qmd and a .docx' }) | Out-Null

$n = 0
foreach ($s in $Steps) { $n++; $s | Add-Member -NotePropertyName N -NotePropertyValue $n -Force }
$Total = $Steps.Count + 2          # + Run-Website + Tidy-Scripts
$WebN  = $Steps.Count + 1
$TidyN = $Steps.Count + 2

$results = New-Object System.Collections.Generic.List[object]
$stopped = $false

function Banner([string]$t) {
    Write-Host ''
    Write-Host ('=' * 70)
    Write-Host ("  {0}" -f $t)
    Write-Host ('=' * 70)
}

Banner ("Run-All  [{0}]   {1}" -f $mode, (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Write-Host ("  {0}" -f $base)
if ($Full) { Write-Host '  FULL - the three structural steps are included.' }
if (-not $Apply) {
    Write-Host ''
    Write-Host '  PREVIEW. Nothing is changed. A later step previewed against an'
    Write-Host '  unchanged tree can only show what it sees today.'
}

# --- prerequisites ------------------------------------------------------------

Write-Host ''
Write-Host '-- prerequisites'
foreach ($tool in @('pandoc', 'quarto')) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) { Write-Host ("   found  : {0}" -f $tool) }
    else { Write-Host ("   MISSING: {0}  (steps that need it will report and be skipped)" -f $tool) }
}

# --- steps 1 to 6 -------------------------------------------------------------

foreach ($s in $Steps) {

    if ($stopped) {
        $results.Add([pscustomobject]@{ Step=$s.N; Name=(Split-Path -Leaf $s.Rel); Status='not run'; Seconds=0; Note='an earlier structural step failed' }) | Out-Null
        continue
    }

    $path = Join-Path $scripts $s.Rel
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host ''
        Write-Host ("-- step {0}  {1}  NOT FOUND" -f $s.N, $s.Rel)
        $results.Add([pscustomobject]@{ Step=$s.N; Name=(Split-Path -Leaf $s.Rel); Status='missing'; Seconds=0; Note=('not at ' + $s.Rel) }) | Out-Null
        if ($s.Critical) { $stopped = $true }
        continue
    }

    Banner ("step {0} of {1}   {2}   -   {3}" -f $s.N, $Total, (Split-Path -Leaf $s.Rel), $s.What)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $err = $null
    try {
        if ($Apply) { & $path -Apply } else { & $path }
    } catch { $err = $_.Exception.Message }
    $sw.Stop()

    if ($err) {
        Write-Host ''
        Write-Host ("   FAILED: {0}" -f $err)
        $results.Add([pscustomobject]@{ Step=$s.N; Name=(Split-Path -Leaf $s.Rel); Status='FAILED'; Seconds=[int]$sw.Elapsed.TotalSeconds; Note=$err }) | Out-Null
        if ($s.Critical) { $stopped = $true; Write-Host '   This step is structural, so the run stops here.' }
    } else {
        $results.Add([pscustomobject]@{ Step=$s.N; Name=(Split-Path -Leaf $s.Rel); Status='ok'; Seconds=[int]$sw.Elapsed.TotalSeconds; Note='' }) | Out-Null
    }
}

# --- step 7  website ----------------------------------------------------------

$runWeb = Join-Path $me 'Run-Website.ps1'
if ($SkipWebsite) {
    $results.Add([pscustomobject]@{ Step=$WebN; Name='Run-Website'; Status='skipped'; Seconds=0; Note='-SkipWebsite' }) | Out-Null
} elseif ($stopped) {
    $results.Add([pscustomobject]@{ Step=$WebN; Name='Run-Website'; Status='not run'; Seconds=0; Note='an earlier structural step failed' }) | Out-Null
} elseif (-not (Test-Path -LiteralPath $runWeb)) {
    $results.Add([pscustomobject]@{ Step=$WebN; Name='Run-Website'; Status='missing'; Seconds=0; Note='not in Engine\' }) | Out-Null
} else {
    Banner ("step {0} of {1}   Run-Website.ps1   -   publish, render, link check" -f $WebN, $Total)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $err = $null
    try {
        $p = @{ TimeoutSeconds = $TimeoutSeconds }
        if ($Apply) { $p['Apply'] = $true }
        & $runWeb @p
    } catch { $err = $_.Exception.Message }
    $sw.Stop()
    $results.Add([pscustomobject]@{
        Step=$WebN; Name='Run-Website'
        Status=$(if ($err) { 'FAILED' } else { 'ok' })
        Seconds=[int]$sw.Elapsed.TotalSeconds; Note=$err }) | Out-Null
}

# --- step 8  tidy -------------------------------------------------------------

$tidy = Join-Path $me 'Tidy-Scripts.ps1'
if ($NoTidy) {
    Write-Host ''
    Write-Host '-- tidy skipped (-NoTidy)'
} elseif ($stopped) {
    Write-Host ''
    Write-Host '-- tidy skipped: the run stopped early, so nothing is being archived'
} elseif (-not (Test-Path -LiteralPath $tidy)) {
    Write-Host ''
    Write-Host '-- tidy skipped: Tidy-Scripts.ps1 not found'
} else {
    Banner ("step {0} of {1}   Tidy-Scripts.ps1   -   put the scripts folder back in order" -f $TidyN, $Total)
    try {
        if ($Apply) { & $tidy -Apply -NoPause } else { & $tidy -NoPause }
        $results.Add([pscustomobject]@{ Step=$TidyN; Name='Tidy-Scripts'; Status='ok'; Seconds=0; Note='' }) | Out-Null
    } catch {
        Write-Host ("   FAILED: {0}" -f $_.Exception.Message)
        $results.Add([pscustomobject]@{ Step=$TidyN; Name='Tidy-Scripts'; Status='FAILED'; Seconds=0; Note=$_.Exception.Message }) | Out-Null
    }
}

# --- summary ------------------------------------------------------------------
# Written out by hand: with input redirected the host reports no console width
# and Format-Table prints nothing at all.

Banner ("Summary  [{0}]" -f $mode)
Write-Host ("{0,3}  {1,-22} {2,-12} {3,6}  {4}" -f '#', 'Step', 'Result', 'Secs', 'Note')
Write-Host ("{0,3}  {1,-22} {2,-12} {3,6}  {4}" -f '---', ('-' * 22), ('-' * 12), '-----', ('-' * 20))
foreach ($r in ($results | Sort-Object Step)) {
    Write-Host ("{0,3}  {1,-22} {2,-12} {3,6}  {4}" -f $r.Step, $r.Name, $r.Status, $r.Seconds, $r.Note)
}

$bad = @($results | Where-Object { $_.Status -eq 'FAILED' -or $_.Status -eq 'missing' })
Write-Host ''
if ($bad.Count -eq 0) {
    Write-Host 'Every step completed.'
} else {
    Write-Host ("{0} step(s) need attention:" -f $bad.Count)
    $bad | ForEach-Object { Write-Host ("   {0}  {1}" -f $_.Name, $_.Note) }
}

if (-not $Apply) {
    Write-Host ''
    Write-Host 'PREVIEW only - nothing was changed. Run Master-All.bat to apply.'
}

Write-Host ''
Write-Host ("Each step's own report is in {0}" -f $reportDir)
try { Stop-Transcript | Out-Null } catch { }
Write-Host ("Log: {0}" -f $transcript)

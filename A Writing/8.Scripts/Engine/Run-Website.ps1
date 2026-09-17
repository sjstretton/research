#requires -Version 5.1
<#
    Run-Website.ps1
    The PDF and website half of the workflow, on its own.

        1  Build-Pdfs      only with -Pdf. A PDF for every paper with a
                           master .docx, one document per process with a time
                           limit, so a document Word cannot open is skipped
                           rather than stopping the run.
        2  Publish-Site    copy the master .docx of every paper into the
                           website's papers\ folder, repoint the links in
                           research.qmd at what was published, write
                           ResearchOverview.docx into the Overview folder,
                           run quarto render, check every link

    The site publishes Word files by default. Driving Word to make PDFs is the
    one part of this pipeline that depends on a desktop application behaving,
    and it is not worth the site depending on it too. -Pdf brings it back.

    Run it with Run\Master-Website.bat. Run-All.ps1 calls this as its last step,
    so there is only one copy of this logic.

    Switches
        -Apply              do it (otherwise both steps report only)
        -Pdf                build PDFs with Word and publish those instead
        -TimeoutSeconds N   per document, default 180, only with -Pdf
        -SkipRender         publish and check without running quarto
        -Only <pattern>     build only papers whose folder name matches
        -Force              rebuild PDFs even where they are already current
#>

[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Pdf,
    [int]$TimeoutSeconds = 180,
    [switch]$SkipRender,
    [string]$Only,
    [switch]$Force
)

$ErrorActionPreference = 'Continue'

$me      = Split-Path -Parent $MyInvocation.MyCommand.Path
$scripts = Split-Path -Parent $me
$mode    = if ($Apply) { 'APPLY' } else { 'PREVIEW' }

$reportDir = Join-Path $scripts 'Reports'
if (-not (Test-Path -LiteralPath $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$transcript = Join-Path $reportDir ("RunWebsite-{0}-{1}.txt" -f $mode, (Get-Date -Format 'yyyyMMdd-HHmmss'))
try { Start-Transcript -LiteralPath $transcript -Force | Out-Null } catch { }

function Banner([string]$t) {
    Write-Host ''
    Write-Host ('=' * 70)
    Write-Host ("  {0}" -f $t)
    Write-Host ('=' * 70)
}

Banner ("Run-Website  [{0}]   {1}" -f $mode, (Get-Date -Format 'yyyy-MM-dd HH:mm'))

$results = New-Object System.Collections.Generic.List[object]

# --- prerequisites ------------------------------------------------------------

Write-Host ''
Write-Host '-- prerequisites'
# No Word probe. Creating and quitting a COM instance just to test for Word is
# itself a way to hang or fail, and when it failed it silently skipped the whole
# PDF step. Build-Pdfs runs each document in its own killable process, so if Word
# really is missing every document fails fast and says so.
Write-Host '   Word     : not probed - Build-Pdfs reports per document'
foreach ($t in @('quarto', 'pandoc')) {
    if (Get-Command $t -ErrorAction SilentlyContinue) { Write-Host ("   found  : {0}" -f $t) }
    else { Write-Host ("   MISSING: {0}" -f $t) }
}

# --- 1  PDFs ------------------------------------------------------------------

$buildPdfs = Join-Path $scripts 'Steps\Build-Pdfs.ps1'
if (-not $Pdf) {
    Write-Host ''
    Write-Host '-- step 1  PDFs not built. The site publishes the master .docx.'
    Write-Host '   Pass -Pdf to build PDFs with Word instead.'
    $results.Add([pscustomobject]@{ Step=1; Name='Build-Pdfs'; Status='not wanted'; Seconds=0; Note='site uses .docx' }) | Out-Null
} elseif (-not (Test-Path -LiteralPath $buildPdfs)) {
    Write-Host ''
    Write-Host '-- step 1  Build-Pdfs.ps1 NOT FOUND in Website\'
    $results.Add([pscustomobject]@{ Step=1; Name='Build-Pdfs'; Status='missing'; Seconds=0; Note='not in Steps\' }) | Out-Null
} else {
    Banner 'step 1 of 2   Build-Pdfs.ps1   -   a PDF for every paper'
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $err = $null
    try {
        $p = @{ TimeoutSeconds = $TimeoutSeconds }
        if ($Apply) { $p['Apply'] = $true }
        if ($Force) { $p['Force'] = $true }
        if ($Only)  { $p['Only']  = $Only }
        & $buildPdfs @p
    } catch { $err = $_.Exception.Message }
    $sw.Stop()
    $results.Add([pscustomobject]@{
        Step=1; Name='Build-Pdfs'
        Status=$(if ($err) { 'FAILED' } else { 'ok' })
        Seconds=[int]$sw.Elapsed.TotalSeconds; Note=$err }) | Out-Null
}

# --- 2  publish, render, check ------------------------------------------------

$publish = Join-Path $scripts 'Steps\Publish-Site.ps1'
if (-not (Test-Path -LiteralPath $publish)) {
    Write-Host ''
    Write-Host '-- step 2  Publish-Site.ps1 NOT FOUND in Website\'
    $results.Add([pscustomobject]@{ Step=2; Name='Publish-Site'; Status='missing'; Seconds=0; Note='not in Steps\' }) | Out-Null
} else {
    Banner 'step 2 of 2   Publish-Site.ps1   -   copy, render, check'
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $err = $null
    try {
        $p = @{ Prefer = $(if ($Pdf) { 'pdf' } else { 'docx' }) }
        if ($Apply)      { $p['Apply'] = $true }
        if ($SkipRender) { $p['SkipRender'] = $true }
        & $publish @p
    } catch { $err = $_.Exception.Message }
    $sw.Stop()
    $results.Add([pscustomobject]@{
        Step=2; Name='Publish-Site'
        Status=$(if ($err) { 'FAILED' } else { 'ok' })
        Seconds=[int]$sw.Elapsed.TotalSeconds; Note=$err }) | Out-Null
}

# --- summary ------------------------------------------------------------------

Banner ("Summary  [{0}]" -f $mode)
Write-Host ("{0,3}  {1,-16} {2,-10} {3,6}  {4}" -f '#', 'Step', 'Result', 'Secs', 'Note')
Write-Host ("{0,3}  {1,-16} {2,-10} {3,6}  {4}" -f '---', ('-' * 16), ('-' * 10), '-----', ('-' * 20))
foreach ($r in ($results | Sort-Object Step)) {
    Write-Host ("{0,3}  {1,-16} {2,-10} {3,6}  {4}" -f $r.Step, $r.Name, $r.Status, $r.Seconds, $r.Note)
}

$bad = @($results | Where-Object { $_.Status -eq 'FAILED' -or $_.Status -eq 'missing' })
Write-Host ''
if ($bad.Count -eq 0) { Write-Host 'Both steps completed. Read _PdfReport.txt and _SiteReport.txt for the detail.' }
else { foreach ($b in $bad) { Write-Host ("   {0}  {1}" -f $b.Name, $b.Note) } }

if (-not $Apply) {
    Write-Host ''
    Write-Host 'PREVIEW only - nothing was changed. Run Run\Master-Website.bat to apply.'
}

try { Stop-Transcript | Out-Null } catch { }
Write-Host ''
Write-Host ("Log: {0}" -f $transcript)

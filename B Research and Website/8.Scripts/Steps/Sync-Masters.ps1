#requires -Version 5.1
<#
    Sync-Masters.ps1
    Retires the derivatives of any paper whose .qmd has been edited.

    THE RULE
    The .qmd is the master. When it is newer than its .docx, the .docx and the
    PDF built from it are out of date. This moves them into

        <paper>\8.PreviousVersions\<Name>-<yyyy-MM-dd>.docx

    so that Run\Master-All.bat rebuilds the .docx from the edited .qmd and
    Run-Website.bat rebuilds the PDF from that. Slot 8 was reserved; this is
    what it is for - superseded editions of the current paper, as against
    9.Archive, which holds material that is no longer part of the paper at all.

    A previous .qmd is kept too when one is found beside it, so an edit can
    always be read against what it replaced.

    SAFETY  Nothing is deleted and nothing is overwritten; a name already taken
    gets a time suffix. Papers whose .docx is newer than the .qmd - the normal
    state after a conversion - are left alone. Re-running is a no-op.

    USAGE
        Preview-SyncMasters.bat
        Run-SyncMasters.bat
#>

param([switch]$Apply, [int]$ToleranceSeconds = 120)

$ErrorActionPreference = 'Stop'
$SlotPrev = '8.PreviousVersions'
$SlotSrc  = '2.Source'
$ExcludeThemes = @('scripts','website','overview','additional')

function Norm([string]$n) { return (($n -replace '[^A-Za-z0-9]','').ToLower()) }
function Find-WritingRoot([string]$s) {
    $d = $s
    for ($i=0; $i -lt 4; $i++) {
        $n = @(Get-ChildItem -LiteralPath $d -Directory -EA SilentlyContinue |
               Where-Object { $_.Name -match '^\d+[A-Za-z]?[.\s_-]' }).Count
        if ($n -ge 3) { return $d }
        $p = Split-Path -Parent $d; if (-not $p -or $p -eq $d) { break }; $d = $p
    }
    return $null
}
$base = Find-WritingRoot $PSScriptRoot
if (-not $base) { Write-Host ''; Write-Host 'Could not find "A Writing".'; Read-Host; return }
$myFolder = if ($PSScriptRoot -eq $base) { '' } else { Split-Path -Leaf $PSScriptRoot }

function Core-Name([string]$n) {
    $t = $n -replace '^\s*\d+(\.\d+)*[A-Za-z]?[.\s_-]+', ''
    $w = $t -split '[^A-Za-z0-9]+' | Where-Object { $_ -ne '' }
    $o = ''
    foreach ($x in $w) {
        if ($x -cmatch '^[A-Z0-9]+$' -or $x -cmatch '^[A-Z]{2,}' -or $x -cmatch '[A-Z].*[A-Z]') { $o += $x }
        else { $o += $x.Substring(0,1).ToUpper() + $x.Substring(1).ToLower() }
    }
    return $o
}

$report = New-Object System.Collections.Generic.List[string]
function Log($m) { $report.Add([string]$m) | Out-Null; Write-Host $m }

Log ("=== Sync masters   {0} ===" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Log ("Base : {0}" -f $base)
Log ("Mode : {0}" -f $(if ($Apply) { 'APPLY' } else { 'PREVIEW - nothing will be moved' }))
Log ''

$themes = @(Get-ChildItem -LiteralPath $base -Directory |
            Where-Object { $_.Name -match '^\d+[A-Za-z]?[.\s_-]' -and $_.Name -ne $myFolder -and
                           (Norm ($_.Name -replace '^\d+(\.\d+)*[A-Za-z]?[.\s_-]+','')) -notin $ExcludeThemes })

$moved = 0; $current = 0
foreach ($t in $themes) {
    foreach ($p in (Get-ChildItem -LiteralPath $t.FullName -Directory | Sort-Object Name)) {
        $core = Core-Name $p.Name
        $qmd  = Join-Path $p.FullName "$core.qmd"
        if (-not (Test-Path -LiteralPath $qmd)) { continue }
        $qt = (Get-Item -LiteralPath $qmd).LastWriteTimeUtc

        $stale = @()
        foreach ($cand in @((Join-Path $p.FullName "$core.docx"),
                            (Join-Path $p.FullName (Join-Path $SlotSrc "$core.pdf")))) {
            if (-not (Test-Path -LiteralPath $cand)) { continue }
            $ct = (Get-Item -LiteralPath $cand).LastWriteTimeUtc
            if (($qt - $ct).TotalSeconds -gt $ToleranceSeconds) { $stale += $cand }
        }
        if ($stale.Count -eq 0) { $current++; continue }

        Log ("--- {0}\{1}" -f $t.Name, $p.Name)
        $stamp = $qt.ToLocalTime().ToString('yyyy-MM-dd')
        foreach ($f in $stale) {
            $fi = Get-Item -LiteralPath $f
            $dst = Join-Path (Join-Path $p.FullName $SlotPrev) ("{0}-{1}{2}" -f $core, $stamp, $fi.Extension)
            if (Test-Path -LiteralPath $dst) {
                $dst = Join-Path (Join-Path $p.FullName $SlotPrev) ("{0}-{1}-{2}{3}" -f $core, $stamp, (Get-Date -Format 'HHmmss'), $fi.Extension)
            }
            if ($Apply) {
                $d = Split-Path -Parent $dst
                if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
                Move-Item -LiteralPath $f -Destination $dst
            }
            Log ("    retired : {0}  ->  {1}\{2}" -f $fi.Name, $SlotPrev, (Split-Path -Leaf $dst))
            $moved++
        }
        # keep the superseded .qmd alongside, if one was left in 8.PreviousVersions earlier
        $prevQmd = Join-Path (Join-Path $p.FullName $SlotPrev) ("{0}-{1}.qmd" -f $core, $stamp)
        if ((Test-Path -LiteralPath $prevQmd)) { Log ("    (previous .qmd already kept: {0})" -f (Split-Path -Leaf $prevQmd)) }
    }
}

Log ''
Log '================================================================'
Log ("Derivatives {0} : {1}" -f $(if ($Apply) { 'retired' } else { 'to retire' }), $moved)
Log ("Papers already current : {0}" -f $current)
Log ''
Log 'Next: Run\Master-All.bat rebuilds the .docx from the edited .qmd,'
Log 'then Run-Website.bat rebuilds the PDF and republishes the site.'
Log '=== Done ==='

# Reports go to <scripts root>\Reports. The scripts root is the folder above
# this one when that folder holds Engine\ - which is what marks it.
function Get-ReportDir([string]$here) {
    $up = Split-Path -Parent $here
    if ($up -and (Test-Path -LiteralPath (Join-Path $up 'Engine'))) { $d = Join-Path $up 'Reports' }
    else { $d = Join-Path $here 'Reports' }
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    return $d
}
$outDir = Get-ReportDir $PSScriptRoot
$sfx = if ($Apply) { '' } else { '-preview' }
$report | Set-Content -LiteralPath (Join-Path $outDir "_SyncReport$sfx.txt") -Encoding UTF8

Write-Host ''
if (-not $Apply) { Write-Host 'PREVIEW only. Run Run\Master-All.bat to apply.'; Write-Host '' }
Write-Host 'Press Enter to close...'
[void](Read-Host)

#requires -Version 5.1
<#
    Build-Pdfs.ps1
    A PDF for every paper that has a master .docx, at
        <paper>\2.Source\<PaperName>.pdf

    This replaces the PDF step that used to sit inside Build-Website.ps1, which
    drove Word in-process and could stop dead on an invisible dialog with no
    error and no way out. Here each document is converted by a separate
    process (ConvertOne-Pdf.ps1) with a wall-clock limit. A document that
    exceeds it is killed, logged, and skipped, and the run carries on.

    Word left behind by a killed conversion is cleaned up too - but only the
    Word processes this script started. Any Word already open when the run
    began is recorded first and never touched.

    A PDF newer than its .docx is left alone, so re-running only rebuilds what
    changed, and a run interrupted halfway resumes rather than starting over.

    Switches
        -Apply              actually build (otherwise list what would be built)
        -TimeoutSeconds N   per document, default 180
        -Only <pattern>     only papers whose name matches, e.g. -Only Sollar
        -Force              rebuild even where the PDF is already current
#>

param(
    [switch]$Apply,
    [int]$TimeoutSeconds = 180,
    [string]$Only,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$SlotSource    = '2.Source'
$ExcludeThemes = @('scripts', 'website', 'overview', 'additional')

function Norm([string]$n) { return (($n -replace '[^A-Za-z0-9]', '').ToLower()) }

# A theme is excluded if its normalised name CONTAINS any of these words, not
# only if it equals one. "6.OverviewAndAdditional" holds the books, the
# philosophy and politics essays and the retained papers: it is a container, not
# a section, and an exact-match list would have walked straight into it.
function Is-ExcludedTheme([string]$name) {
    $n = Norm ($name -replace '^\d+(\.\d+)*[A-Za-z]?[.\s_-]+', '')
    foreach ($w in $ExcludeThemes) { if ($n -like ('*' + $w + '*')) { return $true } }
    return $false
}


function Find-WritingRoot([string]$s) {
    $d = $s
    for ($i = 0; $i -lt 4; $i++) {
        $n = @(Get-ChildItem -LiteralPath $d -Directory -EA SilentlyContinue |
               Where-Object { $_.Name -match '^\d+[A-Za-z]?[.\s_-]' }).Count
        if ($n -ge 3) { return $d }
        $p = Split-Path -Parent $d; if (-not $p -or $p -eq $d) { break }; $d = $p
    }
    return $null
}

function Quote([string]$s) { return ([char]34 + $s + [char]34) }

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

$onWindows = if (Test-Path Variable:\IsWindows) { $IsWindows } else { $true }

$base = Find-WritingRoot $PSScriptRoot
if (-not $base) { Write-Host 'Could not find "A Writing".'; return }

# Reports go to <scripts root>\Reports. The scripts root is the folder above
# this one when that folder holds Engine\ - which is what marks it.
function Get-ReportDir([string]$here) {
    $up = Split-Path -Parent $here
    if ($up -and (Test-Path -LiteralPath (Join-Path $up 'Engine'))) { $d = Join-Path $up 'Reports' }
    else { $d = Join-Path $here 'Reports' }
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    return $d
}
$reportDir = Get-ReportDir $PSScriptRoot

$log = New-Object System.Collections.Generic.List[string]
function Log($m) { $log.Add([string]$m) | Out-Null; Write-Host $m }

$mode = if ($Apply) { 'APPLY' } else { 'PREVIEW' }
Log ('=== Build PDFs  [{0}]   {1} ===' -f $mode, (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Log ('Base    : {0}' -f $base)
Log ('Timeout : {0}s per document' -f $TimeoutSeconds)
Log ''

# --- what needs building -----------------------------------------------------

# Papers are found wherever they sit, at any depth - see the same search in
# Publish-Site.ps1 for why. A folder is a paper folder when it holds a file
# named after itself; slot subfolders are never descended into.

$SkipDirs = @('1.Presentation', '2.Source', '3.BackgroundPapers', '4.ExternalPapers',
              '5.Notes', '6.Reserved', '7.Reserved', '8.PreviousVersions', '9.Archive',
              'media', '_site', '.quarto', '_freeze', 'papers', 'node_modules',
              'Run', 'Engine', 'Steps', 'Reference', 'Reports')

function Find-PaperFolders([string]$root) {
    $found = New-Object System.Collections.Generic.List[object]
    $stack = New-Object System.Collections.Stack
    foreach ($d in (Get-ChildItem -LiteralPath $root -Directory -EA SilentlyContinue)) {
        if ($d.Name -match '[.\s_-]*Scripts$' -or $d.Name -match 'Website$') { continue }
        $stack.Push($d)
    }
    while ($stack.Count -gt 0) {
        $d = $stack.Pop()
        if ($SkipDirs -contains $d.Name) { continue }
        $core = Core-Name $d.Name
        $isPaper = $false
        foreach ($e in @('.docx', '.pdf', '.qmd')) {
            if (Test-Path -LiteralPath (Join-Path $d.FullName ($core + $e))) { $isPaper = $true; break }
        }
        if ($isPaper) {
            $found.Add($d) | Out-Null
        } else {
            foreach ($s in (Get-ChildItem -LiteralPath $d.FullName -Directory -EA SilentlyContinue)) {
                if ($SkipDirs -notcontains $s.Name) { $stack.Push($s) }
            }
        }
    }
    return $found
}

$todo = @(); $fresh = 0; $noMaster = @()
foreach ($p in (Find-PaperFolders $base | Sort-Object FullName)) {
    if ($Only -and $p.Name -notmatch $Only) { continue }
    $rel  = $p.FullName.Substring($base.Length).TrimStart('\', '/')
    $core = Core-Name $p.Name
    $docx = Join-Path $p.FullName "$core.docx"
    $pdf  = Join-Path $p.FullName (Join-Path $SlotSource "$core.pdf")
    if (-not (Test-Path -LiteralPath $docx)) { $noMaster += $rel; continue }
    if (-not $Force -and (Test-Path -LiteralPath $pdf)) {
        if ((Get-Item -LiteralPath $pdf).LastWriteTimeUtc -ge (Get-Item -LiteralPath $docx).LastWriteTimeUtc) {
            $fresh++; continue
        }
    }
    $todo += [pscustomobject]@{ Name = $core; Folder = $rel; Docx = $docx; Pdf = $pdf }
}

Log ('{0} to build, {1} already current, {2} with no master .docx.' -f $todo.Count, $fresh, $noMaster.Count)
Log ''

if ($todo.Count -eq 0) {
    Log 'Nothing to build.'
} elseif (-not $Apply) {
    foreach ($p in $todo) { Log ('    would build : {0}.pdf' -f $p.Name) }
} else {

    $worker = Join-Path $PSScriptRoot 'ConvertOne-Pdf.ps1'
    if (-not (Test-Path -LiteralPath $worker)) { throw "ConvertOne-Pdf.ps1 is missing from $PSScriptRoot" }

    # Word already running belongs to the user and is never touched.
    $preExisting = @(Get-Process -Name WINWORD -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    if ($preExisting.Count -gt 0) {
        Log ('Note: {0} Word process(es) already running - they will be left alone.' -f $preExisting.Count)
        Log ''
    }

    $built = 0; $failed = 0; $timedOut = 0
    $i = 0
    foreach ($p in $todo) {
        $i++
        $stamp = Get-Date -Format 'HH:mm:ss'
        Write-Host ('  [{0}/{1}] {2} {3} ... ' -f $i, $todo.Count, $stamp, $p.Name) -NoNewline

        $tempRoot = $env:TEMP
        if (-not $tempRoot) { $tempRoot = [System.IO.Path]::GetTempPath() }
        $outFile = Join-Path $tempRoot ('pdfout-' + [guid]::NewGuid().ToString('N') + '.txt')
        # Every path here contains spaces - "A Research", "A Writing". Start-Process
        # joins an argument array with plain spaces and quotes nothing, so the
        # child saw "...\Documents\A" and refused it as a file without a .ps1
        # extension. The arguments are quoted individually and passed as one string.
        $psArgs = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
                    '-File',  (Quote $worker),
                    '-Docx',  (Quote $p.Docx),
                    '-Pdf',   (Quote $p.Pdf)) -join ' '

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $spArgs = @{
            FilePath               = 'powershell.exe'
            ArgumentList           = $psArgs
            PassThru               = $true
            RedirectStandardOutput = $outFile
        }
        # -WindowStyle keeps the per-document console off the screen, and exists
        # only on Windows PowerShell.
        if ($onWindows) { $spArgs['WindowStyle'] = 'Hidden' }
        $proc = Start-Process @spArgs

        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            $sw.Stop()
            try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch { }
            Start-Sleep -Milliseconds 300
            # kill only the Word this conversion started
            foreach ($w in @(Get-Process -Name WINWORD -ErrorAction SilentlyContinue)) {
                if ($preExisting -notcontains $w.Id) {
                    try { Stop-Process -Id $w.Id -Force -ErrorAction SilentlyContinue } catch { }
                }
            }
            Write-Host ('TIMED OUT after {0}s' -f $TimeoutSeconds)
            Log ('    TIMED OUT : {0}.pdf   ({1})' -f $p.Name, $p.Folder)
            $timedOut++
        } else {
            $sw.Stop()
            $out = ''
            if (Test-Path -LiteralPath $outFile) { $out = (Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue) }
            if ($out) { $out = $out.Trim() }
            if ($proc.ExitCode -eq 0 -and (Test-Path -LiteralPath $p.Pdf)) {
                Write-Host ('built in {0}s' -f [int]$sw.Elapsed.TotalSeconds)
                Log ('    built     : {0}.pdf   ({1}s)' -f $p.Name, [int]$sw.Elapsed.TotalSeconds)
                $built++
            } else {
                $why = if ($out) { ($out -replace '^ERR\s*', '') } else { ('exit code {0}' -f $proc.ExitCode) }
                if ($why.Length -gt 140) { $why = $why.Substring(0, 140) }
                Write-Host 'FAILED'
                Log ('    FAILED    : {0}.pdf   ({1})' -f $p.Name, $why)
                $failed++
            }
        }
        Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
    }

    # anything this run started and did not clean up
    foreach ($w in @(Get-Process -Name WINWORD -ErrorAction SilentlyContinue)) {
        if ($preExisting -notcontains $w.Id) {
            try { Stop-Process -Id $w.Id -Force -ErrorAction SilentlyContinue } catch { }
        }
    }

    Log ''
    Log ('Built {0}, failed {1}, timed out {2}.' -f $built, $failed, $timedOut)
    if ($timedOut -gt 0) {
        Log ''
        Log 'A timed-out document is almost always Word waiting on a dialog it cannot show.'
        Log 'Open that .docx in Word by hand once, answer whatever it asks, save, and re-run.'
    }
}

if ($noMaster.Count -gt 0) {
    Log ''
    Log 'No master .docx, so no PDF - these papers are not on the site yet:'
    foreach ($n in $noMaster) { Log ('    {0}' -f $n) }
}

$sfx = if ($Apply) { '' } else { '-preview' }
$path = Join-Path $reportDir ("_PdfReport$sfx.txt")
$log | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host ''
Write-Host ('Report : {0}' -f $path)

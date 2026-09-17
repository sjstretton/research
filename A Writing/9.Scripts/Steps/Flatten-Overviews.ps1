#requires -Version 5.1
<#
    Flatten-Overviews.ps1
    A section overview is not a paper. It is one Word file at the top of the
    section it describes, not a folder of its own.

    BEFORE                                  AFTER
        1.ClimateAndFiscalPolicy\               1.ClimateAndFiscalPolicy\
            1.0.OverviewClimateAndFiscalPolicy\     1.0.OverviewClimateAndFiscalPolicy.docx
                OverviewClimateAndFiscalPolicy.qmd  1.1.OpenEconomyCarbonPricing\
                OverviewClimateAndFiscalPolicy.docx ...
                2.Source\...
            1.1.OpenEconomyCarbonPricing\

    The published address does not change. The site names a file by its folder or
    filename with the leading number stripped, so 1.0.OverviewClimateAndFiscalPolicy.docx
    publishes as OverviewClimateAndFiscalPolicy.docx exactly as the folder did.

    The .qmd goes. An overview is now a Word document and is edited in Word;
    Convert-Documents skips these files so that no .qmd reappears beside them.

    WHAT IT LOOKS FOR
        Nothing is listed here - the tree is searched. A folder counts when its
        name begins with a <number>.0 prefix and the folder it sits in already
        holds a .docx with the same <number>.0 prefix. That is the replacement,
        whatever it is called, so 9.0.OverviewRetainedWork\ is retired by
        9.0.OverviewAdditional.docx beside it.

        Only then does the folder go to the Recycle Bin. A .0 folder whose
        replacement is not there yet is left exactly where it is and reported -
        nothing is removed on the assumption that something else worked.

    Renaming or renumbering a section changes nothing here.

    Nothing is overwritten. Running it twice is a no-op.

    Usage
        Run\Flatten-Overviews.bat   lists what it would remove, then asks
#>

param(
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

# Never descended into: the machinery, the build output, and a paper's own slots.
$SkipDirs = @('1.Presentation', '2.Source', '3.BackgroundPapers', '4.ExternalPapers',
              '5.Notes', '6.Reserved', '7.Reserved', '8.PreviousVersions', '9.Archive',
              'media', '_site', '.quarto', '_freeze', 'papers', 'node_modules',
              'Run', 'Engine', 'Steps', 'Reference', 'Reports')

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

$base = Find-WritingRoot $PSScriptRoot
if (-not $base) { Write-Host 'Could not find "A Writing".'; return }

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
Log ('=== Flatten overviews  [{0}]   {1} ===' -f $mode, (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Log ('Base : {0}' -f $base)
Log ''

# ------------------------------------------------------------- the search ----

# Every .0 folder in the tree, wherever the sections happen to sit today.
function Find-OverviewFolders([string]$root) {
    $found = New-Object System.Collections.Generic.List[object]
    $stack = New-Object System.Collections.Stack
    foreach ($d in (Get-ChildItem -LiteralPath $root -Directory -EA SilentlyContinue)) {
        if ($d.Name -match '[.\s_-]*Scripts$' -or $d.Name -match 'Website$') { continue }
        $stack.Push($d)
    }
    while ($stack.Count -gt 0) {
        $d = $stack.Pop()
        if ($SkipDirs -contains $d.Name) { continue }
        if ($d.Name -match '^(\d+)\.0[.\s_-]') {
            $found.Add($d) | Out-Null
            continue                      # a .0 folder holds no sections
        }
        foreach ($s in (Get-ChildItem -LiteralPath $d.FullName -Directory -EA SilentlyContinue)) {
            if ($SkipDirs -notcontains $s.Name) { $stack.Push($s) }
        }
    }
    return $found
}

$folders = @(Find-OverviewFolders $base | Sort-Object FullName)

Log ('--- {0} overview folder(s) found' -f $folders.Count)
Log ''

$removed = 0; $waiting = 0

foreach ($f in $folders) {
    $null = $f.Name -match '^(\d+)\.0[.\s_-]'
    $num  = $Matches[1]
    $sec  = Split-Path -Parent $f.FullName
    $rel  = $f.FullName.Substring($base.Length).TrimStart('\', '/')

    # the replacement: any .docx beside it carrying the same <number>.0 prefix
    $pattern = '^' + [regex]::Escape($num) + '\.0[.\s_-]'
    $repl = @(Get-ChildItem -LiteralPath $sec -File -Filter '*.docx' -EA SilentlyContinue |
              Where-Object { $_.Name -match $pattern } | Select-Object -First 1)

    if ($repl.Count -eq 0) {
        Log ('   WAITING: {0}\   stays - no {1}.0 .docx beside it yet' -f $rel, $num)
        $waiting++
        continue
    }

    Log ('   BIN    : {0}\' -f $rel)
    Log ('       replaced by   {0}' -f $repl[0].Name)
    if ($Apply) {
        $onWindows = if (Test-Path Variable:\IsWindows) { $IsWindows } else { $true }
        if ($onWindows) { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue }
        if ($onWindows -and ($null -ne ('Microsoft.VisualBasic.FileIO.FileSystem' -as [type]))) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                $f.FullName,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
        } else {
            Remove-Item -LiteralPath $f.FullName -Recurse -Force
        }
    }
    $removed++
}

Log ''
Log '================================================================'
if ($folders.Count -eq 0) {
    Log 'Nothing to do - every section overview is already a single Word file.'
} else {
    Log ('Removed {0}, waiting on a replacement {1}.' -f $removed, $waiting)
}
if ($waiting -gt 0) {
    Log ''
    Log 'A folder is only removed once a .docx with the same number sits beside it,'
    Log 'so nothing is lost if a document did not arrive. Put the file there and'
    Log 'run again.'
}
if ($Apply) {
    Log ''
    Log 'Run Run\Master-Website.bat next to republish. The addresses do not change.'
} else {
    Log ''
    Log 'PREVIEW only - nothing was removed.'
}

$sfx = if ($Apply) { '' } else { '-preview' }
$path = Join-Path $reportDir ("_FlattenReport$sfx.txt")
$log | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host ''
Write-Host ('Report : {0}' -f $path)

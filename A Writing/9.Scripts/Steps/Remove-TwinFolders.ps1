#requires -Version 5.1
<#
    Remove-TwinFolders.ps1
    Two folders at the root of A Writing where there should be one.

        0. Overview          and   0.Overview
        6. Overview and Additional and 6.OverviewAndAdditional

    This happens when something writes to the old spelling after the folder has
    been renamed - Windows creates the old name again rather than complaining,
    and the tree quietly forks. The copy with spaces is always the ghost,
    because Rename-Folders has already produced the space-free one.

    WHAT IT DOES
        Finds any two folders at the root whose names are the same once spaces,
        punctuation and case are taken off. Reads every file in the ghost and
        looks for the same relative path in the live one. Only when every file
        is accounted for does the ghost go to the Recycle Bin.

        If even one file exists nowhere else, nothing is removed and that file
        is named, so you can look at it and decide.

    Nothing in the live folder is ever touched. Running it twice is a no-op.

    Usage
        Run\Remove-TwinFolders.bat   lists what it found, then asks
#>

param(
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

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
Log ('=== Remove twin folders  [{0}]   {1} ===' -f $mode, (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Log ('Base : {0}' -f $base)
Log ''

function Norm([string]$n) { return (($n -replace '[^A-Za-z0-9]', '').ToLower()) }

# --------------------------------------------------------------- the pairs --

$dirs  = @(Get-ChildItem -LiteralPath $base -Directory -EA SilentlyContinue)
$pairs = New-Object System.Collections.Generic.List[object]

foreach ($g in ($dirs | Group-Object { Norm $_.Name })) {
    if ($g.Count -lt 2) { continue }
    # the ghost is the one whose name still has a space; failing that, the older
    $ghost = $g.Group | Where-Object { $_.Name -match '\s' } | Select-Object -First 1
    if (-not $ghost) { $ghost = $g.Group | Sort-Object LastWriteTime | Select-Object -First 1 }
    $live  = $g.Group | Where-Object { $_.FullName -ne $ghost.FullName } | Select-Object -First 1
    $pairs.Add([pscustomobject]@{ Ghost = $ghost; Live = $live }) | Out-Null
}

if ($pairs.Count -eq 0) {
    Log 'Nothing to do - no two folders at the root are the same name twice.'
    $log | Set-Content -LiteralPath (Join-Path $reportDir '_TwinFolderReport.txt') -Encoding UTF8
    return
}

$removed = 0; $held = 0

foreach ($p in $pairs) {
    Log ('--- "{0}"   against   "{1}"' -f $p.Ghost.Name, $p.Live.Name)

    $files = @(Get-ChildItem -LiteralPath $p.Ghost.FullName -File -Recurse -Force -EA SilentlyContinue)
    Log ('    {0} file(s) in "{1}"' -f $files.Count, $p.Ghost.Name)

    $orphans = New-Object System.Collections.Generic.List[string]
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($p.Ghost.FullName.Length).TrimStart('\', '/')
        if (Test-Path -LiteralPath (Join-Path $p.Live.FullName $rel)) {
            Log ('    in both  : {0}' -f $rel)
        } else {
            Log ('    ONLY HERE: {0}' -f $rel)
            $orphans.Add($rel) | Out-Null
        }
    }

    if ($orphans.Count -gt 0) {
        Log ('    HELD - {0} file(s) exist nowhere else, so "{1}" stays.' -f $orphans.Count, $p.Ghost.Name)
        $held++
        Log ''
        continue
    }

    Log ('    BIN      : "{0}"   [every file in it is already in "{1}"]' -f $p.Ghost.Name, $p.Live.Name)
    if ($Apply) {
        $onWindows = if (Test-Path Variable:\IsWindows) { $IsWindows } else { $true }
        if ($onWindows) { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue }
        if ($onWindows -and ($null -ne ('Microsoft.VisualBasic.FileIO.FileSystem' -as [type]))) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                $p.Ghost.FullName,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
        } else {
            Remove-Item -LiteralPath $p.Ghost.FullName -Recurse -Force
        }
    }
    $removed++
    Log ''
}

Log '================================================================'
Log ('Removed {0}, held back {1}.' -f $removed, $held)
if ($held -gt 0) {
    Log ''
    Log 'A held folder has something in it that exists nowhere else. Move what you'
    Log 'want to keep into the live folder and run this again.'
}
if (-not $Apply) {
    Log ''
    Log 'PREVIEW only - nothing was removed.'
}

$sfx = if ($Apply) { '' } else { '-preview' }
$path = Join-Path $reportDir ("_TwinFolderReport$sfx.txt")
$log | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host ''
Write-Host ('Report : {0}' -f $path)

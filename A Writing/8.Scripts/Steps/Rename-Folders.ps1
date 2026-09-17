#requires -Version 5.1
<#
    Rename-Folders.ps1
    Renames every folder under "A Writing" to a space-free form, with a dot
    between the number and the name.

        1. Climate and Fiscal Policy     ->  1.ClimateAndFiscalPolicy
        1.1 Open Economy Carbon Pricing  ->  1.1.OpenEconomyCarbonPricing
        1.3 Iron, Steel, CBAM            ->  1.3.IronSteelCBAM
        2. Source                        ->  2.Source
        3. Background Papers             ->  3.BackgroundPapers
        Voting Patterns                  ->  VotingPatterns
        Feebates Brief                   ->  FeebatesBrief

    It also converts anything already renamed with an underscore:

        1_ClimateAndFiscalPolicy         ->  1.ClimateAndFiscalPolicy
        2_Source                         ->  2.Source

    The leading number keeps its dots; everything after it is CamelCase joined
    to the number by the separator below. Acronyms keep their case: CBAM, MDB,
    SLIDIs, PPAs, TFP. Change $Separator to '_' or '-' if you change your mind.

    NOT renamed:
      - anything starting with _ or . (_to_delete, _Scripts, .git)
      - folders that already have no spaces and no number prefix (images,
        Manifesto, NineEleven, Philosophy) - so relative paths that already
        work keep working
      - files. Only folders are touched.

    REFERENCES
    Before renaming, every .qmd .rmd .md .tex .r .py .yml .yaml file under
    "A Writing" is scanned for path-like uses of the old names and rewritten:
        2.%20Source/images/x.png   ->  2_Source/images/x.png
        3. Background Papers\y     ->  3_BackgroundPapers\y
    A name has to be followed or preceded by a slash to count, so prose
    headings like "# 1. Climate and Fiscal Policy" in research.qmd are left
    alone. _CoreFiles.txt is rewritten too.

    SAFETY
    Nothing is deleted. A rename whose target already exists is skipped and
    reported. Deepest folders are renamed first. Re-running is a no-op.

    USAGE
        Preview-Rename.bat    dry run, writes the report only
        Run-Rename.bat        does it
#>

param(
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

# The character between the number and the name.
$Separator = '.'

$TextExt   = @('.qmd','.rmd','.md','.tex','.r','.py','.yml','.yaml')
$SkipDirs  = '^[_.]'                      # _to_delete, _Scripts, .git
$NumPrefix = '^(\d+(?:\.\d+)*[A-Za-z]?)[.\s_-]+(.*)$'

# --- locate "A Writing" ------------------------------------------------------
function Find-WritingRoot([string]$start) {
    $d = $start
    for ($i = 0; $i -lt 4; $i++) {
        $n = @(Get-ChildItem -LiteralPath $d -Directory -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '^\d+[A-Za-z]?[.\s_-]' }).Count
        if ($n -ge 3) { return $d }
        $p = Split-Path -Parent $d
        if (-not $p -or $p -eq $d) { break }
        $d = $p
    }
    return $null
}

if ($PSScriptRoot -match '[\\/](_superseded|_Scripts)([\\/]|$)') {
    Write-Host ''; Write-Host 'This is an old copy. Run the live one instead.'
    Write-Host ''; Write-Host 'Press Enter to close...'; [void](Read-Host); return
}

$base = Find-WritingRoot $PSScriptRoot
if (-not $base) {
    Write-Host ''
    Write-Host 'Could not find "A Writing" (a folder holding several numbered folders)'
    Write-Host "from: $PSScriptRoot"
    Write-Host ''; Write-Host 'Press Enter to close...'; [void](Read-Host); return
}
Set-Location -LiteralPath $base          # so this script's own folder is not locked

$report = New-Object System.Collections.Generic.List[string]
function Log($m) { $report.Add([string]$m) | Out-Null; Write-Host $m }
function Blank() { Log '' }

# --- naming ------------------------------------------------------------------
function To-Camel([string]$text) {
    $words = $text -split '[^A-Za-z0-9]+' | Where-Object { $_ -ne '' }
    $out = ''
    foreach ($w in $words) {
        if ($w -cmatch '^[A-Z0-9]+$' -or $w -cmatch '^[A-Z]{2,}' -or $w -cmatch '[A-Z].*[A-Z]') {
            $out += $w
        } else {
            $out += $w.Substring(0,1).ToUpper() + $w.Substring(1).ToLower()
        }
    }
    return $out
}

function Convert-FolderName([string]$name) {
    if ($name -match $SkipDirs) { return $name }     # _to_delete, _Scripts, .git
    if ($name -match $NumPrefix) {
        $num  = $Matches[1]
        $rest = $Matches[2]
        if ($rest -eq '') { return $name }
        # Already clean? Keep it exactly as written - a deliberate hyphen in
        # "5A.Analytics-ExciseDiagnostic" is not ours to remove.
        if ($rest -notmatch '^[A-Za-z0-9._-]+$') { $rest = To-Camel $rest }
        $new = $num + $Separator + $rest
    }
    elseif ($name -match '[^A-Za-z0-9._-]') { $new = To-Camel $name }
    elseif ($name -match '_')               { $new = $name -replace '_', $Separator }
    else                                    { return $name }

    # Windows will not keep a trailing dot, and '..' in a name is asking for it.
    if ($new -match '\.\.' -or $new.EndsWith('.') -or $new -eq '') { return $name }
    return $new
}

# --- collect the renames, deepest first --------------------------------------
Log ("=== Rename folders   separator '{0}'   {1} ===" -f $Separator, (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Log ("Base : {0}" -f $base)
Log ("Mode : {0}" -f $(if ($Apply) { 'APPLY - folders will be renamed' } else { 'PREVIEW - nothing will be changed' }))
Blank

$allDirs = @(Get-ChildItem -LiteralPath $base -Directory -Recurse -Force |
             Where-Object { $_.FullName -notmatch '[\\/][_.][^\\/]*([\\/]|$)' } |
             Sort-Object { ($_.FullName -split '[\\/]').Count } -Descending)

$renames = @()          # @{ Old; New; OldLeaf; NewLeaf; Parent }
foreach ($d in $allDirs) {
    $newLeaf = Convert-FolderName $d.Name
    if ($newLeaf -ceq $d.Name) { continue }
    $renames += [pscustomobject]@{
        Old     = $d.FullName
        Parent  = $d.Parent.FullName
        OldLeaf = $d.Name
        NewLeaf = $newLeaf
        New     = (Join-Path $d.Parent.FullName $newLeaf)
    }
}

if ($renames.Count -eq 0) {
    Log 'Nothing to rename - every folder already matches the convention.'
} else {
    Log ("{0} folders to rename." -f $renames.Count)
}
Blank

# --- rewrite references first, while the old names still resolve -------------
function Escape-Variants([string]$leaf) {
    # the raw name, and the percent-encoded form a renderer may have written
    $v = @($leaf)
    if ($leaf -match ' ') { $v += ($leaf -replace ' ', '%20') }
    return $v
}

# Windows paths are case-insensitive but these comparisons are not, so make the
# regex rewriting case-insensitive to match how the filesystem behaves.

$pairs = @()
foreach ($r in $renames) {
    foreach ($variant in (Escape-Variants $r.OldLeaf)) {
        $e = [regex]::Escape($variant)
        # must sit in a path: followed by / or \, or preceded by one
        $pairs += [pscustomobject]@{ Pattern = "(?i)(?<=[\\/])$e(?=[\\/])"; Replace = $r.NewLeaf }
        $pairs += [pscustomobject]@{ Pattern = "(?i)(?<![\w%])$e(?=[\\/])";  Replace = $r.NewLeaf }
        $pairs += [pscustomobject]@{ Pattern = "(?i)(?<=[\\/])$e(?![\w%])";  Replace = $r.NewLeaf }
    }
}

$touched = 0
if ($pairs.Count -gt 0) {
    Log '--- references'
    $textFiles = @(Get-ChildItem -LiteralPath $base -File -Recurse -Force |
                   Where-Object { ($TextExt -contains $_.Extension.ToLower()) -or ($_.Name -eq '_CoreFiles.txt') })
    foreach ($f in $textFiles) {
        $txt = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
        if ([string]::IsNullOrEmpty($txt)) { continue }
        $orig = $txt
        foreach ($p in $pairs) { $txt = [regex]::Replace($txt, $p.Pattern, $p.Replace) }
        if ($txt -ne $orig) {
            if ($Apply) { [System.IO.File]::WriteAllText($f.FullName, $txt, (New-Object System.Text.UTF8Encoding($false))) }
            Log ("    rewritten : {0}" -f $f.FullName.Substring($base.Length).TrimStart('\','/'))
            $touched++
        }
    }
    if ($touched -eq 0) { Log '    no path references needed changing' }
    Blank
}

# --- do the renames ----------------------------------------------------------
Log '--- folders'
$done = 0; $skipped = 0; $failed = 0
$myDir = $PSScriptRoot        # may itself get renamed below
foreach ($r in $renames) {
    $rel = $r.Old.Substring($base.Length).TrimStart('\','/')
    if (-not (Test-Path -LiteralPath $r.Old)) { Log ("    GONE   : {0}" -f $rel); continue }
    if ((Test-Path -LiteralPath $r.New) -and ($r.New -cne $r.Old)) {
        Log ("    SKIP   : {0}   (target already exists: {1})" -f $rel, $r.NewLeaf)
        $skipped++
        continue
    }
    if ($Apply) {
        try {
            Rename-Item -LiteralPath $r.Old -NewName $r.NewLeaf
        } catch {
            Log ("    FAILED : {0}   ({1})" -f $rel, $_.Exception.Message)
            $failed++
            continue
        }
    }
    Log ("    {0}   ->   {1}" -f $rel, $r.NewLeaf)
    if ($r.Old -eq $myDir) { $myDir = $r.New }     # our own folder moved
    $done++
}

Blank
Log '================================================================'
Log ("Folders renamed {0} : {1}" -f $(if ($Apply) { '' } else { '(planned)' }), $done)
Log ("Skipped (target exists)  : {0}" -f $skipped)
Log ("Failed                   : {0}" -f $failed)
Log ("Files with paths rewritten: {0}" -f $touched)
Blank
if ($failed -gt 0) {
    Log 'A failure is almost always a file open in Word, Excel or an editor.'
    Log 'Close it and run this again - the script is safe to re-run.'
    Blank
}
Log 'NOTE: this script cannot rename its own folder while it is running.'
Log 'If the folder holding these scripts still has a space in its name,'
Log 'rename it in Explorer. Nothing depends on what it is called.'
Blank
Log '=== Done ==='

if (-not (Test-Path -LiteralPath $myDir)) { $myDir = $PSScriptRoot }
# Reports go to <scripts root>\Reports. The scripts root is the folder above
# this one when that folder holds Engine\ - which is what marks it.
function Get-ReportDir([string]$here) {
    $up = Split-Path -Parent $here
    if ($up -and (Test-Path -LiteralPath (Join-Path $up 'Engine'))) { $d = Join-Path $up 'Reports' }
    else { $d = Join-Path $here 'Reports' }
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    return $d
}
$outDir = Get-ReportDir $myDir
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$reportPath = Join-Path $outDir ('_RenameReport{0}.txt' -f $(if ($Apply) { '' } else { '-preview' }))
$report | Set-Content -LiteralPath $reportPath -Encoding UTF8

Write-Host ''
Write-Host "Report : $reportPath"
if (-not $Apply) {
    Write-Host ''
    Write-Host 'This was a PREVIEW. Nothing was changed.'
    Write-Host 'Read the report, then run Run-Rename.bat.'
} else {
    Write-Host ''
    Write-Host 'Now run Preview-Reorganize.bat to confirm the layout still reads correctly.'
}
Write-Host ''
Write-Host 'Press Enter to close...'
[void](Read-Host)

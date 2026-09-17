# Reorganize the "1.1 Open Economy Carbon Pricing" folder.
# Safe by design: only MOVES/RENAMES files, never overwrites, never deletes a file.
# The only deletions are empty leftover folders.

$ErrorActionPreference = 'Stop'
$base = $PSScriptRoot
Set-Location -LiteralPath $base

$logDir  = Join-Path $base 'Possibly Deletable'
$logPath = Join-Path $logDir '_ReorganizeLog.txt'
$lines   = New-Object System.Collections.Generic.List[string]

function Say($msg) {
    Write-Host $msg
    $lines.Add($msg)
}

function MoveItemSafe($from, $to) {
    $src = Join-Path $base $from
    $dst = Join-Path $base $to
    if (-not (Test-Path -LiteralPath $src)) { Say "MISSING      : $from"; return }
    if (Test-Path -LiteralPath $dst)        { Say "SKIP(exists) : $to";   return }
    $parent = Split-Path -Parent $dst
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Move-Item -LiteralPath $src -Destination $dst
    Say "MOVED        : $from  ->  $to"
}

Say "=== Reorganize OECP  $(Get-Date -Format 'yyyy-MM-dd HH:mm') ==="
Say "Base: $base"
Say ""

# --- 1. New folder structure -------------------------------------------------
foreach ($d in @('Presentation and Briefing Paper',
                 'Background Materials',
                 'Background Materials\Notes',
                 'Possibly Deletable')) {
    $p = Join-Path $base $d
    if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null; Say "CREATED DIR  : $d" }
    else { Say "DIR EXISTS   : $d" }
}
Say ""

# --- 2. Main paper files, standard CamelCase stem at the folder root ---------
MoveItemSafe 'MainPaper-OpenEconomyCarbonPricing.tex'                 'OpenEconomyCarbonPricing.tex'
MoveItemSafe 'Additional Material\OECP.qmd'                           'OpenEconomyCarbonPricing.qmd'
MoveItemSafe 'Additional Material\Open_Economy_Carbon_Pricing.pdf'    'OpenEconomyCarbonPricing.pdf'
MoveItemSafe 'oecp_refs.bib'                                          'OpenEconomyCarbonPricing.bib'
Say ""

# --- 3. Presentation and Briefing Paper -------------------------------------
MoveItemSafe 'Additional Material\OECP.pptx'                                          'Presentation and Briefing Paper\Presentation-OpenEconomyCarbonPricing.pptx'
MoveItemSafe '3.1 Updating Carbon Pricing\Presentation-UpdatingCarbonPricing.pptx'    'Presentation and Briefing Paper\Presentation-UpdatingCarbonPricing.pptx'
MoveItemSafe '3.1 Updating Carbon Pricing\BriefingPaper-UpdatingCarbonPricing.docx'   'Presentation and Briefing Paper\BriefingPaper-UpdatingCarbonPricing.docx'
MoveItemSafe '3.1 Updating Carbon Pricing\WP10-Designing a Race to the Top.docx'      'Presentation and Briefing Paper\WP10-DesigningARaceToTheTop.docx'
Say ""

# --- 4. Background Materials -------------------------------------------------
MoveItemSafe 'Additional Material\OECP_Abstract.txt'                                      'Background Materials\OpenEconomyCarbonPricing-Abstract.txt'
MoveItemSafe 'Background\Carbon Consumption Tax\CarbonConsumptionTax.docx'                'Background Materials\CarbonConsumptionTax.docx'
MoveItemSafe 'Background\Carbon Consumption Tax\Notes\Carbon Pricing Version Two.txt'     'Background Materials\Notes\Carbon Pricing Version Two.txt'
MoveItemSafe 'Background\Carbon Consumption Tax\Notes\Outline to Paper on Carbon Pricing.txt' 'Background Materials\Notes\Outline to Paper on Carbon Pricing.txt'
MoveItemSafe '3.1 Updating Carbon Pricing\Notes\Feebates-Related-Comments.txt'            'Background Materials\Notes\Feebates-Related-Comments.txt'
Say ""

# --- 5. Possibly Deletable ---------------------------------------------------
MoveItemSafe 'Old Versions\main.tex'  'Possibly Deletable\OpenEconomyCarbonPricing-EarlyDraft.tex'
Say ""

# --- 6. Repoint bibliography references to the renamed .bib ------------------
foreach ($f in @('OpenEconomyCarbonPricing.tex', 'OpenEconomyCarbonPricing.qmd')) {
    $p = Join-Path $base $f
    if (Test-Path -LiteralPath $p) {
        $txt = Get-Content -LiteralPath $p -Raw
        if ($txt -match 'oecp_refs\.bib') {
            $new = $txt -replace 'oecp_refs\.bib', 'OpenEconomyCarbonPricing.bib'
            [System.IO.File]::WriteAllText($p, $new, (New-Object System.Text.UTF8Encoding($false)))
            Say "BIB REF FIXED: $f"
        } else { Say "BIB REF N/A  : $f" }
    }
}
Say ""

# --- 7. Remove leftover folders, only if empty -------------------------------
foreach ($d in @('3.1 Updating Carbon Pricing\Notes',
                 '3.1 Updating Carbon Pricing',
                 'Additional Material',
                 'Background\Carbon Consumption Tax\Notes',
                 'Background\Carbon Consumption Tax',
                 'Background',
                 'Old Versions')) {
    $p = Join-Path $base $d
    if (Test-Path -LiteralPath $p) {
        if (-not (Get-ChildItem -LiteralPath $p -Force)) {
            Remove-Item -LiteralPath $p -Force
            Say "REMOVED EMPTY: $d"
        } else {
            Say "LEFT (not empty): $d"
        }
    }
}
Say ""
Say "=== Done ==="

# --- 8. Write the log, then retire the scripts -------------------------------
if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$lines | Set-Content -LiteralPath $logPath -Encoding UTF8

foreach ($s in @('Reorganize-OECP.bat')) {
    $sp = Join-Path $base $s
    if (Test-Path -LiteralPath $sp) { Move-Item -LiteralPath $sp -Destination (Join-Path $logDir $s) -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
Write-Host "Log written to: $logPath"
Write-Host "Press Enter to close..."
[void](Read-Host)

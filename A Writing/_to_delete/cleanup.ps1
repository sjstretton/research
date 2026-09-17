# Clean up duplicates and dead files in "A Research".
#
#   Preview:          powershell -ExecutionPolicy Bypass -File .\cleanup.ps1 -DryRun
#   Move to bin:      powershell -ExecutionPolicy Bypass -File .\cleanup.ps1
#   Delete for good:  powershell -ExecutionPolicy Bypass -File .\cleanup.ps1 -Delete
#
# Default behaviour MOVES everything into "_to_delete\", mirroring its original
# folder path, so nothing is lost and you can put anything back. Use -Delete
# only once you have looked in that folder and are happy.
#
# Run this AFTER renumber.ps1. Pre-renumber paths are checked as a fallback, so
# it also works if you have not renumbered yet.

param([switch]$DryRun, [switch]$Delete)

$ErrorActionPreference = 'Stop'

$research = "C:\Users\sjstr\Documents\OneDrive\Documents\A Research"
$root     = Join-Path $research "A Writing"
$bin      = Join-Path $root "_to_delete"

$script:acted = 0; $script:skipped = 0; $script:freed = 0

function Resolve-First([string[]]$candidates) {
    foreach ($c in $candidates) {
        $p = Join-Path $root $c
        if (Test-Path -LiteralPath $p) { return @{ Rel = $c; Full = $p } }
    }
    return $null
}

function Purge([string[]]$candidates, [string]$why) {
    $hit = Resolve-First $candidates
    if (-not $hit) {
        Write-Host "  SKIP  not found      : $($candidates[0])" -ForegroundColor DarkYellow
        $script:skipped++; return
    }
    $item = Get-Item -LiteralPath $hit.Full
    $size = if ($item.PSIsContainer) {
        (Get-ChildItem -LiteralPath $hit.Full -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    } else { $item.Length }
    if (-not $size) { $size = 0 }

    $label = "{0}  ({1:N0} KB)  - {2}" -f $hit.Rel, ($size/1KB), $why

    if ($DryRun) {
        Write-Host "  WOULD $(if($Delete){'DELETE'}else{'BIN   '}) $label" -ForegroundColor Cyan
    }
    elseif ($Delete) {
        Remove-Item -LiteralPath $hit.Full -Recurse -Force
        Write-Host "  DELETED $label" -ForegroundColor Green
    }
    else {
        $dest = Join-Path $bin $hit.Rel
        $parent = Split-Path -Parent $dest
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        if (Test-Path -LiteralPath $dest) {
            Write-Host "  SKIP  already binned : $($hit.Rel)" -ForegroundColor Red
            $script:skipped++; return
        }
        Move-Item -LiteralPath $hit.Full -Destination $dest
        Write-Host "  BINNED  $label" -ForegroundColor Green
    }
    $script:acted++; $script:freed += $size
}

# Only acts if the two files are byte-identical. Protects against acting on a
# file that has diverged since I checked it.
function PurgeIfIdentical([string[]]$keepCand, [string[]]$dupCand, [string]$why) {
    $k = Resolve-First $keepCand
    $d = Resolve-First $dupCand
    if (-not $k -or -not $d) {
        Write-Host "  SKIP  pair not found : $($dupCand[0])" -ForegroundColor DarkYellow
        $script:skipped++; return
    }
    $hk = (Get-FileHash -LiteralPath $k.Full -Algorithm SHA256).Hash
    $hd = (Get-FileHash -LiteralPath $d.Full -Algorithm SHA256).Hash
    if ($hk -ne $hd) {
        Write-Host "  SKIP  NOT identical  : $($d.Rel)" -ForegroundColor Red
        Write-Host "        differs from    : $($k.Rel)  - left alone, check by hand" -ForegroundColor Red
        $script:skipped++; return
    }
    Write-Host "  hash match confirmed : $($d.Rel)" -ForegroundColor DarkGray
    Purge $dupCand $why
}

$mode = if ($DryRun) { "DRY RUN - nothing will change" }
        elseif ($Delete) { "PERMANENT DELETE" }
        else { "MOVE TO _to_delete" }
Write-Host "`n=== CLEANUP : $mode ===`n" -ForegroundColor Yellow

if ($Delete -and -not $DryRun) {
    $ans = Read-Host "This deletes permanently. There is no Recycle Bin for OneDrive scripted deletes. Type YES to continue"
    if ($ans -ne 'YES') { Write-Host "Aborted.`n" -ForegroundColor Yellow; exit }
}

# ---------------------------------------------- A. Byte-identical, self-verifying
Write-Host "A. Byte-identical duplicates (hash checked at runtime)" -ForegroundColor White

PurgeIfIdentical `
    @("3. Sovereign Incentives and MDBs\3.3 Climate Investment Trust\CIT Introduction.pptx") `
    @("3. Sovereign Incentives and MDBs\3.3 Climate Investment Trust\Archive\CIT.pptx") `
    "identical to CIT Introduction.pptx"

PurgeIfIdentical `
    @("3. Sovereign Incentives and MDBs\3.4 SLIDIs\SLIDI Sept 2024 final.docx",
      "3. Sovereign Incentives and MDBs\3.2. SLIDIs\SLIDI Sept 2024 final.docx") `
    @("3. Sovereign Incentives and MDBs\3.4 SLIDIs\Archive\SLIDI_Long.docx",
      "3. Sovereign Incentives and MDBs\3.2. SLIDIs\Archive\SLIDI_Long.docx") `
    "same bytes as SLIDI Sept 2024 final.docx"

# ---------------------------------------------- B. Verified by text comparison
Write-Host "`nB. Duplicates verified by text comparison" -ForegroundColor White

Purge @("2. Finance and Risk\2.1 Climate Finance Intermediation for Clean Power\Earlier version\WP1A-SyntheticSovereignBonds.docx",
        "2. Finance and Risk\2.2 RE Payments Intermediary Facility\Earlier version\WP1A-SyntheticSovereignBonds.docx") `
      "text identical (1.000) to 2.3\F2-SyntheticSovereignBonds.docx"

Purge @("3. Sovereign Incentives and MDBs\3.3 Climate Investment Trust\Archive\TechnicalSummary-TheClimateIncentivesTrust-Clean.docx") `
      "0.998 match to TechnicalSummary_CIT.docx"

Purge @("3. Sovereign Incentives and MDBs\3.3 Climate Investment Trust\Archive\FullPaper-TheClimateIncentivesTrust_Apr2024.docx") `
      "0.949 match to WP4- CIT.docx, which is longer and newer"

Purge @("5. Analytics\5.1 Excise-Fiscal Diagnostic\MAiSierra_Leone_Excise_Complete_Report.docx",
        "5. Analytics\Excise Diagnostic\MAiSierra_Leone_Excise_Complete_Report.docx") `
      "early AI pass with prompts still in the body"

# ---------------------------------------------- C. Empty and orphaned
Write-Host "`nC. Empty or orphaned" -ForegroundColor White

Purge @("1. Climate and Fiscal Policy\1.1 Open Economy Carbon Pricing\Background\Carbon Consumption Tax\Old",
        "1. Climate and Fiscal Policy\1.2 Carbon Consumption Tax\Old") `
      "empty folder"

Purge @("4. Modelling\4.2 CPAT - Architecture, Recoding and Fiscal Application\Background\CPAT Modelling of ETS\Power Investment Equations",
        "4. Modelling\4.1 CPAT Modelling of ETS\Power Investment Equations") `
      "orphan subfolder holding only a duplicate references.bib"

Purge @("3. Sovereign Incentives and MDBs\3.4 SLIDIs\Archive\Additional Work\NotesOnOutline.txt",
        "3. Sovereign Incentives and MDBs\3.2. SLIDIs\Archive\Additional Work\NotesOnOutline.txt") `
      "zero bytes"

Purge @("7. Books\Book2-CarbonPricingWrongTime-Extras\RightPolicyWrongTime.zip") `
      "22 bytes - empty or truncated archive"

# ---------------------------------------------- D. Outside A Writing
Write-Host "`nD. Outside A Writing" -ForegroundColor White

$wr = Join-Path $research "B Website\research.qmd"
if (Test-Path -LiteralPath $wr) {
    if ($DryRun) { Write-Host "  WOULD $(if($Delete){'DELETE'}else{'BIN   '}) B Website\research.qmd  - master now lives in A Writing" -ForegroundColor Cyan }
    elseif ($Delete) { Remove-Item -LiteralPath $wr -Force; Write-Host "  DELETED B Website\research.qmd" -ForegroundColor Green }
    else {
        $d = Join-Path $bin "B Website\research.qmd"
        New-Item -ItemType Directory -Path (Split-Path -Parent $d) -Force | Out-Null
        Move-Item -LiteralPath $wr -Destination $d
        Write-Host "  BINNED  B Website\research.qmd" -ForegroundColor Green
    }
    $script:acted++
} else { Write-Host "  SKIP  not found      : B Website\research.qmd" -ForegroundColor DarkYellow; $script:skipped++ }

# ---------------------------------------------- Summary
Write-Host "`n--------------------------------------------"
Write-Host ("  items: {0}   skipped: {1}   space: {2:N1} MB" -f $script:acted, $script:skipped, ($script:freed/1MB))
if (-not $Delete -and -not $DryRun) {
    Write-Host "  Everything is in _to_delete\ with its original path. Look through it," -ForegroundColor Yellow
    Write-Host "  then remove that folder, or rerun with -Delete." -ForegroundColor Yellow
}

Write-Host "`n  NOT handled here, on purpose:" -ForegroundColor White
Write-Host "  - SLE_Excise_Diagnostic.docx + SLE-ExciseDiagnostic.docx are two halves"
Write-Host "    of one document (body, then appendices). Append the second into the"
Write-Host "    first by hand, then bin the second. Deleting it first loses the appendices."
Write-Host "  - 3.4 SLIDIs holds ~77 MB of deck versions, all different sizes, so none"
Write-Host "    is a straight copy. Thin by hand if you want the space."
Write-Host "  - Archive\Older\bonds with kpi.zip is 16 MB beside a 428 KB docx of the"
Write-Host "    same name. Probably stale, not opened, so not touched."
Write-Host "  - B Website copies of paper sources other than research.qmd. Quarto"
Write-Host "    renders those; deleting them breaks the site.`n"

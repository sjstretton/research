# Renumber "A Writing" to the final structure.
#
#   Preview:  powershell -ExecutionPolicy Bypass -File .\renumber.ps1 -DryRun
#   Run:      powershell -ExecutionPolicy Bypass -File .\renumber.ps1
#
# Nothing is deleted. Folders left empty or superseded are moved into
# "_to_delete\" for you to remove later.
#
# Order matters and is deliberate: several targets are occupied until an
# earlier step vacates them. Do not reorder.

param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

$research = "C:\Users\sjstr\Documents\OneDrive\Documents\A Research"
$root     = Join-Path $research "A Writing"

$sec1 = "1. Climate and Fiscal Policy"
$sec2 = "2. Finance and Risk"
$sec3 = "3. Sovereign Incentives and MDBs"
$sec4 = "4. Modelling"
$sec5 = "5. Analytics"
$cpat = "$sec4\4.2 CPAT - Architecture, Recoding and Fiscal Application"

$script:done = 0; $script:skipped = 0

function MoveIt([string]$src, [string]$dst) {
    $s = Join-Path $root $src
    $d = Join-Path $root $dst
    if (-not (Test-Path -LiteralPath $s)) {
        Write-Host "  SKIP  source missing : $src" -ForegroundColor DarkYellow
        $script:skipped++; return
    }
    if (Test-Path -LiteralPath $d) {
        Write-Host "  SKIP  target exists  : $dst" -ForegroundColor Red
        $script:skipped++; return
    }
    $parent = Split-Path -Parent $d
    if (-not (Test-Path -LiteralPath $parent)) {
        if ($DryRun) { Write-Host "  mkdir $((Resolve-Path $root).Path -replace '.*\\','')\...\$(Split-Path -Leaf $parent)" -ForegroundColor DarkGray }
        else { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    }
    if ($DryRun) { Write-Host "  MOVE  $src`n     -> $dst" -ForegroundColor Cyan }
    else {
        Move-Item -LiteralPath $s -Destination $d
        Write-Host "  OK    $src -> $dst" -ForegroundColor Green
    }
    $script:done++
}

function MoveFiles([string]$srcDir, [string]$pattern, [string]$dstDir) {
    $s = Join-Path $root $srcDir
    $d = Join-Path $root $dstDir
    if (-not (Test-Path -LiteralPath $s)) {
        Write-Host "  SKIP  source missing : $srcDir" -ForegroundColor DarkYellow
        $script:skipped++; return
    }
    if (-not (Test-Path -LiteralPath $d)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
    $items = Get-ChildItem -LiteralPath $s -Filter $pattern -File
    if (-not $items) {
        Write-Host "  SKIP  no match $pattern in $srcDir" -ForegroundColor DarkYellow
        $script:skipped++; return
    }
    foreach ($i in $items) {
        $target = Join-Path $d $i.Name
        if (Test-Path -LiteralPath $target) {
            Write-Host "  SKIP  target exists  : $($i.Name)" -ForegroundColor Red
            $script:skipped++; continue
        }
        if ($DryRun) { Write-Host "  MOVE  $srcDir\$($i.Name)`n     -> $dstDir\" -ForegroundColor Cyan }
        else { Move-Item -LiteralPath $i.FullName -Destination $target; Write-Host "  OK    $($i.Name) -> $dstDir\" -ForegroundColor Green }
        $script:done++
    }
}

if ($DryRun) { Write-Host "`n=== DRY RUN - nothing will change ===`n" -ForegroundColor Yellow }
else { Write-Host "`n=== RENUMBERING ===`n" -ForegroundColor Yellow }

# ---------------------------------------------------------------- Section 1
Write-Host "1. Climate and Fiscal Policy" -ForegroundColor White

# Stray folder I created before the paper moved to Analytics 5.3.
MoveIt "$sec1\1.5 Instrument Diagnostic" "_to_delete\1.5 Instrument Diagnostic (superseded by 5.3)"

# Carbon Consumption Tax becomes the appendix to 1.1.
MoveIt "$sec1\1.2 Carbon Consumption Tax" "$sec1\1.1 Open Economy Carbon Pricing\Background\Carbon Consumption Tax"

MoveIt "$sec1\1.4 CBAM Issues"       "$sec1\1.3 Iron, Steel, CBAM"

# Three feebate folders become one paper, two of them as background.
MoveIt "$sec1\1.6 Power Sector OBR"  "$sec1\1.2 Feebates and Output-Based Rebating"
MoveIt "$sec1\1.7 Industrial Feebates" "$sec1\1.2 Feebates and Output-Based Rebating\Background\Industrial Feebates"
MoveIt "$sec1\1.5 Feebates Brief"      "$sec1\1.2 Feebates and Output-Based Rebating\Background\Feebates Brief"

MoveIt "$sec1\1.9 Rent Tax"          "$sec1\1.4 Rent Tax"

# India folder becomes the coal PPA paper; the existing India material is the
# source to extract it from, so it goes to Background rather than staying loose.
MoveIt "$sec1\1.8 India Climate Policy" "$sec1\1.5 Stranded by Contract - Reforming Legacy Coal PPAs"
MoveFiles "$sec1\1.5 Stranded by Contract - Reforming Legacy Coal PPAs" "*.*" "$sec1\1.5 Stranded by Contract - Reforming Legacy Coal PPAs\Background\India Note"

# ---------------------------------------------------------------- Section 2
Write-Host "`n2. Finance and Risk" -ForegroundColor White

# 2.1 and 2.2 swap, so a temporary name is required.
MoveIt "$sec2\2.2 RE Payments Intermediary Facility" "$sec2\__tmp RE Payments"
MoveIt "$sec2\2.1 Standardizing Green Project Finance" "$sec2\2.2 Standardized Two-Stage Climate Project Finance"
MoveIt "$sec2\__tmp RE Payments" "$sec2\2.1 Climate Finance Intermediation for Clean Power"

MoveIt "$sec2\2.4 The Sollar"           "$sec2\2.5 The Sollar"
MoveIt "$sec2\2.0 Trillions to Billions" "$sec2\2.4 Trillions to Billions"
# 2.3 Synthetic Sovereign Bonds keeps its number.

# ---------------------------------------------------------------- Section 3
Write-Host "`n3. Sovereign Incentives and MDBs" -ForegroundColor White

MoveIt "$sec3\3.6 MDB Climate Envelope"    "$sec3\3.5 MDB Climate Envelope"
MoveIt "$sec3\3.4 Reforming MDBs"          "$sec3\3.6 Reforming MDBs"
MoveIt "$sec3\3.2. SLIDIs"                 "$sec3\3.4 SLIDIs"
MoveIt "$sec3\3.1 SLL Operationalisation"  "$sec3\3.2 Sustainability-Linked Lending"
# 3.1 Notional Capitalised Value and 3.3 Climate Investment Trust are already correct.

# ---------------------------------------------------------------- Section 4
Write-Host "`n4. Modelling" -ForegroundColor White

# Five former papers collapse into 4.2 as background. Do these before the
# TECP rename, which needs the 4.1 slot.
MoveIt "$sec4\4.2 Power Investment Equations" "$cpat\Background\Power Investment Equations"
MoveIt "$sec4\4.1 CPAT Modelling of ETS"      "$cpat\Background\CPAT Modelling of ETS"
MoveIt "$sec4\4.5 WB Models"                  "$cpat\Background\WB Models"
MoveIt "$sec4\4.5 Fiscal Long-Term Strategy"  "$cpat\Background\Fiscal Long-Term Strategy"
MoveIt "$sec4\4.2 AI-Assisted CPAT Recoding"  "$cpat\Background\AI-Assisted CPAT Recoding (notes)"

MoveIt "$sec4\4.3 TECP and CES" "$sec4\4.1 Policy-Equivalent Carbon Price and CES"

# Toy Model crosses into Analytics, beside the Instrument Diagnostic.
MoveIt "$sec4\4.4 Toy Model of Global Mitigation Policies" "$sec5\5.2 Toy Model of Global Mitigation Policies"

# Prices module workbooks are the recoding record, not an analytics product.
MoveFiles "$sec5\CPAT Analysis" "CPAT_PricesModule_v*.xlsx" "$cpat"
MoveIt    "$sec5\CPAT Analysis" "_to_delete\CPAT Analysis (emptied)"

# ---------------------------------------------------------------- Section 5
Write-Host "`n5. Analytics" -ForegroundColor White

# Shift the two I created up one, CFF first so it clears the 5.5 slot.
MoveIt "$sec5\5.5 Climate-Fiscal-Financial Dashboard"   "$sec5\5.6 Climate-Fiscal-Financial Dashboard"
MoveIt "$sec5\5.3 Green Growth and Sectoral TFP Diagnostic" "$sec5\5.4 Green Growth and Sectoral TFP Diagnostic"
MoveIt "$sec5\CBAM Dashboard"    "$sec5\5.5 CBAM Dashboard and Emission Factors"
MoveIt "$sec5\Excise Diagnostic" "$sec5\5.1 Excise-Fiscal Diagnostic"
# 5.3 Instrument Diagnostic is already correct.

# Admin scaffold, not research - out of A Writing entirely.
$sc = Join-Path $root "$sec5\Setup Claude"
$scDst = Join-Path $research "Setup Claude"
if (Test-Path -LiteralPath $sc) {
    if (Test-Path -LiteralPath $scDst) { Write-Host "  SKIP  target exists  : A Research\Setup Claude" -ForegroundColor Red; $script:skipped++ }
    elseif ($DryRun) { Write-Host "  MOVE  $sec5\Setup Claude`n     -> A Research\Setup Claude" -ForegroundColor Cyan; $script:done++ }
    else { Move-Item -LiteralPath $sc -Destination $scDst; Write-Host "  OK    Setup Claude -> A Research\" -ForegroundColor Green; $script:done++ }
} else { Write-Host "  SKIP  source missing : $sec5\Setup Claude" -ForegroundColor DarkYellow; $script:skipped++ }

# ---------------------------------------------------------------- Summary
Write-Host "`n--------------------------------------------"
Write-Host ("  {0}: {1}   skipped: {2}" -f $(if($DryRun){"would move"}else{"moved"}), $script:done, $script:skipped)
if ($script:skipped -gt 0) {
    Write-Host "  Red skips mean a target was occupied - check those before rerunning." -ForegroundColor Yellow
}
Write-Host "  Nothing deleted. See _to_delete\ and _deletion-list.md.`n"

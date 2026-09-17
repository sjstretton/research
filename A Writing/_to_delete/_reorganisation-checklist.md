# A Writing — reorganisation checklist

Do the steps **in order** within each section. Order matters: several renames
collide if run out of sequence, and Windows fails those silently.

`research.qmd` is already written to the new numbering. The six new folders are
already created. Everything below is renames, moves and deletions.

---

## 1. Climate and Fiscal Policy

Target: 1.1 Open Economy Carbon Pricing · 1.2 Feebates and Output-Based Rebating ·
1.3 Iron Steel and CBAM · 1.4 Rent Tax · 1.5 India Climate Policy

The Instrument Diagnostic has moved out of this section to Analytics 5.3.

1. MOVE folder `1.2 Carbon Consumption Tax`
   → into `1.1 Open Economy Carbon Pricing\Appendix - Carbon Consumption Tax`
2. RENAME `1.4 CBAM Issues` → `1.3 Iron Steel and CBAM`
3. RENAME `1.6 Power Sector OBR` → `1.2 Feebates and Output-Based Rebating`
4. MOVE contents of `1.7 Industrial Feebates`
   → `1.2 Feebates and Output-Based Rebating\Industrial\`
   then DELETE the empty `1.7 Industrial Feebates`
5. MOVE contents of `1.5 Feebates Brief`
   → `1.2 Feebates and Output-Based Rebating\Outreach\`
   then DELETE the empty `1.5 Feebates Brief`
6. RENAME `1.9 Rent Tax` → `1.4 Rent Tax`
7. RENAME `1.8 India Climate Policy` → `1.5 India Climate Policy`
8. DELETE the folder `1.5 Instrument Diagnostic` — I created it here before you
   reclassified it; the replacement already exists at `5. Analytics\5.3 Instrument Diagnostic`.
   Do this **before** step 7, or the rename collides on the number.

---

## 2. Finance and Risk

Target: 2.1 Climate Finance Intermediation for Clean Power ·
2.2 Standardized Two-Stage Climate Project Finance · 2.3 Synthetic Sovereign Bonds ·
2.4 Trillions to Billions · 2.5 The Sollar

**2.1 and 2.2 swap places, so a temporary name is required.**

1. RENAME `2.2 RE Payments Intermediary Facility` → `_tmp RE Payments`
2. RENAME `2.1 Standardizing Green Project Finance`
   → `2.2 Standardized Two-Stage Climate Project Finance`
3. RENAME `_tmp RE Payments` → `2.1 Climate Finance Intermediation for Clean Power`
4. RENAME `2.4 The Sollar` → `2.5 The Sollar`
5. RENAME `2.0 Trillions to Billions` → `2.4 Trillions to Billions`
6. DELETE `2.1 Climate Finance Intermediation for Clean Power\Earlier version\WP1A-SyntheticSovereignBonds.docx`
   — text-identical (1.000) to `2.3\F2-SyntheticSovereignBonds.docx`

`2.3 Synthetic Sovereign Bonds` keeps its number.

---

## 3. Sovereign Incentives and MDBs

Target: 3.1 Notional Capitalised Value and Guarantees ✔ ·
3.2 Sustainability-Linked Lending · 3.3 Climate Investment Trust · 3.4 SLIDIs ·
3.5 MDB Climate Envelope · 3.6 Reforming MDBs

1. RENAME `3.6 MDB Climate Envelope` → `3.5 MDB Climate Envelope`
2. RENAME `3.4 Reforming MDBs` → `3.6 Reforming MDBs`
3. RENAME `3.2. SLIDIs` → `3.4 SLIDIs`  (note the stray period in the old name)
4. RENAME `3.1 SLL Operationalisation` → `3.2 Sustainability-Linked Lending`

Deletions in `3.3 Climate Investment Trust`:

5. DELETE `Archive\CIT.pptx` — byte-identical to `CIT Introduction.pptx`
   (7,664,307 bytes each). Frees 7.6 MB
6. DELETE `Archive\TechnicalSummary-TheClimateIncentivesTrust-Clean.docx`
   — 0.998 match to `TechnicalSummary_CIT.docx`, which has the proper title page
7. DELETE `Archive\FullPaper-TheClimateIncentivesTrust_Apr2024.docx`
   — 0.949 match to `WP4- CIT.docx`, which is longer and newer

**Keep** `Archive\The Climate Incentives Trust.docx` — only 0.636 against WP4,
so it is a genuinely different earlier draft, not a copy.

---

## 4. Modelling

Target: 4.1 Policy-Equivalent Carbon Price and CES · 4.2 AI-Assisted CPAT Recoding ✔ ·
4.3 CPAT Mitigation Architecture · 4.4 Power Investment Equations ·
4.5 Fiscal Long-Term Strategy ✔ · 4.6 WB Models

1. MOVE folder `4.4 Toy Model of Global Mitigation Policies`
   → `5. Analytics\5.2 Toy Model of Global Mitigation Policies`
   (it lands beside 5.3 Instrument Diagnostic — the optimal/feasible pair)
2. RENAME `4.5 WB Models` → `4.6 WB Models`
3. RENAME `4.2 Power Investment Equations` → `4.4 Power Investment Equations`
4. RENAME `4.1 CPAT Modelling of ETS` → `4.3 CPAT Mitigation Architecture`
5. RENAME `4.3 TECP and CES` → `4.1 Policy-Equivalent Carbon Price and CES`
6. DELETE `4.3 CPAT Mitigation Architecture\Power Investment Equations\`
   — orphan subfolder holding only a duplicate `references.bib`
7. MOVE the four `CPAT_PricesModule_v*.xlsx` from `5. Analytics\CPAT Analysis`
   → `4.2 AI-Assisted CPAT Recoding\`
   then DELETE the empty `5. Analytics\CPAT Analysis`

Steps 3, 4 and 5 must run in that order — each frees the number the next one needs.

---

## 5. Analytics

Target: 5.1 Excise-Fiscal Diagnostic · 5.2 Toy Model (arrives from §4) ·
5.3 Instrument Diagnostic ✔ · 5.4 Green Growth and Sectoral TFP Diagnostic ·
5.5 CBAM Dashboard and Emission Factors · 5.6 Climate-Fiscal-Financial Dashboard

5.2 and 5.3 are a deliberate pair: the Toy Model diagnoses what policy should be,
the Instrument Diagnostic asks what a country can carry. Keep them adjacent.

1. RENAME `Excise Diagnostic` → `5.1 Excise-Fiscal Diagnostic`
2. RENAME `CBAM Dashboard` → `5.5 CBAM Dashboard and Emission Factors`
3. RENAME `5.3 Green Growth and Sectoral TFP Diagnostic`
   → `5.4 Green Growth and Sectoral TFP Diagnostic`
4. RENAME `5.5 Climate-Fiscal-Financial Dashboard`
   → `5.6 Climate-Fiscal-Financial Dashboard`
   — do this **after** step 2, or it collides with the CBAM rename
5. MOVE `Setup Claude` out of `A Writing` — it is admin scaffold, not research
   (`9. Additional` or the `A Research` root)

Inside `5.1 Excise-Fiscal Diagnostic`:

6. DELETE `MAiSierra_Leone_Excise_Complete_Report.docx`
   — earlier AI pass with the prompts still pasted in; 0.017 similarity to the
   real Sierra Leone report, so nothing is lost
7. JOIN `SLE_Excise_Diagnostic.docx` + `SLE-ExciseDiagnostic.docx` into one file.
   These are **not** duplicates — the first is the report body (exec summary,
   fiscal setting, methodology, 144 paragraphs), the second is its appendices
   (worked computations, Appendix A full diagnostics, Appendix B year-by-year).
   They are two halves of one document.

`excise_diagnostic.docx` is the generic method paper with no country in it —
that is the 5.1 paper proper. Keep it separate from the Sierra Leone application.

---

## Outside A Writing

- DELETE `B Website\research.qmd` — master now lives in `A Writing`

---

## Known duplication left alone, to resolve later

`A Writing` and `B Website` hold byte-identical copies of several paper sources:
`TECP_Combined_Paper.qmd`, `OpenEconomyCarbonPricing.tex`, `rent_tax_paper.tex`,
Power Investment Equations `.tex` and `.qmd`. Quarto renders the `B Website`
copies, so deleting them breaks the site — this needs a single-source decision,
not a deletion.

Voting Patterns is the exception: the `B Website` copies are *larger* than the
`A Writing` ones (48,434 vs 48,022 and 50,556 vs 50,139 bytes), so the website
version is the newer edit. Reconcile that one before syncing anything.

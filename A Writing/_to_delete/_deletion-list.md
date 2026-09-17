# A Writing — deletion list

Verified against the folder as it stands now. Everything here is either a
confirmed duplicate, an empty artefact, or a folder left behind by a move.

**Deletions are permanent — there is no Trash on this path.** Do the moves that
empty a folder before deleting the folder.

All paths are relative to `A Research\A Writing\` unless stated.

---

## Confirmed duplicates — verified by content, safe to delete

| # | Path | Evidence |
|---|---|---|
| 1 | `2. Finance and Risk\2.1 Climate Finance Intermediation for Clean Power\Earlier version\WP1A-SyntheticSovereignBonds.docx` | Text identical (1.000) to `2.3 Synthetic Sovereign Bonds\F2-SyntheticSovereignBonds.docx` — same 48 paragraphs, same 12 headings. Path shown post-rename |
| 2 | `3. Sovereign Incentives and MDBs\3.3 Climate Investment Trust\Archive\CIT.pptx` | Byte-identical to `CIT Introduction.pptx` — 7,664,307 bytes each. Frees 7.6 MB |
| 3 | `3. Sovereign Incentives and MDBs\3.3 Climate Investment Trust\Archive\TechnicalSummary-TheClimateIncentivesTrust-Clean.docx` | 0.998 text match to `TechnicalSummary_CIT.docx`, which keeps the proper title page |
| 4 | `3. Sovereign Incentives and MDBs\3.3 Climate Investment Trust\Archive\FullPaper-TheClimateIncentivesTrust_Apr2024.docx` | 0.949 text match to `WP4- CIT.docx`, which is longer and newer — this is its April draft |
| 5 | `5. Analytics\5.1 Excise-Fiscal Diagnostic\MAiSierra_Leone_Excise_Complete_Report.docx` | Earlier AI pass with the prompts still pasted into the body. 0.017 similarity to the real Sierra Leone report, so it is not a version of anything you are keeping |

## Empty or orphaned — safe to delete

| # | Path | Why |
|---|---|---|
| 6 | `1. Climate and Fiscal Policy\1.2 Carbon Consumption Tax\Old\` | Empty folder |
| 7 | `1. Climate and Fiscal Policy\1.5 Instrument Diagnostic\` | I created this before you reclassified the paper. Its replacement already exists at `5. Analytics\5.3 Instrument Diagnostic`. **Delete before renaming India to 1.5** |
| 8 | `4. Modelling\4.1 CPAT Modelling of ETS\Power Investment Equations\` | Orphan subfolder containing only a duplicate `references.bib`. Delete the subfolder, not the parent |
| 9 | `3. Sovereign Incentives and MDBs\3.2. SLIDIs\Archive\Additional Work\NotesOnOutline.txt` | Zero bytes |
| 10 | `7. Books\Book2-CarbonPricingWrongTime-Extras\RightPolicyWrongTime.zip` | 22 bytes — an empty or truncated archive, not a backup of anything |

## Folders to delete *after* their contents move

| # | Path | Move contents to |
|---|---|---|
| 11 | `1. Climate and Fiscal Policy\1.5 Feebates Brief\` | `1.2 Feebates and Output-Based Rebating\Outreach\` |
| 12 | `1. Climate and Fiscal Policy\1.7 Industrial Feebates\` | `1.2 Feebates and Output-Based Rebating\Industrial\` |
| 13 | `5. Analytics\CPAT Analysis\` | the four `CPAT_PricesModule_v*.xlsx` go to `4. Modelling\4.2 CPAT - Architecture, Recoding and Fiscal Application\` |
| 14 | `1. Climate and Fiscal Policy\1.2 Carbon Consumption Tax\` | `1.1 Open Economy Carbon Pricing\Appendix - Carbon Consumption Tax\` |

In section 4 the old `4.1`, `4.2` and `4.5` folders are **not** deleted — they
move wholesale into `4.2 CPAT ...\Background Papers\` and keep their contents.

## Outside A Writing

| # | Path | Why |
|---|---|---|
| 15 | `A Research\B Website\research.qmd` | Master now lives in `A Writing`, per your decision |

---

## Not a deletion — a join

`5. Analytics\5.1 Excise-Fiscal Diagnostic\SLE_Excise_Diagnostic.docx` and
`SLE-ExciseDiagnostic.docx` are **not** duplicates. The first is the report body
— executive summary, fiscal setting, methodology, 144 paragraphs. The second is
its appendices — worked computations, Appendix A full diagnostics, Appendix B
year-by-year changes, 54 paragraphs. They are two halves of one document that
got split.

Append the second into the first, then delete the second. Deleting it before the
join loses the appendices.

`excise_diagnostic.docx` in the same folder is the generic method paper with no
country in it — that is the 5.1 paper proper. Keep it separate.

---

## Deliberately kept

- `3.3 Climate Investment Trust\Archive\The Climate Incentives Trust.docx` —
  scores only 0.636 against `WP4- CIT.docx`, so it is a genuinely different
  earlier draft, not a copy.
- All `B Website` copies of paper sources other than `research.qmd`
  (`TECP_Combined_Paper.qmd`, `OpenEconomyCarbonPricing.tex`,
  `rent_tax_paper.tex`, the Power Investment Equations `.tex` and `.qmd`).
  Quarto renders those, so deleting them breaks the site. This needs a
  single-source decision, not a deletion.

---

## Worth a look, not yet verified

`3.2. SLIDIs` holds roughly 77 MB of presentation versions at different sizes —
`SLIDIs_PDM.pptx`, `SLIDIs-AsPresented`, `SLIDIs-Summary`, `SLIDIs-origi`,
`SLIDIs-NZ`, `-NZ2`, `-NZ3`, two `KPI Bonds.pptx` and a shorter version. All
differ in byte size, so none is a straight copy and I have not recommended
deleting any. Given the paper is below the cut, thinning this to the presented
version plus one archive copy would reclaim most of that space.

`Archive\Older\bonds with kpi.zip` is 16 MB beside a 428 KB
`bonds with kpi.docx`. Likely a stale archive of material already unpacked in
the same tree, but I have not opened it.

`SLIDI Sept 2024 final.docx` and `Archive\SLIDI_Long.docx` are both exactly
242,628 bytes — almost certainly the same file under two names. I was midway
through confirming this when we changed direction; check before deleting.

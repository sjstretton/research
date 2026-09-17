# Paper folder layout

The standard shape for every folder under `A Writing\<theme>\<paper>`.

```
<PaperName>.<ext>          the core paper, alone at root
<PaperName>.bib            its bibliography, beside it
1.Presentation             briefing papers (BP), slides, abstracts, summaries
2.Source                   other formats, data, spreadsheets, images, code
3.BackgroundPapers         other papers of mine in the same folder
4.ExternalPapers           other people's work
5.Notes                    notes, comments, outlines
9.Archive                  superseded drafts and old data versions
```

Slots 6, 7 and 8 are **reserved, not missing**. Leave the gap.

A slot exists only if something is in it. Most folders have two or three.

## Naming

**No spaces anywhere.** Folders are `<number>.<CamelCase>`:

```
1. Climate and Fiscal Policy      ->  1.ClimateAndFiscalPolicy
1.1 Open Economy Carbon Pricing   ->  1.1.OpenEconomyCarbonPricing
1.3 Iron, Steel, CBAM             ->  1.3.IronSteelCBAM
3. Background Papers              ->  3.BackgroundPapers
Voting Patterns                   ->  VotingPatterns
```

A dot joins the number to the name, and the number keeps its own dots — so a
paper folder reads `1.1.OpenEconomyCarbonPricing`. Acronyms keep their case —
CBAM, MDB, SLIDIs, PPAs, TFP.

`<PaperName>` for the core file is the paper folder's name in CamelCase with
the number dropped: `1.4.RentTax` holds `RentTax.qmd`.

`Rename-Folders.ps1` applies this, and converts anything already renamed with
an underscore. The separator is `$Separator` at the top of that script — set it
to `_` or `-` if you change your mind again. Slot folders are matched ignoring
spaces and punctuation, so `1. Presentation`, `1_Presentation` and
`1.Presentation` are all recognised as the same slot and never duplicated.

Everything the core paper needs by relative path stays where it can find it.
The `.bib` sits at root next to the core; a `.tex` in `2.Source` reaches it
as `../<PaperName>.bib`. No folder name is written inside a source file except
for images, which is the one place the layout costs something — see below.

## Which file is the core paper

- `WP` prefix means a working paper. That is the core.
- No prefix at all is also a candidate.
- `BP` prefix means a briefing paper. **Never the core.** It goes to
  `1.Presentation`, in every format it exists in — Word, PDF, Canva export.
- Ties break: WP beats unprefixed; then `.qmd`, `.docx`, `.tex`; then highest
  version number, then newest, then largest.

When the choice is a guess, the CSV says so and the runners-up go to
`3.BackgroundPapers`. When the candidates look like *different papers*
rather than versions of one, nothing is moved and the folder is flagged for
splitting.

## Where things live

```
A Writing\
    research.qmd             the portfolio index
    0.Website\               the Quarto site - never touched by the scripts
    1.ClimateAndFiscalPolicy\
    2.FinanceAndRisk\
    3.SovereignIncentivesAndMDBs\
    4.Modelling\
    5A.Analytics-ExciseDiagnostic\      5B.Analytics-PolicyChoice\
    5C.Analytics-Dashboards\            5D.Analytics-GreenGrowth\
    5E.AnalyticsMacroFiscal\
    6.Books\   7.Philosophy\   8.Politics\   10.Overview\
    9.Scripts\               the live tool set
        Preview-Rename.bat     Run-Rename.bat     Rename-Folders.ps1
        Preview-Reorganize.bat Run-Reorganize.bat Reorganize-Papers.ps1
        Preview-Convert.bat    Run-Convert.bat    Convert-Documents.ps1
        Preview-RenameFiles.bat Run-RenameFiles.bat Rename-Files.ps1
        Tidy-Scripts.bat       Tidy-Scripts.ps1
        _CoreFiles.txt  _PaperFolderLayout.md  _PaperIndex.csv
        _Reports\             conversion and reorganise reports
        MaintenanceAndReference\   earlier versions, kept
        XArchiveDeleteable\        spent scripts and old reports
```

Themes are **discovered, not listed**: any folder at the root whose name starts
with a number — a trailing letter is allowed, so `5A.` works — is a theme,
unless it normalises to Overview, Books, Scripts, Website or Additional. So
renumbering or splitting a theme needs no edit anywhere.

`A Writing` itself is found by looking for numbered folders, and the scripts
treat whatever folder they sit in as the housekeeping folder — so `9.Scripts`
can be renamed or renumbered freely.

## File naming

```
<PaperName>.qmd  .docx  .bib     the master, at the paper root, no prefix
1.Presentation\    Pres-<Name>     slide decks
                   Briefing-<Name> briefing papers, abstracts, summaries
3.BackgroundPapers\ Background-<Name>
5.Notes\           Notes-<Name>
2.Source\          <PaperName>.<ext>   derivatives share the master's stem
```

`<Name>` is CamelCase with spaces and punctuation stripped. A leading working
reference — `BP-`, `WP7-`, `B3a-`, `A3-`, `F2-` — is dropped, and a word that
only repeats the prefix is dropped too, so `SPIFA Brief.pdf` becomes
`Briefing-SPIFA.pdf` rather than `Briefing-SPIFABrief.pdf`.

A master and every derivative sharing its stem are renamed together, so a `.qmd`
never loses its `.docx`. `4.ExternalPapers` and `9.Archive` are left alone —
other people's names carry meaning, and the bin does not need tidying.

`Rename-Files.ps1` also does the housekeeping that follows: a `.bib` at the
paper root is renamed to match the master and the `bibliography:` line is
rewritten to follow it; loose `.txt` and `.md` at a paper root move into
`5.Notes`; and pandoc's doubled `media\` folders are flattened with the
image paths in the `.qmd` corrected.

## Formats

Every document is held as **both a `.qmd` and a `.docx`** with the same stem,
side by side, carrying the same content with no formatting. LaTeX is kept only
where it already exists, in `2.Source`, and is never generated.

`Convert-Documents.ps1` maintains that pairing:

- a `.docx` or `.md` with no sibling `.qmd` gets one;
- a `.qmd` with no sibling `.docx` gets one;
- a `.tex` is converted only if its paper folder has no `.qmd` at all, so a
  LaTeX source never duplicates a paper that already exists in Quarto form.

Word styling, fonts, colours, text boxes and raw HTML are dropped. Headings,
paragraphs, lists, tables, emphasis, footnotes and links survive. Images are
extracted into a `media\` folder beside the `.qmd`; pass `-NoMedia` to drop
them instead.

Not converted: `9.Archive`, `4.ExternalPapers`, `2.Source`, `0.Website`, the
scripts folder, anything starting with `_` or `.`, README files, and files
loose at the root of `A Writing`.

## Running it

The `.bat` files live in `9.Scripts`. Double-click, previews first:

- **`Preview-Rename.bat`** / **`Run-Rename.bat`** — puts every folder name into
  the convention above and rewrites any path references that point at them.
  After it has run once it reports nothing to do.
- **`Preview-Reorganize.bat`** — changes nothing. Writes
  `_Scripts\_ReorganizeReport-preview.txt` and refreshes `_PaperIndex.csv`.
- **`Run-Reorganize.bat`** — does it.
- **`Preview-Convert.bat`** / **`Run-Convert.bat`** — gives every document its
  missing `.qmd` or `.docx`. Writes `_Reports\_ConvertIndex.csv`.
- **`Preview-RenameFiles.bat`** / **`Run-RenameFiles.bat`** — puts filenames
  into the convention below and rewrites what points at them.
- **`Tidy-Scripts.bat`** — sweeps the scripts folder. Lists what it would move,
  asks, then moves anything that is not part of the live tool set into
  `_Archive\<date>\`, keeping the four newest reports. Nothing is deleted.

Nothing is ever deleted or overwritten, and no format is converted. Running it
twice is a no-op, so it is safe to re-run after adding files to a folder.

## `_PaperIndex.csv`

One row per paper folder, in `9.Scripts`, regenerated on every run.

| Column | Meaning |
|---|---|
| `Status` | Structured / CHECK / NO PAPER FOUND / SPLIT THE FOLDER |
| `CoreFile` | the current filename of the core paper |
| `OriginalFile` | what it was called before the rename |
| `OriginalPrefix` | WP, BP, OTHER or NONE |
| `Confidence` | confident, guessed, override, separate-papers, briefings-only |
| `OtherFormats` | the same paper's other formats sitting in `2.Source` |
| `Slots` | which numbered slots exist, as digits |
| `Files` | file count in the folder tree |
| `Notes` | why it was flagged |

`OriginalFile` and `Confidence` are carried forward between runs, so renaming
a core does not erase the record of what it used to be or how it was chosen.

## Pinning a core file

When the script guesses wrong, or finds nothing, add a line to
`_CoreFiles.txt` beside the scripts:

```
1.ClimateAndFiscalPolicy\1.2.FeebatesAndOutputBasedRebating | WP6- PowerSectorFeebates.docx
```

Folder path relative to `A Writing`, a pipe, the exact filename. Re-run.
An override beats every rule, including the BP exclusion.

## Images

`2.Source` holds images, so a `.qmd` at root refers to them as
`2.Source/images/...`. With spaces gone this is an ordinary relative path —
no percent-encoding, and LaTeX's `\includegraphics` handles it too. Files whose
paths were rewritten are listed under **CHECK THESE RENDERS** in the report;
re-render those once.

To keep images at the paper root instead, set `$MoveImagesIntoSource = $false`
near the top of `Reorganize-Papers.ps1`.

## Data versions

Spreadsheets and data files are grouped into families by name, ignoring
version numbers and words like FINAL, clean, copy, peer-review. The highest
version stays in `2.Source`; the rest move to `9.Archive`. So
`CPAT_PricesModule` v1.10, v1.11_FINAL and v1.11_peer-review-2030 are archived
and v1.12 stays.

## Tidying up the scripts themselves

The first thing a reorganise run does is sweep the root of `A Writing` into
the scripts folder:

- the scripts, `_CoreFiles.txt`, this file, and any stray `_ReorganizeLog.txt`
  or `cleanup.ps1` / `renumber.ps1` left over from earlier attempts;
- holding folders — `_to_delete`, `_Scripts`, `_superseded`;
- anything already there is not overwritten. A duplicate found at the
  root is parked in `_Scripts\_superseded\` instead, so neither copy is lost.

`_PaperIndex.csv`, `research.qmd` and the numbered theme folders are left where
they are. Anything else unrecognised at the root is listed in the report as
`LEFT` rather than moved — the sweep only touches names it knows.

Inside a paper folder, stray copies of `Reorganize-*.ps1`, `Reorganize-*.bat`,
`_ReorganizeLog.txt` or `_PaperIndex.csv` go to that folder's `9.Archive`. So
old runs clean up after themselves wherever they landed.

A copy of the script sitting in `_superseded` or `_Scripts` refuses to run and
says so, rather than treating its own folder as `A Writing`.

`Tidy-Scripts.bat` is the manual sweep of the scripts folder itself: anything
that is not one of the eight live files, plus reports older than the newest
four, goes into `_Archive\<date>\`. Run it after a rename or reorganise.

To reset entirely: delete `_Scripts\`, `_Archive\` and `_PaperIndex.csv`, then
re-run. Nothing in the paper folders depends on any of them.

## Known exceptions

- **`2.1.ClimateFinanceIntermediationForCleanPower`** — its core,
  `ClimateFinanceIntermediationForCleanPower.qmd`, is titled "SPIFA Brief". It
  was promoted before the BP rule existed. There is no working paper in that
  folder; the only WPs are archived earlier drafts. Either accept a briefing
  paper as the core here, or write the WP.
- **`2.2`** — the core was guessed between two WP3 drafts. Check it.
- **`2.4.TrillionsToBillions`** and **`6.PhilosophyAndPolitics\Philosophy`** — several distinct
  papers sharing one folder. Nothing was moved at root. They want splitting into
  a folder each.

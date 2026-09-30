# Research

Personal research workspace covering climate-fiscal economics, sovereign risk,
and related modelling/analytics — including the underlying papers, a Quarto
website, scripting engine, and a shared Claude workspace.

## Repository layout

| Folder | Contents |
|---|---|
| `A Geoprosperity Overview` | High-level pitch materials and overview for the "Geoprosperity" paper series. |
| `B Research and Website` | Main body of research and the public-facing website, organized as: |
| &nbsp;&nbsp;`1.ClimateAndFiscalPolicy` | Carbon pricing, feebates/output-based rebating, CBAM, and related policy papers. |
| &nbsp;&nbsp;`2.FinanceAndRisk` | Climate finance intermediation, climate investment trust, and risk work. |
| &nbsp;&nbsp;`3.SovereignIncentives` | Sovereign incentives, notional capitalised value and guarantees. |
| &nbsp;&nbsp;`4.Modelling` | CPAT architecture recoding, fiscal application, and background modelling papers. |
| &nbsp;&nbsp;`5.Analytics` | Climate-fiscal-financial, green growth/TFP, and carbon pricing political economy diagnostics. |
| &nbsp;&nbsp;`6.Additional` | Supplementary analytics and reference books/archive. |
| &nbsp;&nbsp;`7.Website` | Quarto site source (`*.qmd`, `_quarto.yml`) that publishes the research. |
| &nbsp;&nbsp;`8.Scripts` | Automation engine (`Engine`, `Reference`, `Run`, `Steps`) used to generate reports. |
| &nbsp;&nbsp;`9.ResearchTracking` | CV, paper tracker, and research overview documents. |
| `C Research Proposal` | Oxford DPhil research proposal on sovereign incentives and derisking. |
| `D Climate Econ Course` | Materials for a climate-fiscal economics course, organized by topic (A–G). |
| `E Templates and Info` | Shared templates (briefings, one-pagers) used across the research. |
| `F Claude + Scripts` | Shared workspace and scripts for working with Claude (see its own README). |

Most subfolders that need extra explanation have their own `README.md` — check
there first for folder-specific conventions.

## Getting started

- Browse a topic folder under `B Research and Website` for the relevant papers.
- The website source lives in `B Research and Website/7.Website`; see its
  `render.bat`/`preview.bat`/`deploy.bat` scripts for building and publishing.
- The `8.Scripts` folder contains the engine used to run/generate reports —
  see `8.Scripts/Run/README.md` and `8.Scripts/Steps/README.md` for usage.
- `F Claude + Scripts/Setup Claude` documents the shared Claude workspace
  conventions (projects, inputs/working/outputs, archive).

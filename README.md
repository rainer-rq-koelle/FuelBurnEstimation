# FuelBurnEstimation

This repository is the 2026 workshop for the development, validation, and documentation of a flight-phase fuel-burn estimation workflow for multi-regional benchmarking.

The immediate goal is a simple Quarto paper that can render to MS Word and PDF, plus a technical note that documents the data preparation pipeline step by step.

## Current Setup

- `paper.qmd` is the lightweight paper draft.
- `technical-note-data-preparation.qmd` is the process note for source data, cleaning, milestone generation, and analysis datasets.
- `R/` contains reusable helper functions, initially lifted from the 2025 ICNS CHN-EUR fuel-burn work.
- `scripts/` contains reproducible data-preparation scripts.
- `R/canonical-fuel-milestones.R` and `scripts/prepare-chn-qar-canonical.R` are ported from the 2025/2026 CHN-EUR workflow that helped Lingling process one-file-per-flight QAR data locally.
- The CHN QAR reader now writes `CHN-fuel-flow-unit-qc.csv` to compare kg/h and lb/h fuel-flow assumptions before producing kilogram-based canonical outputs.
- `data-raw/` and `data-derived/` are intentionally ignored by Git except for placeholders.
- `notes/canonical-milestone-model.md` captures the enriched milestone convention for along-track distance anchors, pressure-altitude flight-level crossings, level segments, intervals, and lookup-table inputs.
- `notes/reference-data-inventory.csv` can be regenerated from the 2025 project with `Rscript scripts/00-inventory-reference-data.R`.
- `notes/handover-2026-10-05.md` captures the first conceptual milestone: source-specific preparation, harmonised milestone outputs, and level-segment characterisation as a paper-level analytical decision.

## EUR Milestone Harmonization

EUR PRU data uses legacy milestone labels that need harmonization to the 2026 enriched convention:

- `scripts/03-audit-eur-canonical-milestones.R` audits the local EUR canonical milestone parquet against the enriched milestone convention.
- `R/eur-milestone-harmonization.R` provides functions for renaming, mapping, and deriving canonical milestone labels.
- `scripts/04-harmonize-eur-milestones.R` applies the full harmonization pipeline:
  1. Renames distance labels: `F40`→`D040`, `L40`→`A040`, `F100`→`D100`, `L100`→`A100`
  2. Maps `FL100` to direction-aware `D_FL100`/`A_FL100` based on phase context
  3. Derives new FL crossing milestones: `D_FL075`, `D_FL180`, `A_FL075`, `A_FL180`
  4. Reconstructs `LVL` events into paired `LVL_START`/`LVL_END` milestones

Output: `data-derived/canonical-milestones-eur-2026-harmonized.parquet`

## Reference Project

The previous work is expected at:

`../paper-2025-ICNS-CHN-EUR-fuelburn`

Set `FUELBURN_2025_PROJECT` if the reference project lives elsewhere.
For machine-specific settings, copy `.Renviron.example` to `.Renviron` and edit the local paths there. `.Renviron` is ignored by Git so macOS, Windows, and other local environments can point at different source-data locations without changing tracked scripts.

## First Commands

```sh
quarto render paper.qmd --to html
quarto render technical-note-data-preparation.qmd --to html
Rscript scripts/00-inventory-reference-data.R
Rscript scripts/test-eur-canonical-import.R
Rscript scripts/03-audit-eur-canonical-milestones.R
Rscript scripts/04-harmonize-eur-milestones.R
Rscript scripts/90-check-data-store.R
```

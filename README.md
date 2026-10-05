# FuelBurnEstimation

This repository is the 2026 workshop for the development, validation, and documentation of a flight-phase fuel-burn estimation workflow for multi-regional benchmarking.

The immediate goal is a simple Quarto paper that can render to MS Word and PDF, plus a technical note that documents the data preparation pipeline step by step.

## Current Setup

- `paper.qmd` is the lightweight paper draft.
- `technical-note-data-preparation.qmd` is the process note for source data, cleaning, milestone generation, and analysis datasets.
- `R/` contains reusable helper functions, initially lifted from the 2025 ICNS CHN-EUR fuel-burn work.
- `scripts/` contains reproducible data-preparation scripts.
- `R/canonical-fuel-milestones.R` and `scripts/prepare-chn-qar-canonical.R` are ported from the 2025/2026 CHN-EUR workflow that helped Lingling process one-file-per-flight QAR data locally.
- `data-raw/` and `data-derived/` are intentionally ignored by Git except for placeholders.
- `notes/reference-data-inventory.csv` can be regenerated from the 2025 project with `Rscript scripts/00-inventory-reference-data.R`.
- `notes/handover-2026-10-05.md` captures the first conceptual milestone: source-specific preparation, harmonised milestone outputs, and level-segment characterisation as a paper-level analytical decision.

## Reference Project

The previous work is expected at:

`../paper-2025-ICNS-CHN-EUR-fuelburn`

Set `FUELBURN_2025_PROJECT` if the reference project lives elsewhere.

## First Commands

```sh
quarto render paper.qmd --to html
quarto render technical-note-data-preparation.qmd --to html
Rscript scripts/00-inventory-reference-data.R
```

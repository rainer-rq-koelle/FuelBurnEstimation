# FuelBurnEstimation

This repository is the 2026 workshop for the development, validation, and
documentation of a flight-phase fuel-burn estimation workflow for multi-regional
benchmarking.

The immediate goal is a simple Quarto paper that can render to MS Word and PDF,
plus a technical note that documents the data preparation pipeline step by step.

## Current Setup

- `paper.qmd` is the lightweight paper draft.
- `technical-note-data-preparation.qmd` is the process note for source data,
  cleaning, milestone generation, and analysis datasets.
- `R/` contains reusable helper functions.
- `scripts/` contains reproducible data-preparation scripts.
- `data-raw/` and `data-derived/` are intentionally ignored by Git except for
  placeholders.
- `notes/canonical-milestone-model.md` captures the enriched milestone
  convention for along-track distance anchors, pressure-altitude flight-level
  crossings, level segments, intervals, and lookup-table inputs.

## Data Sharing via Cloudflare R2

R2 is the source of truth for shared data artifacts. Each machine maintains a
local cache synced from R2; OneDrive is no longer part of the workflow.

```text
r2://paper-fuel-burn-estimation/
├── raw/eur/         EUR canonical milestones (source data)
├── raw/chn/         CHN canonical milestones (source data)
├── derived/eur/     EUR harmonized milestones (2026 convention)
├── derived/chn/     CHN harmonized milestones (2026 convention)
├── manifest/        Authoritative manifest, inventory, and validation reports
└── handover/        Cross-machine sync status summaries
```

### Setup

Install the R dependency:

```r
install.packages("paws.storage")
```

Copy `.Renviron.example` to `.Renviron` and configure:

```r
FUELBURN_DATA_STORE=/path/to/local/data-store
R2_ACCESS_KEY_ID=<your-key>
R2_SECRET_ACCESS_KEY=<your-secret>
R2_ENDPOINT=https://<account>.r2.cloudflarestorage.com
R2_BUCKET=paper-fuel-burn-estimation
```

Never commit `.Renviron` or real R2 credentials.

### Contributor Workflow

```sh
Rscript scripts/r2-list-files.R
Rscript scripts/r2-sync-status.R
Rscript scripts/r2-download-data-store.R
Rscript scripts/00-check-data-store.R
```

`r2-sync-status.R` compares the local cache with
`manifest/current-artifacts.csv`. `r2-download-data-store.R` verifies downloaded
files against manifest SHA-256 hashes when the manifest is present.

### Maintainer Workflow

After processing or updating artifacts locally:

```sh
Rscript scripts/00-check-data-store.R
Rscript scripts/r2-upload-data-store.R
Rscript scripts/r2-publish-manifest.R --dry-run
Rscript scripts/r2-publish-manifest.R
Rscript scripts/r2-sync-status.R
```

`scripts/r2-upload-data-store.R` uploads registered artifacts and publishes the
authoritative manifest. `scripts/r2-publish-manifest.R` can refresh only the
manifest when needed.

### Authoritative Manifest

`manifest/current-artifacts.csv` is the lightweight source of truth for data
artifacts. A data artifact is authoritative only when it is listed there with
`status == "current"` and its local SHA-256 hash matches.

The manifest records:

- object key
- source and stage (`raw`, `derived`)
- required flag
- version label
- SHA-256 hash and byte size
- producing script
- input artifact keys
- manifest timestamp and machine/user metadata

## Local Data Store

Each machine maintains a local cache:

```text
FUELBURN_DATA_STORE/
├── raw/eur/
├── raw/chn/
├── derived/eur/
├── derived/chn/
├── manifest/
└── handover/
```

`scripts/00-check-data-store.R` validates folder structure, required file
presence, parquet row/column counts, and writes local manifest/handover outputs.

## EUR Milestone Harmonization

EUR PRU data uses legacy milestone labels that need harmonization to the 2026
enriched convention:

- `scripts/03-audit-eur-canonical-milestones.R` audits the local EUR canonical
  milestone parquet against the enriched milestone convention.
- `R/eur-milestone-harmonization.R` provides functions for renaming, mapping,
  and deriving canonical milestone labels.
- `scripts/04-harmonize-eur-milestones.R` applies the harmonization pipeline.

Output is written to the local `derived/eur/` cache and can then be uploaded to
R2 by a maintainer.

## Reference Project

The previous work is expected at:

`../paper-2025-ICNS-CHN-EUR-fuelburn`

Set `FUELBURN_2025_PROJECT` if the reference project lives elsewhere.

## First Commands

```sh
Rscript scripts/r2-list-files.R
Rscript scripts/r2-sync-status.R
Rscript scripts/r2-download-data-store.R
Rscript scripts/00-check-data-store.R

quarto render paper.qmd --to html
quarto render technical-note-data-preparation.qmd --to html

Rscript scripts/00-inventory-reference-data.R
Rscript scripts/test-eur-canonical-import.R
Rscript scripts/03-audit-eur-canonical-milestones.R
Rscript scripts/04-harmonize-eur-milestones.R
```

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

## Cross-Machine Data Sharing (Cloudflare R2)

Data artifacts are shared via **Cloudflare R2** (S3-compatible storage) to overcome corporate OneDrive sync restrictions.

### R2 Bucket Structure
```
r2://paper-fuel-burn-estimation/
├── raw/eur/         EUR canonical milestones (source data)
├── raw/chn/         CHN canonical milestones (source data)
├── derived/eur/     EUR harmonized milestones (2026 convention)
├── derived/chn/     CHN harmonized milestones (2026 convention)
├── manifest/        Data inventory and validation reports
└── handover/        Cross-machine sync status summaries
```

### Setup (One-Time per Machine)

1. **Copy `.Renviron.example` to `.Renviron`**
2. **Set local data store path**:
   ```r
   FUELBURN_DATA_STORE=/path/to/local/data/store
   ```
3. **Add R2 credentials** (get from https://dash.cloudflare.com → R2 → API Tokens):
   ```r
   R2_ACCESS_KEY_ID=<your-key>
   R2_SECRET_ACCESS_KEY=<your-secret>
   R2_ENDPOINT=https://<account>.r2.cloudflarestorage.com
   R2_BUCKET=paper-fuel-burn-estimation
   ```

### Workflow

**On source machine (Windows):**
```sh
# Upload data to R2
Rscript scripts/r2-upload-data-store.R

# Verify upload
Rscript scripts/r2-list-files.R
```

**On destination machine (Mac):**
```sh
# Download data from R2
Rscript scripts/r2-download-data-store.R

# Verify local data
Rscript scripts/00-check-data-store.R
```

### R2 Helper Functions

**R package** (`R/r2-storage.R`):
- `r2_upload()` - Upload file to R2
- `r2_download()` - Download file from R2
- `r2_list()` - List bucket contents
- `r2_exists()` - Check if file exists
- `r2_delete()` - Delete file from R2

**Scripts**:
- `scripts/r2-upload-data-store.R` - Upload local data store to R2
- `scripts/r2-download-data-store.R` - Download R2 data to local machine
- `scripts/r2-list-files.R` - List all files in R2 bucket

## Local Data Store

Each machine maintains a local data store (OneDrive sync or local directory):

```
FUELBURN_DATA_STORE/
├── raw/eur/         EUR canonical milestones (source data)
├── raw/chn/         CHN canonical milestones (source data)
├── derived/eur/     EUR harmonized milestones (2026 convention)
├── derived/chn/     CHN harmonized milestones (2026 convention)
├── manifest/        Data inventory and validation reports
└── handover/        Cross-machine sync status summaries
```

**Checker script** (`scripts/00-check-data-store.R`):
- Validates folder structure and file presence
- Checks parquet file integrity (row/column counts)
- Creates manifest CSV with file metadata
- Generates handover summary for collaboration

## EUR Milestone Harmonization

EUR PRU data uses legacy milestone labels that need harmonization to the 2026 enriched convention:

- `scripts/03-audit-eur-canonical-milestones.R` audits the local EUR canonical milestone parquet against the enriched milestone convention.
- `R/eur-milestone-harmonization.R` provides functions for renaming, mapping, and deriving canonical milestone labels.
- `scripts/04-harmonize-eur-milestones.R` applies the full harmonization pipeline:
  1. Renames distance labels: `F40`→`D040`, `L40`→`A040`, `F100`→`D100`, `L100`→`A100`
  2. Maps `FL100` to direction-aware `D_FL100`/`A_FL100` based on phase context
  3. Derives new FL crossing milestones: `D_FL075`, `D_FL180`, `A_FL075`, `A_FL180`
  4. Reconstructs `LVL` events into paired `LVL_START`/`LVL_END` milestones

Output: `data-derived/canonical-milestones-eur-2026-harmonized.parquet` or local data store `derived/eur/`

## Reference Project

The previous work is expected at:

`../paper-2025-ICNS-CHN-EUR-fuelburn`

Set `FUELBURN_2025_PROJECT` if the reference project lives elsewhere.
For machine-specific settings, copy `.Renviron.example` to `.Renviron` and edit the local paths there. `.Renviron` is ignored by Git so macOS, Windows, and other local environments can point at different source-data locations without changing tracked scripts.

## First Commands

```sh
# Download data from R2 (first time on new machine)
Rscript scripts/r2-download-data-store.R

# Validate local data store
Rscript scripts/00-check-data-store.R

# List R2 bucket contents
Rscript scripts/r2-list-files.R

# Render documentation
quarto render paper.qmd --to html
quarto render technical-note-data-preparation.qmd --to html

# Data validation and processing
Rscript scripts/00-inventory-reference-data.R
Rscript scripts/test-eur-canonical-import.R
Rscript scripts/03-audit-eur-canonical-milestones.R
Rscript scripts/04-harmonize-eur-milestones.R

# Upload data to R2 (after processing)
Rscript scripts/r2-upload-data-store.R
```

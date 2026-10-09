# FuelBurnEstimation

This repository is the 2026 workshop for the development, validation, and
documentation of a flight-phase fuel-burn estimation workflow for multi-regional
benchmarking.

The immediate goal is a simple Quarto paper that can render to MS Word and PDF,
plus a technical note that documents the data preparation pipeline step by step.

## Current Setup

- `paper.qmd` is the lightweight paper draft.
- `paper-exploratory-2026.qmd` develops the AICAP 2027 argument, delivered-release
  diagnostics, profile-aware lookup design, and validation gates.
- `technical-note-data-preparation.qmd` is the process note for source data,
  cleaning, milestone generation, and analysis datasets.
- `technical-note-methodology.qmd` records analytical definitions, parameter
  trials, percentile interpretation, validation, and the cruise side study.
- `notes/study-worker-plan.md` defines work packages, dependencies, acceptance
  criteria, and the proposed schedule to 30 October 2026.
- `notes/worker-dispatch.md` provides the initial W0 dispatch pinned to an exact
  instruction commit; `notes/worker-handoff-template.md` defines the return package.
- `R/` contains reusable helper functions.
- `scripts/` contains reproducible data-preparation scripts.
- `data-raw/` and `data-derived/` are intentionally ignored by Git except for
  placeholders.
- `notes/canonical-milestone-model.md` captures the enriched milestone
  convention for along-track distance anchors, pressure-altitude flight-level
  crossings, level segments, intervals, and lookup-table inputs.

## EUR Data Pipeline Status

**Analytical readiness update (9 October 2026):** the FIXED release is available
and all seven local manifest-listed files match their hashes, but the study
readiness audit identifies unresolved EUR repeated/overlapping intervals, CHN
distance/time inconsistencies and missing landing milestones, and differences
between intended and actual phase/schema semantics. Availability and zero orphan
rate do not establish analytical validity. The pipeline completion statements
below describe the earlier delivery checks; the new validation gates take
precedence for scientific use.

```sh
Rscript scripts/12-audit-study-readiness.R
quarto render paper-exploratory-2026.qmd --to html
quarto render technical-note-methodology.qmd --to html
```

The audit writes aggregate diagnostics to `outputs/study-design/` without
modifying production data. Review the exploratory paper and worker plan before
estimating or publishing fuel-reference coefficients.

**Current:** FIXED pipeline (October 2026)
- ✅ LOBT bug corrected (two-stage SAM_ID extraction)
- ✅ 0% orphan rate (down from 54.4%)
- ✅ 100% complete segments (86,142 total)
- ✅ EUR-CHN schema harmonized (21/31 columns)
- ✅ Production data in R2 (`processed/eur/`)

See `notes/EUR-Pipeline-FIXED-Documentation.md` for complete pipeline documentation.

## Data Sharing via Cloudflare R2

R2 is the source of truth for shared data artifacts. Each machine maintains a
local cache synced from R2; OneDrive is no longer part of the workflow.

```text
r2://paper-fuel-burn-estimation/
├── processed/eur/     EUR production data (FIXED pipeline, 0% orphans)
├── processed/chn/     CHN production data (Summer 2025)
├── raw/eur/           EUR raw extraction (FIXED, LOBT corrected)
├── raw/chn/           CHN raw data
├── derived/eur/       EUR enriched intermediates
├── archive/           Archived OLD data (pre-LOBT fix)
├── manifest/          Authoritative manifest & snapshots
└── handover/          Cross-machine sync & documentation
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

Download and verify production data:

```sh
Rscript scripts/r2-list-files.R
Rscript scripts/r2-sync-status.R
Rscript scripts/r2-download-data-store.R
Rscript scripts/00-check-data-store.R
```

`r2-sync-status.R` compares the local cache with
`manifest/current-artifacts.csv`. `r2-download-data-store.R` verifies downloaded
files against manifest SHA-256 hashes when the manifest is present.

Production datasets (harmonized EUR-CHN schema):
- `processed/eur/EUR-canonical-milestones-summer2025.parquet` (21 cols, 21.0 MB)
- `processed/eur/EUR-level-segments-summer2025.parquet` (31 cols, 4.5 MB)
- `processed/chn/CHN-canonical-milestones-summer2025.parquet` (21 cols, 20.9 MB)
- `processed/chn/CHN-level-segments-summer2025.parquet` (31 cols, 6.1 MB)

### Maintainer Workflow

After processing or updating artifacts locally:

```sh
Rscript scripts/00-check-data-store.R
Rscript scripts/r2-upload-data-store.R
Rscript scripts/11-update-r2-registry-for-fixed.R
Rscript scripts/r2-publish-manifest.R --dry-run
Rscript scripts/r2-publish-manifest.R
Rscript scripts/r2-sync-status.R
```

`scripts/r2-upload-data-store.R` uploads registered artifacts.
`scripts/r2-publish-manifest.R` publishes the authoritative manifest.

### Authoritative Manifest

`manifest/current-artifacts.csv` is the lightweight source of truth for data
artifacts. A data artifact is authoritative only when it is listed there with
`required == TRUE` and its local SHA-256 hash matches.

The manifest records:

- object key
- source and stage (`raw`, `derived`, `production`)
- required flag
- version label
- SHA-256 hash and byte size
- producing script
- input artifact keys

Current production artifacts (required=TRUE):
- EUR canonical milestones (FIXED, 0% orphans, CHN-compatible)
- EUR level segments (FIXED, 100% complete)
- CHN canonical milestones (Summer 2025)
- CHN level segments (Summer 2025)

## Local Data Store

Each machine maintains a local cache:

```text
FUELBURN_DATA_STORE/
├── processed/eur/     Production EUR data (FIXED)
├── processed/chn/     Production CHN data
├── raw/eur/           EUR extraction files (FIXED)
├── raw/chn/           CHN source data
├── derived/eur/       EUR enriched intermediates
├── manifest/          Local manifest copy
└── handover/          Sync reports
```

`scripts/00-check-data-store.R` validates folder structure, required file
presence, parquet row/column counts, and writes local manifest/handover outputs.

## EUR Data Pipeline (FIXED)

EUR PRU data preparation with LOBT bug correction and EUR-CHN schema harmonization:

### Pipeline Steps

1. **Extract canonical milestones** (`scripts/01-extract-eur-canonical.R`)
   - Reads PRU G2G FIXED extraction (two-stage SAM_ID, LOBT corrected)
   - Uses `fuel_eur_milestones()` from prungs package

2. **Enrich canonical schema** (`scripts/06-enrich-eur-canonical.R`)
   - Add TOTAL_FLOWN_NM, MST_GROUP, MST_METHOD, DIST_REMAINING_NM
   - CHN-compatible metadata (21 columns)

3. **Harmonize milestones** (`scripts/04-harmonize-eur-milestones.R`)
   - Rename distance milestones (F40→D040, L40→A040, etc.)
   - Map FL100 to direction-aware labels (D_FL100/A_FL100)
   - Derive FL crossings (D_FL075, D_FL180, A_FL075, A_FL180)
   - Reconstruct LVL_START/LVL_END pairs

4. **Derive level segments** (`scripts/05-derive-eur-level-segments.R`)
   - Pair LVL_START with LVL_END markers
   - Calculate duration, altitude change, fuel burn
   - Apply QC flags
   - **Result: 86,142 segments, 0% orphans!**

5. **Enrich level segments** (`scripts/07-enrich-eur-level-segments.R`)
   - Add LEVEL_CONTEXT_PHASE (CLIMB/DESCENT/ENROUTE)
   - Add MST_GROUP and MST_METHOD (consistency)

6. **Create production datasets** (`scripts/08-create-harmonized-analytical-datasets.R`)
   - EUR-canonical-milestones-summer2025.parquet (21 cols)
   - EUR-level-segments-summer2025.parquet (31 cols)

7. **Upload to R2** (`scripts/09-upload-eur-fixed-to-r2.R`)
   - Archive OLD data to archive/old-lobt-bug/
   - Upload production data to processed/eur/
   - Generate handover documentation

8. **Publish manifest** (`scripts/r2-publish-manifest.R`)
   - Update manifest/current-artifacts.csv
   - Archive snapshot

### Pipeline Quality

| Metric | OLD Pipeline | FIXED Pipeline | Improvement |
|--------|-------------|----------------|-------------|
| Orphan Rate | 54.4% | **0.0%** | -100% |
| Total Segments | 60,012 | **86,142** | +43.6% |
| Complete Segments | 90.8% | **100%** | +9.2% |

### Key Documentation

- **Pipeline:** `notes/EUR-Pipeline-FIXED-Documentation.md`
- **LOBT Bug:** `notes/CRITICAL-LOBT-Filter-Bug.md`
- **Results:** `notes/EUR-FIXED-Final-Results.md`
- **EUR-CHN Schema:** `notes/EUR-CHN-Schema-Comparison.md`
- **Canonical Model:** `notes/canonical-milestone-model.md`

## CHN Data Pipeline

CHN QAR data (Summer 2025 update):

```sh
Rscript scripts/process-chn-summer2025-update.R
Rscript scripts/upload-chn-summer2025-to-r2.R
```

Produces:
- CHN-canonical-milestones-summer2025.parquet (21 cols, EUR-compatible)
- CHN-level-segments-summer2025.parquet (31 cols)
- CHN-phase-summaries-summer2025.parquet

## Reference Project

The previous work is expected at:

`../paper-2025-ICNS-CHN-EUR-fuelburn`

Set `FUELBURN_2025_PROJECT` if the reference project lives elsewhere.

## First Commands

```sh
# Download production data
Rscript scripts/r2-list-files.R
Rscript scripts/r2-sync-status.R
Rscript scripts/r2-download-data-store.R
Rscript scripts/00-check-data-store.R

# Render documents
quarto render paper.qmd --to html
quarto render technical-note-data-preparation.qmd --to html

# EUR pipeline (if reprocessing)
Rscript scripts/01-extract-eur-canonical.R
Rscript scripts/06-enrich-eur-canonical.R
Rscript scripts/04-harmonize-eur-milestones.R
Rscript scripts/05-derive-eur-level-segments.R
Rscript scripts/07-enrich-eur-level-segments.R
Rscript scripts/08-create-harmonized-analytical-datasets.R
```

## Data Quality Assurance

All production datasets include:
- SHA-256 checksums in authoritative manifest
- Version labels (FIXED-summer2025, summer2025)
- QC flags for level segments
- Metadata tracking (MST_GROUP, MST_METHOD, LEVEL_CONTEXT_PHASE)
- Pipeline provenance (producing scripts documented)

EUR FIXED pipeline ensures:
- 0% orphan rate (complete segment pairing)
- EUR-CHN schema compatibility
- Full trajectory coverage (two-stage SAM_ID extraction)
- Enriched metadata for analysis

---

**Status:** Production-ready EUR-CHN harmonized datasets (FIXED pipeline) with complete metadata, 0% orphans, and synchronized manifest for multi-contributor collaboration.

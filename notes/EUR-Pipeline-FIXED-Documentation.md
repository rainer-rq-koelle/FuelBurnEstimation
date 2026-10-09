# EUR Data Preparation Pipeline - FIXED (October 2026)

## Overview

This document describes the complete EUR data preparation pipeline from PRU G2G extraction through to production-ready analytical datasets with 0% orphan rate and EUR-CHN schema compatibility.

**Pipeline Status:** ✅ Production (FIXED)  
**Orphan Rate:** 0.0% (down from 54.4% in OLD pipeline)  
**EUR-CHN Compatible:** Yes (harmonized schemas)  
**Last Updated:** 2026-10-09

---

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ EUR Data Preparation Pipeline (FIXED)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PRU G2G Query (FIXED)                                         │
│  ├─ Two-stage SAM_ID extraction (LOBT bug corrected)          │
│  ├─ Flight metadata: 21,503 flights                           │
│  └─ Segment details: 637,762 segments                         │
│          │                                                      │
│          ↓                                                      │
│  Raw Canonical Milestones                                      │
│  └─ scripts/01-extract-eur-canonical.R                        │
│     (fuel_eur_milestones from prungs package)                 │
│          │                                                      │
│          ↓                                                      │
│  Schema Enrichment                                             │
│  └─ scripts/06-enrich-eur-canonical.R                         │
│     ├─ Add TOTAL_FLOWN_NM (total trajectory distance)         │
│     ├─ Add MST_GROUP (milestone categorization)               │
│     ├─ Add MST_METHOD (derivation tracking)                   │
│     └─ Add DIST_REMAINING_NM (distance to destination)        │
│          │                                                      │
│          ↓                                                      │
│  Milestone Harmonization                                       │
│  └─ scripts/04-harmonize-eur-milestones.R                     │
│     ├─ Rename distance milestones (F40→D040, etc.)            │
│     ├─ Map FL100 to direction-aware D_FL100/A_FL100           │
│     ├─ Derive FL crossings (D_FL075, D_FL180, etc.)           │
│     └─ Reconstruct LVL_START/LVL_END pairs                    │
│          │                                                      │
│          ↓                                                      │
│  Level Segment Derivation                                      │
│  └─ scripts/05-derive-eur-level-segments.R                    │
│     ├─ Pair LVL_START with LVL_END markers                    │
│     ├─ Calculate duration, altitude change, fuel burn         │
│     ├─ Apply QC flags                                         │
│     └─ Result: 86,142 segments, 0% orphans                    │
│          │                                                      │
│          ↓                                                      │
│  Segment Enrichment                                            │
│  └─ scripts/07-enrich-eur-level-segments.R                    │
│     ├─ Add LEVEL_CONTEXT_PHASE (CLIMB/DESCENT/ENROUTE)        │
│     ├─ Add MST_GROUP (level_segment)                          │
│     └─ Add MST_METHOD (derived_interval)                      │
│          │                                                      │
│          ↓                                                      │
│  Production Datasets                                           │
│  └─ scripts/08-create-harmonized-analytical-datasets.R        │
│     ├─ EUR-canonical-milestones-summer2025.parquet (21 cols)  │
│     └─ EUR-level-segments-summer2025.parquet (31 cols)        │
│          │                                                      │
│          ↓                                                      │
│  R2 Upload & Archive                                           │
│  └─ scripts/09-upload-eur-fixed-to-r2.R                       │
│     ├─ Archive OLD data to archive/old-lobt-bug/              │
│     ├─ Upload to processed/eur/                               │
│     └─ Update manifest                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Critical Bug Fix: LOBT Filter Issue

### Problem

The original PRU query filtered segments by LOBT, which caused incomplete flights:
- Many segments from complete flights were excluded
- Artificial orphan rate of 54.4%
- Only 60,012 segments captured (vs 86,142 actual)

### Solution (FIXED Pipeline)

**Two-stage SAM_ID extraction:**

1. **Stage 1:** Select flights by LOBT
   ```sql
   SELECT DISTINCT SAM_ID 
   FROM flight_metadata 
   WHERE LOBT BETWEEN '2025-06-01' AND '2025-06-30'
   ```

2. **Stage 2:** Get ALL segments for those SAM_IDs
   ```sql
   SELECT * 
   FROM segment_details 
   WHERE SAM_ID IN (...)
   -- NO LOBT filter here!
   ```

### Results

| Metric | OLD | FIXED | Improvement |
|--------|-----|-------|-------------|
| Orphan Rate | 54.4% | 0.0% | -100% |
| Total Segments | 60,012 | 86,142 | +43.6% |
| Complete Segments | 90.8% | 100% | +9.2% |

**Documentation:** `notes/CRITICAL-LOBT-Filter-Bug.md`

---

## EUR-CHN Schema Harmonization

### Canonical Milestones (21 columns)

**Core Fields:**
- SOURCE_UID, FLTID, ADEP, ADES, TYPE
- TIME, LAT, LON, ALT_FT
- MST, TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL
- DIST_FLOWN_NM, DIST_FROM_DEP_NM, DIST_TO_ARR_NM
- FLIGHT_PHASE_RAW, ROW_ID

**Enrichments (NEW):**
- **TOTAL_FLOWN_NM:** Total trajectory distance (max of DIST_FLOWN_NM per flight)
- **MST_GROUP:** Milestone categorization
  - operational_profile (AOBT, ATOT, ALDT, AIBT, etc.)
  - level_segment (LVL_START, LVL_END)
  - cruise_bounds (TOC, TOD)
  - departure_flow (D040, D100, D_FL100, D_FL180)
  - arrival_flow (A100, A040, A_FL100, A_FL075)
  - airspace_boundary (FIR, AUA)
- **MST_METHOD:** Derivation tracking
  - explicit_pru_source (from PRU G2G)
  - derived_operational (trajectory analysis)
  - derived_fl_crossing (algorithmic)
  - derived_distance (cumulative distance)
- **DIST_REMAINING_NM:** Distance to destination (TOTAL_FLOWN_NM - DIST_FLOWN_NM)

### Level Segments (31 columns)

**Core Fields:**
- SOURCE_UID, ADEP, ADES, TYPE, SEGMENT_ID, SEGMENT_ORDER
- START_TIME, START_ALT_FT, START_FUEL_KG, START_PHASE
- END_TIME, END_ALT_FT, END_FUEL_KG, END_PHASE
- DURATION_SEC, ALTITUDE_CHANGE_FT, MEAN_ALTITUDE_FT
- FUEL_BURN_KG, ALTITUDE_BAND, PHASE_CONTEXT

**Enrichments (NEW):**
- **LEVEL_CONTEXT_PHASE:** Phase categorization
  - ENROUTE (49,759 segments, >FL200)
  - DESCENT (27,215 segments)
  - CLIMB (5,138 segments)
  - TERMINAL (108 segments, <FL100)
  - INTERMEDIATE (3,922 segments, FL100-FL200)
- **MST_GROUP:** level_segment (consistency with canonical)
- **MST_METHOD:** derived_interval

**QC Flags:**
- HAS_END, qc_orphaned, qc_zero_duration, qc_negative_duration
- qc_excessive_altitude_change, qc_missing_fuel, qc_negative_fuel, qc_flag

**Documentation:** `notes/EUR-CHN-Schema-Comparison.md`

---

## Key Scripts

### Data Extraction

**`scripts/01-extract-eur-canonical.R`**
- Reads PRU G2G FIXED extraction parquet files
- Calls `fuel_eur_milestones()` from prungs package
- Outputs: EUR-canonical-milestones-summer2025-FIXED.parquet

### Enrichment

**`scripts/06-enrich-eur-canonical.R`**
- Adds TOTAL_FLOWN_NM, MST_GROUP, MST_METHOD, DIST_REMAINING_NM
- Outputs: EUR-canonical-milestones-summer2025-ENRICHED.parquet (21 cols)

**`scripts/07-enrich-eur-level-segments.R`**
- Adds LEVEL_CONTEXT_PHASE, MST_GROUP, MST_METHOD
- Outputs: level-segments-eur-2026-ENRICHED.parquet (31 cols)

### Harmonization & Derivation

**`scripts/04-harmonize-eur-milestones.R`**
- Renames distance milestones
- Maps FL100 to direction-aware labels
- Derives FL crossing milestones
- Reconstructs LVL events into START/END pairs
- Adds implicit END markers at trajectory end

**`scripts/05-derive-eur-level-segments.R`**
- Pairs LVL_START with LVL_END
- Calculates segment metrics
- Applies QC flags
- Result: 0% orphans!

### Production

**`scripts/08-create-harmonized-analytical-datasets.R`**
- Creates production datasets with column reordering
- EUR-canonical-milestones-summer2025.parquet (21 cols, 21.0 MB)
- EUR-level-segments-summer2025.parquet (31 cols, 4.5 MB)
- dataset-manifest-summer2025.csv

### R2 Synchronization

**`scripts/09-upload-eur-fixed-to-r2.R`**
- Archives OLD data to archive/old-lobt-bug/
- Uploads production data to processed/eur/
- Creates handover documentation
- Updates upload manifest

**`scripts/11-update-r2-registry-for-fixed.R`**
- Updates R/r2-storage.R artifact registry
- Registers production artifacts

**`scripts/r2-publish-manifest.R`**
- Publishes authoritative manifest to R2
- manifest/current-artifacts.csv (current)
- manifest/archive/artifacts-YYYYMMDD-HHMMSS.csv (snapshot)

### Cleanup

**`scripts/10-cleanup-intermediate-files.R`**
- Removes intermediate processing files
- Archives local OLD data
- Keeps production datasets and documentation

---

## Production Data Locations

### R2 Storage

```
r2://paper-fuel-burn-estimation/
├── processed/eur/
│   ├── EUR-canonical-milestones-summer2025.parquet (21 cols, 21.0 MB)
│   ├── EUR-level-segments-summer2025.parquet (31 cols, 4.5 MB)
│   └── EUR-dataset-manifest-summer2025.csv
├── processed/chn/
│   ├── CHN-canonical-milestones-summer2025.parquet (21 cols, 20.9 MB)
│   ├── CHN-level-segments-summer2025.parquet (31 cols, 6.1 MB)
│   └── CHN-phase-summaries-summer2025.parquet
├── archive/old-lobt-bug/
│   ├── canonical-milestones-eur-2026-harmonized.parquet (OLD)
│   └── level-segments-eur-2026.parquet (OLD, 9.2% orphans)
├── manifest/
│   ├── current-artifacts.csv (authoritative manifest)
│   └── archive/artifacts-*.csv (snapshots)
└── handover/
    └── eur-fixed-upload-20261009.txt
```

### Local Data Store

```
$FUELBURN_DATA_STORE/
├── processed/eur/
│   ├── EUR-canonical-milestones-summer2025.parquet
│   └── EUR-level-segments-summer2025.parquet
├── processed/chn/
│   ├── CHN-canonical-milestones-summer2025.parquet
│   ├── CHN-level-segments-summer2025.parquet
│   └── CHN-phase-summaries-summer2025.parquet
├── raw/eur/
│   ├── EUR-canonical-milestones-summer2025-FIXED.parquet
│   ├── EUR-canonical-milestones-summer2025-ENRICHED.parquet
│   ├── g2g-flight-metadata-2025-summer-FIXED.parquet
│   └── g2g-segment-details-2025-summer-FIXED.parquet
├── derived/eur/
│   └── level-segments-eur-2026-ENRICHED.parquet
└── manifest/
    └── current-artifacts.csv
```

---

## Quality Metrics

### EUR FIXED Pipeline

| Metric | Value |
|--------|-------|
| Flights | 21,503 |
| Canonical Rows | 696,076 |
| Level Segments | 86,142 |
| Complete Segments | 86,142 (100%) |
| Orphaned Segments | 0 (0.0%) |
| Mean Segment Duration | 958.9 sec |
| Median Segment Duration | 349 sec |

### Segment Phase Distribution

| Phase | Count | Percentage |
|-------|-------|------------|
| ENROUTE (>FL200) | 49,759 | 57.8% |
| DESCENT | 27,215 | 31.6% |
| CLIMB | 5,138 | 6.0% |
| INTERMEDIATE (FL100-FL200) | 3,922 | 4.6% |
| TERMINAL (<FL100) | 108 | 0.1% |

---

## Contributor Workflow

### Initial Setup

1. Download authoritative manifest:
   ```sh
   Rscript scripts/r2-download-data-store.R
   ```

2. Verify local data:
   ```sh
   Rscript scripts/00-check-data-store.R
   ```

### Working with Production Data

Access production datasets from R2:
- `processed/eur/EUR-canonical-milestones-summer2025.parquet`
- `processed/eur/EUR-level-segments-summer2025.parquet`
- `processed/chn/CHN-canonical-milestones-summer2025.parquet`
- `processed/chn/CHN-level-segments-summer2025.parquet`

All contributors work from the same authoritative manifest ensuring data consistency.

---

## Related Documentation

- **LOBT Bug:** `notes/CRITICAL-LOBT-Filter-Bug.md`
- **Pipeline Results:** `notes/EUR-FIXED-Final-Results.md`
- **Schema Comparison:** `notes/EUR-CHN-Schema-Comparison.md`
- **Column Attribution:** `notes/Column-Attribution-Smoke-Test.md`
- **Handover:** `notes/EUR-FIXED-R2-Upload-20261009.txt`
- **Canonical Model:** `notes/canonical-milestone-model.md`

---

## Future Work

1. Apply FIXED pipeline to additional time periods
2. Extend harmonization to other regions (NAM, APAC)
3. Automate end-to-end processing
4. Develop validation dashboards
5. Document fuel burn estimation methodology

---

**Status:** Production-ready EUR-CHN harmonized datasets with 0% orphans, complete metadata, and synchronized manifest for multi-contributor collaboration.

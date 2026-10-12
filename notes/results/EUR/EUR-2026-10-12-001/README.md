# EUR Parallel Preprocessing Candidate

**Run:** `EUR-2026-10-12-001`
**Status:** Candidate for the study pilot; not a replacement for the existing EUR production release.
**R2 prefix:** `derived/eur/parallel-preprocessing/EUR-2026-10-12-001/`

## Purpose

This run creates a parallel European analytical dataset from the PRU G2G study sample and the accepted PRU CCO/CDO interval products. Its milestone labels and table schemas are aligned with the current Chinese canonical outputs so both regions can enter the same study framework. The candidate preserves all 21,503 study flights and supplies a separate screening table for selecting an initial pilot subset.

## Inputs and mapping

- G2G flight metadata and segment details from the restricted `raw/eur/source-sample/` prefix.
- Monthly M3 trajectories for June–August 2025. `SAM_ID` is retained as `SOURCE_UID`; `FLTID` is populated from the unique `CALLSIGN` associated with M3 `FLIGHT_ID == SAM_ID`.
- Monthly PRU CCO and CDO interval files. Only rows where `CONSIDERED == 1` are promoted to level segments. CCO maps to `LEVEL_CONTEXT_PHASE = CLIMB`; CDO maps to `DESCENT`.

The M3 mapping covered all 21,503 study flights with one non-empty callsign each. Route and aircraft type agreed with the G2G metadata for every mapped flight. `FIR` and `AUA` crossings are excluded from this release; they require a separate geospatial treatment.

G2G fuel and distance values are row increments and are accumulated in time order. The source provides both `FUEL_BURNT_KG` and `FUEL_BURNT_KG_ORIGINAL`; both were retained as delivered, with no additional take-off adjustment. Their flight totals reconcile with the G2G metadata within floating-point precision. The local extraction companion was used as a row-level cross-check and matched both series on all 637,762 rows.

## Canonical form

The milestone, level-segment, and phase-summary columns have the same names and order as the current CHN parquet tables (27, 22, and 15 columns, respectively, including lowercase `source_batch`). The EUR milestone label set is identical to the CHN set. `LVL` point tags are represented as paired `LVL_START` and `LVL_END` rows linked by `LEVEL_SEGMENT_ID`.

The accepted PRU interval supplies each level boundary's exact time, coordinate, and altitude. Cumulative adjusted/original fuel and flown distance are linearly interpolated from adjacent G2G rows at those times, with no extrapolation. `START_ROW_ID` and `END_ROW_ID` refer to the nearest G2G row for traceability; exact event times and positions remain those from CCO/CDO. For 2,571 of 49,836 intervals, both boundaries resolve to the same nearest G2G row because G2G is sparse relative to CCO/CDO. The separately stored extension table preserves PRU `DIST_LEVEL_NM`, `Add_fuel_kg`, `Add_CO2_kg`, detector metadata, and G2G-integrated values. `PRU_LEVEL_EXCESS_FUEL_KG` is not the actual fuel burned inside the interval and is not substituted for `LEVEL_FUEL_KG`.

## Build and checks

Run from the repository root after the source files are available locally in the ignored data store:

```sh
Rscript scripts/build-eur-parallel-canonical.R
```

Add `--upload` to place the six flight-level parquet files and aggregate build audit in the restricted R2 candidate prefix. The script does not write to production prefixes. It writes the aggregate audit to this directory and to the ignored local output directory.

Build results:

- 21,503 flights; 569,408 canonical milestone rows.
- 49,836 accepted level intervals across 19,279 flights: 9,091 climb and 40,745 descent.
- All accepted intervals matched a G2G flight and had G2G time coverage; no negative or missing integrated interval fuel/distance was found.
- Adjusted and original fuel totals, and total distance, reconcile to flight metadata within `3e-11` kg and `2e-12` NM.
- The milestone label set and all three shared table schemas match the current CHN parquet outputs exactly.
- 21,320 flights pass the initial `FULL_PROFILE_SCREEN_PASS` rule: unique FLTID, ATOT/TOC/TOD/ALDT present, and positive, complete CLIMB/CRUISE/DESCENT intervals. This is a pilot-screening rule, not a final validity determination.
- Across all nine phase summaries, 586 intervals have zero duration and 8 have missing duration (four `RUNWAY_EXIT` and four `TAXI_IN`); no negative phase durations were found. These remain visible as zero or missing values.
- 3,658 PRU `Add_fuel_kg` values are negative. They are preserved without clipping and need methodological interpretation before use as an efficiency measure.

The exact aggregate build audit is in [`EUR-parallel-build-audit.csv`](EUR-parallel-build-audit.csv). Flight-level outputs and hashes belong in restricted R2; no flight identifiers or callsigns are included in this GitHub evidence folder.

## Candidate outputs in R2

- `EUR-canonical-milestones-parallel.parquet`
- `EUR-level-segments-parallel.parquet`
- `EUR-level-segment-extensions.parquet`
- `EUR-phase-summaries-parallel.parquet`
- `EUR-flights-parallel.parquet`
- `EUR-flight-eligibility-parallel.parquet`
- `EUR-parallel-build-audit.csv`
- `EUR-parallel-artifact-manifest.csv`

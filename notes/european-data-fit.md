# European Data Fit For Refined Milestones

Source inspected:

`../international-CHN-EUR-2025/data/fuel-burn-study/`

## Canonical European Milestones

`EUR-canonical-milestones-summer2025.parquet`

- 696,076 rows
- 17 columns
- 21,503 flights for the main backbone milestones
- Existing fields match the imported canonical model:
  - `SOURCE_UID`
  - `ADEP`, `ADES`, `TYPE`
  - `TIME`, `LAT`, `LON`, `ALT_FT`
  - `MST`
  - `TOT_FUEL_KG`, `TOT_FUEL_KG_ORIGINAL`
  - `DIST_FLOWN_NM`
  - `FLIGHT_PHASE_RAW`
  - `ROW_ID`

Important observed milestone labels:

- Backbone: `AOBT`, `ERWY`, `ATOT`, `DLTO`, `D40`, `D100`, `TOC`, `TOD`, `A100`, `A40`, `ALTO`, `ALDT`, `XRWY`, `AIBT`
- Existing extra event labels: `LVL`, `FL100`, `FIR`, `AUA`

`MST == "LVL"` appears 84,939 times. These are not yet paired as `LVL_START` and `LVL_END`, but the row ordering and `FLIGHT_PHASE_RAW` field should allow grouping consecutive level rows into level intervals.

Relevant raw flight-phase labels:

- `Lvl_climb`: 39,029 rows
- `Lvl_descent`: 78,640 rows
- plus ordinary `Climb`, `Cruise`, `Descent`, `Taxi-Out`, `Approach`, etc.

## Phase Summaries

`EUR-phase-summaries-summer2025.parquet`

- 193,309 rows
- 21,503 flights for most phases
- Existing phase model:
  - `TAXI_OUT`
  - `TAKE_OFF_ROLL`
  - `LTO_CLIMB_OUT`
  - `CLIMB`
  - `CRUISE`
  - `DESCENT`
  - `LTO_APPROACH_LANDING`
  - `RUNWAY_EXIT`
  - `TAXI_IN`

## Existing Smoothness Summaries

The report-facing topic-study files already include level-flight descriptors for distance bands:

`topic-study/eur-distance-band-smoothness-summary.csv`

Observed medians:

- long 1900 km: climb 0.0 min level, descent 2.52 min level
- medium 1200 km: climb 0.1 min level, descent 1.5 min level
- short 1000 km: climb 0.5 min level, descent 4.25 min level

This confirms the European side already fits the refined concept: level flight is present and summarised, but the next step is to recover or derive event pairs as milestones.

## Implication For This Project

The European data can support the proposed approach in two layers:

1. Keep the canonical backbone milestones as-is.
2. Derive `LVL_START` / `LVL_END` interval milestones from consecutive `LVL` rows, especially those labelled `Lvl_climb` and `Lvl_descent`.

This will make the European and Chinese paths comparable at the level of flight-profile characterisation, even if their raw data sources differ.

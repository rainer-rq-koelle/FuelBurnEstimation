# VFE And Level-Off Implementation Scan

## External Methodology

The EUROCONTROL/PRU material supports the direction we discussed:

- VFE for climb/descent is based on detecting level segments in the relevant climb/descent portions.
- The published methodology limits the analysis to a 200 NM radius around the relevant airport for the PRU implementation.
- The harmonised vertical-rate threshold is 300 feet per minute.
- The climb analysis starts around 3000 ft AGL; descent ends around 1800 ft AGL.
- The methodology explicitly treats average time in level flight as a practical proxy, not a direct fuel-burn calculation.

For this paper, we can use the same detection lineage but retain a richer milestone table rather than only computing aggregate VFE indicators.

## Local Implementations Found

### `paper-ICNS-2024/R/level_segments.R`

This is the clearest Sam/PRU-style implementation.

Relevant functions:

- `check_level_flight()`
- `extract_level_segments()`
- `exclude_level_segments_per_uid()`

It flags level portions using a flight-level/time threshold equivalent to 300 ft/min, extracts begin/end rows, and filters artefacts such as coverage hiccups and levels close to entry altitude.

### `BRA-EUR-pointmerge/R/trj_level_segments.R`

This version has the most direct milestone conversion:

- `check_level_segments()`
- `level_segments_to_msts()`

It converts flagged segments directly into:

- `LVL_START`
- `LVL_END`

and attaches a level identifier plus minimum-duration filtering.

### `international-CHN-EUR-2025/R/canonical-fuel-milestones.R`

This is now imported into the current repo. It already has:

- `fuel_vertical_profile()`
- `fuel_level_descriptors()`
- `fuel_eur_level_descriptors_from_segments()`
- `fuel_eur_level_descriptors_from_milestones()`

It currently summarises level time and level share, but does not yet expose level segments as paired milestones.

### `paper-2024-SID/R/vertical-flight-efficiency.R`

This work used OPDI flight events with `level-start` and `level-end` after top-of-descent and within 200 NM of EHAM. It also compared the resulting time-in-level-flight series against PRU monitored VFE values.

One useful insight: short level segments matter. That work notes a material share of short segments below the current reporting threshold, which is relevant for sensitivity tests.

### `borealis-study-backup`

This contains older 3Di/VFE machinery:

- level segment extraction;
- conversion to milestone-like level events;
- vertical component summaries by phase;
- weighting by requested flight level.

The weighting logic is probably not the first thing to reuse, but the idea of classifying level intervals as climb, enroute, or descent is useful.

### `international-PBWG-2026/TN-milestone-tables.qmd`

This already frames CCO/CDO as a level-segment study and explicitly links it to a harmonised milestone table for flight-phase fuel-burn/CO2 estimation.

### `paper-2026-OSN-PBWG`

This is the most directly reusable recent implementation.

Relevant files:

- `R/trajectory_milestones.R`
- `scripts/16-build-analyst-milestone-dataset.R`
- `docs/trajectory-milestones.md`
- `docs/playdata-trajectory-milestone-showcase.qmd`

Key functions and concepts:

- `build_trajectory_profile()` enriches prepared trajectory points with airport/runway geometry, flight level, cumulative track distance, previous-point state, and profile gaps.
- `select_vfe_boundary_milestones()` derives `arr_A200` and `dep_D200` from ARP 200 NM crossings.
- `select_vfe_tod_toc_milestones()` derives `arr_TOD_A200` and `dep_TOC_D200`.
- `build_vfe_level_segment_milestones()` scans consecutive intervals, flags those with absolute vertical rate at or below 300 ft/min, merges contiguous level intervals, and writes paired event rows:
  - `arr_vfe_level_start`
  - `arr_vfe_level_end`
  - `dep_vfe_level_start`
  - `dep_vfe_level_end`
- The level milestones carry:
  - `vfe_level_segment_id`
  - `vfe_level_duration_seconds`
  - `vfe_level_distance_nm`
- `summarise_vfe_level_segments()` reconstructs interval rows from paired start/end milestones and derives altitude-band measures from the underlying profile points.
- `qualify_vfe_level_segments()` applies rule sets after extraction.

The OSN default extractor is intentionally generous:

- vertical-rate threshold: 300 ft/min;
- minimum raw level duration: 10 seconds;
- maximum adjacent-point gap: 30 seconds.

The showcase then qualifies candidates with rules such as:

- `baseline_20s_200ft`: at least 20 seconds duration and no more than 200 ft altitude band;
- `duration_30s_200ft`;
- `duration_60s_200ft`;
- `band_20s_100ft`;
- `band_20s_300ft`;
- `conservative_30s_100ft`.

This separation between raw extraction and qualification is useful for the fuel-burn paper. It lets us preserve level-off evidence in the milestone table while keeping reporting thresholds transparent and sensitivity-testable.

## Suggested Implementation Direction

Add a new module:

`R/level-off-milestones.R`

Initial functions:

- `detect_level_flags()`
- `level_flags_to_segments()`
- `level_segments_to_milestones()`
- `append_level_milestones()`
- `summarise_level_intervals()`

The output should preserve both:

- event rows: `LVL_START` / `LVL_END`
- interval rows: one row per level segment with duration, fuel, distance, phase context, altitude band, and order within flight.

Sensitivity parameters to expose:

- vertical-rate threshold, default 300 ft/min;
- minimum duration, with a raw extractor default near 10 seconds and reporting rules such as 20, 30, 60, and 120 seconds;
- maximum altitude band for qualifying a level segment, for example 100, 200, and 300 ft;
- airport radius, default 200 NM for PRU comparability;
- phase context method: milestone-window based first, raw phase labels second.

The OSN implementation is close enough that we should adapt its design rather than start from the older Sam wrapper alone. The older wrapper remains useful provenance for the threshold logic; OSN gives us the modern event-table contract.

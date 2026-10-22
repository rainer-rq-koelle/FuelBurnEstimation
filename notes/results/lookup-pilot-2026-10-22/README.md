# Partial lookup snapshot, 22 October 2026

See `notes/paper-lookup-table.md` for definitions, support rules, fuel-convention
checks and interpretation. This is a source-derived descriptive pilot.

- `wide_grid.csv`: one row per lookup cell, with metric-specific n, P20/P50/P80,
  status and paired-support flags. The 180 rows include baseline rows, actual
  altitude-conditioned rows and explicitly unassigned terminal-class slots.
  They are not 180 validated coefficients.
- `grid.csv`: the same grid in long form, 900 metric rows.
- `profile_support.csv`: enroute fuel support by fixed altitude class.
- `paired_support.csv`: paired regional support by class and metric.
- `quality_summary.csv`: separate profile, fuel and distance support.
- `variant_audit.csv`: original/delivered EUR airborne fuel consistency.
- `input-manifest.csv`, `source-manifest.csv`: exact SHA-256 input/code identity.
  Resolve `data-store/` against `FUELBURN_DATA_STORE`; other paths are relative
  to the project root.
- `session-info.txt`: runtime from the standalone lookup export.

Reproduce with scripts 14 then 15, and `tests/paper-lookup-table.R`. The cached
enroute class input must match both current source hashes and the flight cohort.
Detailed flight records remain in the ignored output store; this snapshot
contains aggregate references and no flight identifiers. Sparse percentiles
are suppressed. Class-not-assigned rows use missing support rather than zero.

The `paper.qmd` source hash includes the subsequent Word output configuration
added on 22 October; this export-only change leaves the aggregate results intact.

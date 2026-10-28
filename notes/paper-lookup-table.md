# Partially populated phase-reference lookup

Development record, 22 October 2026. This note records pilot eligibility and
input details; the paper keeps the methodological description and examples.

## What can already be populated

The key is source/region × exact aircraft type × engine group × 100 NM GCD band
× phase × common profile class. Engine identity is not in the supplied study
metadata, so **Not stratified** is explicit, rather than an invented common engine.

Three distinct row kinds preserve the meaning of incomplete dimensions:

1. **Marginal baseline:** all profiles pooled within each aircraft/GCD/phase cell.
   The six existing shared cells × three airborne phases × two regions give
   36 baseline rows. These are not profile-conditioned comparisons.
2. **Profile-conditioned enroute:** source-window time-weighted mean pressure
   altitude below FL300, FL300--339, or FL340 and above. Thresholds are fixed
   across regions and independent of the fuel outcome. Altitude-unobserved rows
   are explicit. These are altitude classes, not interruption/smoothness classes.
3. **Reserved terminal-phase classes:** continuous, lightly interrupted, heavily
   interrupted, and unknown coverage for climb and descent. They remain
   unassigned; support and percentiles are NA, not zero. They do not claim that
   an absent classification represents uninterrupted flight.

The complete grid exports both a long metric table (`grid.csv`) and one row per
lookup cell (`wide_grid.csv`). The six source aircraft/stage cells are A20N,
A21N, A320, A321 and B738 over 600--699 NM, plus A21N over 500--599 NM.

## Metrics and sample support

For the source ATOT--TOC--TOD--ALDT partition, calculate phase fuel from cumulative
fuel differences and elapsed time from the corresponding timestamp differences.
Whole-airborne climb includes climb-out; descent includes approach/landing.
The pilot does not substitute the narrower supplied CLIMB/DESCENT phase rows.

Each metric has its own eligible-flight count and P20/P50/P80:

- Total fuel kg: finite, positive phase fuel and eligible source fuel channels.
- Duration min: independently valid source-window timing; not automatically
  reduced to the fuel-eligible sample.
- kg/min: each flight's phase fuel divided by its own phase duration.
- kg/NM: each flight's phase fuel divided by its own **flown phase distance**,
  with the stricter distance screen. GCD is only the stage-length stratum.
- Flown NM: the exposure corresponding to the eligible distance-based rates.

Suppress percentile values when n<30. Retain the actual n and an explicit sparse
or empty status; allow a source-specific populated row even if its regional
counterpart is sparse. A paired-support flag requires n>=30 in both regions for
the particular metric. Separate percentile columns are marginal distributions
within a cell; they are not one joint flight vector. Do not average class
percentiles to obtain the pooled reference, or add pooled and conditional counts.

There are **three paired enroute fuel cells**:

| Aircraft | GCD band | Altitude class | Fuel n CHN / EUR |
|---|---|---|---:|
| A21N | 500--599 NM | FL340+ | 37 / 266 |
| A320 | 600--699 NM | FL300--339 | 35 / 195 |
| A321 | 600--699 NM | FL300--339 | 51 / 44 |

Distance eligibility supports fewer comparisons; the A320 middle-altitude cell
does not meet the paired kg/NM threshold. This is one reason to retain per-metric
support instead of copying the fuel count to every lookup column.

The A21N / 500--599 NM / enroute / FL340+ cell illustrates all four requested
reference metrics in the paper. Fuel, time and kg/min have n=37 / 266; kg/NM
has n=36 / 266. The full CSVs contain the other cells and their status flags.

## Fuel eligibility and interpretation

The pilot uses the existing profile cohort, supplemented by the returned Chinese
unit and flow QC tables: high-confidence units with no requested review, no more
than 1% spike rows, and no more than 5% full-record fuel change. Positive phase
fuel and duration are checked independently. This retains **626 CHN / 4,207 EUR**
flights for fuel/time metrics and **484 / 4,207** for distance metrics, in each
of the three phases. Duration-only support remains 672 / 4,207.

The 46 additional fuel-screen exclusions are B738 records in the present common
cohort. The full-record QC rule is conservative: ground anomalies can affect that
screen even when an airborne channel remains useful. This is an exploratory
source-derived pilot, not an adopted fuel-validation release or an independent
calibration of QAR against the European model. The Chinese legacy boundary-
accounting convention is preserved, not repaired in this table builder. Revised
source outputs must be adopted explicitly before promotion to final coefficients.

The original-versus-delivered EUR cumulative quantities were checked over the
actual ATOT--TOC--TOD--ALDT windows. Their **phase differences are identical for
all 4,207 flights**. In the supplied finer phase table, the 20% adjustment occurs
in TAKE_OFF_ROLL, before ATOT. Do not apply an additional blanket 20% reduction
to airborne fuel. The original/adjusted convention remains source metadata.

Only source-window fuel is populated. The alternative level-envelope TOC/TOD
analysis uses different boundaries; do not reuse source phase fuel unchanged at
those boundaries. Populating that sensitivity requires timestamp-aligned fuel
at its actual selected endpoints.

No engine identity is inferred from aircraft family; no separate regional
quantiles define profile classes. Fuel-source method and region remain confounded.
Payload, weather, speed and operator selection are not held equal by type, GCD
and altitude class. P20 is descriptive, and P50--P20 is not an ATM benefit pool.

## Reproduce and extend

```sh
Rscript tests/paper-lookup-table.R
Rscript scripts/14-characterise-enroute-levels.R
Rscript scripts/15-populate-paper-lookup.R
quarto render paper.qmd --to pdf
quarto render paper.qmd --to html
```

The standalone lookup script uses the matching cached enroute result and checks
its input hashes and flight cohort. Rerun script 14 whenever the profile inputs,
definitions or configuration change. The QMD computes both modules directly.
`FUELBURN_PAPER_CHN_DIR` can select a new fourteen-batch input root, after its
schema and eligibility semantics are reviewed. No source releases are modified.

The scripts export to `outputs/paper-lookup/`: the grid, wide grid, support/QC
summaries, fuel-variant audit, input hashes, runtime and restricted RDS. Flight-
level records stay ignored. To add the engine axis later, supply an explicit
engine mapping with source provenance. To populate climb/descent classes, first
freeze common interruption definitions and coverage rules, then replace the
reserved slots using the same metric-by-metric support policy.

The identifier-free snapshot is in `notes/results/lookup-pilot-2026-10-22/`.
It includes the full long/wide grids and exact source/input hashes; earlier
profile and altitude-residence snapshots are preserved.

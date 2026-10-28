# Terminal-window alternatives and airport sensitivity

27 October 2026. Supplement to the [lower-altitude support assessment](../paper-lower-ground-support-2026-10-27/README.md)
and [integration plan](../../paper-integration-plan-2026-10-27.md), following the
user's decision to retain the ATOT–A/FL030 option alongside ATOT–FL075.
These are existing-window support counts; canonical inputs and manuscript results
remain unchanged. No new FL030 crossing was generated.

## Existing terminal alternatives

The source-defined DLTO/ALTO are the available 3,000 ft terminal boundaries.
CHN uses a field-relative pressure increment; EUR source boundaries have different
semantics. Their counts do not establish a common absolute FL030 cohort. Keep
the physical reference explicit when selecting the eventual paper scheme.

| Window | CHN fuel/time | EUR fuel/time | CHN paired | EUR paired |
|---|---:|---:|---:|---:|
| ATOT–source DLTO | 6,392 | 21,502 | 1,647 | 6,224 |
| ATOT–FL075 | 6,391 | 21,501 | 1,647 | 6,224 |
| Source ALTO–ALDT | 6,376 | 21,502 | 1,639 | 6,224 |
| FL075–ALDT | 6,391 | 21,168 | 1,648 | 6,086 |

All four windows have eight paired type/GCD cells. The departure flight sets
within those cells are identical for the two alternatives, in both regions.
Across the full samples, departure FL075 support is a subset of source-DLTO
support, differing by one eligible flight in each region. There is no departure
sample-size reason to retire the source 3,000 ft option now.

Arrival supports are not interchangeable: the full CHN overlap is 6,374, with
two source-ALTO-only and seventeen FL075-only flights; the EUR FL075 set is a
subset of the source-ALTO set, lacking 334 of its eligible flights. Within paired
cells, FL075 adds nine CHN flights but removes 138 EUR flights relative to the
source option. Use actual set intersections for paired boundary sensitivities,
not the smaller sample count as a proxy for overlap.

## Airport impact

| CHN airport | Eligible ATOT–source DLTO | Eligible ATOT–FL075 | Eligible source ALTO–ALDT | Eligible FL075–ALDT |
|---|---:|---:|---:|---:|
| ZBAA | 1,503 | 1,503 | 1,513 | 1,513 |
| ZLXY | 1,032 | 1,031 | 1,009 | 1,014 |
| ZPPP | 744 | 744 | 586 | 586 |
| ZSSS | 3,113 | 3,113 | 3,268 | 3,278 |

The relevant airport is departure for climb and arrival for descent. ZPPP source
DLTO and ALTO median stored altitudes are approximately 9,786 and 9,764 ft, above
FL075. ZPPP therefore has zero positive-duration DLTO–FL075 / FL075–ALTO windows,
while retaining 744 ATOT–DLTO and 586 ALTO–ALDT fuel/time observations. A generic
milestone chain must not require the same order at every airport.

As a transparent sensitivity, omitting ZPPP at the relevant endpoint would give:

| CHN terminal window | All airports | Without relevant ZPPP endpoint | Eligible records removed |
|---|---:|---:|---:|
| ATOT–source DLTO | 6,392 | 5,648 | 744 |
| ATOT–FL075 | 6,391 | 5,647 | 744 |
| Source ALTO–ALDT | 6,376 | 5,790 | 586 |
| FL075–ALDT | 6,391 | 5,805 | 586 |

None of the paired fuel counts in the first table changes: the ZPPP comparisons
are outside those supported type/stage cells. This is a scenario, not an adopted
airport exclusion. It is not a general high-elevation threshold and does not make
the remaining source altitude references equivalent. ZLXY, for example, retains
a field-relative source boundary at a higher stored altitude than 3,000 ft.
Retain airport context and independently supported windows rather than imposing
one airport restriction on the entire study.

## Consequence for the plan

Keep the 3,000 ft terminal option live and compare its boundary semantics and
fuel/time distributions with the FL075 alternative before choosing a primary
terminal scheme. Use FL075–100 and FL100–180 (and descent counterparts) as the
core pressure windows. Additional flight levels and their source-implementation
investigation remain deferred. No distance-proxy values were invented here;
ground proxy design and the confirmed EUR roll-fuel convention are recorded in
the integration plan.

## Reproduce

```sh
Rscript scripts/assess-paper-terminal-options.R /restricted/new-empty-directory
```

The directory must exist inside FUELBURN_DATA_STORE. The checked run is
`derived/paper/eligibility-comparability/PAPER-2026-10-27-005-terminal-options/`.
The script reads the checked lower/ground window ledger and its aggregate
type/stage support table. It writes no canonical data. It checks unchanged input
hashes and reconciles set intersections with each alternative's support count.

This directory contains identifier-free aggregates, not flight-level ledgers:
`aggregate-airport-support.csv`, `aggregate-airport-scenarios.csv`,
`aggregate-terminal-option-overlap.csv`, input/source manifests and the R runtime.
The preceding assessment's manifest identifies the unchanged canonical sources.

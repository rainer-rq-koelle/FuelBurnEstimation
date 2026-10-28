# Pressure-window and terminal reference snapshot

27 October 2026. Adopted analysis `PAPER-REFERENCES-2026-10-27-001`; see
[reproduction and scope](../../paper-window-references.md). This is an explicit
candidate.6 CHN / pinned EUR analysis adoption. All canonical inputs remain unchanged.

## Reference tables

- `core-references.csv`: 64 rows, four directional pressure windows × eight
  supported aircraft/GCD cells × two sources. The windows are climb FL075–100,
  climb FL100–180, descent FL180–100 and descent FL100–075.
- `terminal-references.csv`: 64 rows retaining ATOT–source DLTO, ATOT–FL075,
  source ALTO–ALDT and FL075–ALDT in the eight supported cells, by source.
- `ground-references.csv`: the four ground source windows in their eight paired
  fuel/time cells. Distance-rate support is independent and much smaller.

Each wide row retains its window/endpoint scheme, source fuel convention, aircraft,
GCD band, explicit unstratified engine group and marginal all-profiles state.
For fuel kg, duration min, kg/min, kg/NM and flown NM, the row contains independent
n, P20/P50/P80, sparse/populated status and paired-support flags. The kg/NM column
uses supplied phase distance, never airport GCD. Ground zero-distance entries
remain unsupported for that metric. No proxy distances or interruption classes
were assigned.

Source-defined 3,000 ft terminal boundaries are not harmonised FL030 crossings.
The departure alternatives use identical matched flight sets: 1,647 CHN and
6,224 EUR each. Arrival sample sets differ. The delivered EUR roll fuel already
includes the stakeholder-confirmed 0.8 factor; original values remain in the
restricted view and their relation is recorded in `fuel_convention.csv`.

## Support and profile context

`support.csv` gives all-source time/fuel/distance eligibility per window.
`paired_support.csv` gives counts across supported cells for each metric;
`paired_cells.csv` retains the full type/GCD support matrix, including sparse and
unpaired cells. `inventory.csv`, `types.csv` and `dates.csv` describe the source
population. Counts overlap; they must not be added across windows.

`overview.csv` contains regional marginal references with each window's own
eligibility. These are differently composed source samples, not standardised
regional effects. `median-ratios.csv` contains ratios of within-cell medians for
the four pressure windows; it does not define a joint reference flight or replace
individual-flight rate calculations.

The `enroute-*` files give an independent time/profile cohort, altitude-band
residence, paired boundary-scheme summaries and support. Position-review holds
do not remove independently usable altitude, but cannot provide trusted radius
context. Unbracketed residence remains explicit. `profile_state.csv` reports
measurement support, not an assigned continuous/light/heavy class. Unknown
profile coverage does not remove a fuel-valid observation from marginal tables.

## Provenance

`input-manifest.csv` pins source products and derived eligibility views. Resolve
`data-store/` against FUELBURN_DATA_STORE; other paths are project-relative.
`source-manifest.csv` pins analysis/configuration, tests and manuscript/layout
sources. `session-info.txt` records the export runtime. The export script checks
that no aggregate CSV schema contains flight identifiers.

Flight/window/event/candidate ledgers and the complete grid remain in the approved
restricted store. Reproduce with scripts 16 and 17 and the checks documented in
the companion note. Percentiles are descriptive; no recoverable ATM savings,
independent fuel-source calibration or formal profile compliance is asserted.

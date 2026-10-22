# Enroute altitude residence and TOC/TOD sensitivity

Development record, 22 October 2026. Pipeline status and input-adoption details
belong here and in the technical notes, rather than in the conference draft.

## Analysis scope

The comparison keeps the six existing exact-aircraft-type / 100 NM GCD cells:
A20N, A21N, A320, A321 and B738 over 600--699 NM, and A21N over 500--599 NM.
There are 672 Chinese and 4,207 European flights in the source-window comparison.
These are selected study operations, not representative regional traffic samples.

The main new result measures **residence at pressure-altitude bands throughout
TOC--TOD**, including step changes. It is not a level-off count or a smoothness
classification. Minutes and phase shares are both retained, with equal weight
for each flight. The weighted altitude is first calculated per flight, then
summarised with P20/P50/P80; it is not the median of altitude samples.

### Measurement model

- China: use the existing altitude-time milestones, including the paired
  level-segment endpoints. These are the original fourteen returned batches.
- Europe: use the corresponding monthly M3 altitude-time profiles; convert
  flight levels from hundreds of feet to feet before any calculations.
- Consolidate duplicate timestamps, retain altitude-time ordering, and clip
  intervals to the selected TOC/TOD window. Use linear interpolation between
  successive altitude knots, split at every band crossing, and integrate time.
  Flat sections and both upward/downward crossings use the same accounting.
- Bands: below FL240, FL240--299, FL300--339, FL340--379, and FL380 or higher.
  The boundaries are half-open intervals [low, high), in pressure altitude;
  they do not assert that only discrete flight levels are flown.
- Preserve unbracketed time separately. Do not extrapolate outside the available
  altitude profile or treat the absence of altitude support as low-level flight.
- A second allocation includes only interpolation spans no longer than 300 s.
  The primary reconstruction is a declared model, not continuous observation.
  Long flat spans in sparse M3 profiles must not disappear merely because the
  sampling interval exceeds a five-minute screening parameter.

The Chinese paired level intervals cover a median 95.5% of the source enroute
window in the existing common-support cohort. Their interior altitude values
are not all stored in the milestone product; linear interpolation remains an
assumption even where a paired source interval establishes sustained level flight.
For the current Chinese qualified level intervals the largest endpoint altitude
change in these cells is 92 ft. Full altitude traces can replace the knot adapter
when adopted; they should not be mixed silently with the older source product.

### Boundary definitions

The source-window comparison retains the existing TOC and TOD, allowing continuity
with the earlier draft. The alternative uses a common **200 NM context / level
envelope** rule, independent of the source TOC/TOD timestamp:

1. Identify complete sustained level intervals over the whole airborne profile.
   Require at least 120 s, absolute vertical rate <=300 ft/min, and altitude span
   <=1,000 ft. Chinese candidates use the paired interval product; European
   candidates are derived from M3, with no low-rate run bridged across a sampling
   gap >300 s. Preserve original M3 knots when integrating residence time.
2. For Europe, split low-rate runs when altitude excursion exceeds the plateau
   tolerance. Discarding an entire slow step-change run could otherwise remove
   valid plateaus before and after the step. A transition step exceeding the
   tolerance is not turned into a plateau.
3. Find the maximum pressure altitude in the initial departure / final arrival
   200 NM contexts. The qualifying altitude floor is that maximum minus the
   greater of 1,000 ft and 3%. These contexts depend on geometry; they do not
   define the TOC/TOD timestamps. Use the airborne ceiling if a radius does not
   discriminate.
4. TOC is entry to the first complete level above the departure floor; TOD is
   exit from the last complete level above the arrival floor. Require climb and
   descent evidence and a positive interval. Do not clip a level at a circle.
5. Compare both window definitions on identical independent flights. Missing
   alternative boundaries remain missing; do not manufacture a zero-duration
   enroute phase. Show support and agreement within 60 s, alongside the altitude
   comparison, rather than assuming boundary definitions are interchangeable.

This is a descriptive sensitivity built from the study products. It is not a
new adopted canonical release or a substitution for the candidate.6 raw-QAR
processing. Source cadence and smoothing differ; the nominal common thresholds
do not demonstrate equal detector performance or CCO/CDO compliance.

## Reproduce and update inputs

### Results in the present source sample

Chinese median flight-weighted enroute altitude is lower in all six paired cells:
approximately 2,935--6,899 ft under the source windows and 2,914--6,994 ft under
the alternative envelope. The paired boundary cohort is 671 CHN / 4,162 EUR
flights; one CHN and 45 EUR flights lack an alternative satisfying the full rule.
All six cells still have at least 30 flights per region.

Source/envelope boundary agreement within one minute is 73.3% for Chinese TOC
and 71.4% for Chinese TOD; European values are 66.8% and 69.1%. Chinese per-cell
source/envelope median duration differences and European differences show why
phase duration requires an explicit definition even where the altitude contrast
persists. Differences of cell medians and the median of paired shifts are separate
statistics; they must not be substituted for each other.

The source enroute altitude profile is bracketed throughout in the median flight
of every cell. A gap-limited allocation nevertheless leaves substantial time
unclassified, especially across long flat sections represented by endpoint knots.
The gap screen is a resolution sensitivity, not proof of missing level flight.
The contrast concerns selected routes and operators and remains observational;
it is not an estimate of a regional ATM effect or a fuel-consumption penalty.

### Commands

```sh
Rscript tests/enroute-level-exposure.R
Rscript scripts/14-characterise-enroute-levels.R
quarto render paper.qmd --to pdf
quarto render paper.qmd --to html
```

The QMD calculates both analysis modules at render time. Standalone exports live
in the Git-ignored `outputs/paper-enroute-levels/` directory: aggregate percentile
tables, altitude-band minutes/shares, boundary shifts and support, input hashes,
R session, and an RDS containing restricted flight-level details. The original
18 October aggregate snapshot is preserved.

The identifier-free 22 October snapshot is in
`notes/results/enroute-levels-2026-10-22/`, including input/source-code hashes
and the fixed-cohort altitude and boundary tables. Time-accounting tests and
the complete rerun reproduce all stored aggregate results.

Both analysis modules recognise `FUELBURN_PAPER_CHN_DIR` as an optional override
for the root containing fourteen separate Chinese canonical/level tables. The
default stays pinned to the original batches. `FUELBURN_DATA_STORE` sets the
store root. After receiving the cleaned outputs, inventory their configuration,
eligibility and column semantics before changing this input root; do not infer
adoption from the presence of a new directory. Updating the root regenerates
the paper's counts, tables and plots. Interpretation and eligibility still need
review if definitions or source flags change. No source release is modified.

## Potential additions within the eight-page paper

### Core extensions for the two research questions

1. **Climb/descent interruption composition.** Total level minutes and phase
   share, count, longest interruption and altitude. Use common thresholds for
   continuous/lightly/heavily interrupted classes, retaining unknown coverage.
   First show each region's class distribution, then condition fuel on class.
2. **Conditional fuel distributions.** In the same aircraft/distance/phase/profile
   cells, report total kg alongside duration, kg/min and kg/NM, with P20/P50/P80
   and independent-flight support. Retain source provenance and the European
   adjusted/original fuel convention; percentile spreads are not recoverable ATM
   savings.
3. **Enroute duration and altitude jointly.** One compact panel or table pairing
   time-weighted altitude with enroute minutes and airborne share. This connects
   the present altitude result to consumption without assuming that lower
   altitude alone explains a fuel difference.

### Compact optional additions, in priority order

- **Step-climb / step-descent structure:** initial/final plateau, maximum attained
  altitude, count and magnitude of sustained changes. Useful for explaining why
  TOC/TOD endpoints and residence-weighted altitude differ.
- **Distance-band and route-mix sensitivity:** adjacent band boundaries or a
  continuous GCD adjustment, plus route direction/airport elevation context.
  Avoid pooling regional cells with different fleet or distance weights.
- **Sampling and boundary sensitivity:** keep one compact figure/table in the
  paper; put detailed gap limits, selected profile plots and derivation evidence
  in the reproducibility note.
- **Uncertainty:** flight-level or route/day-clustered bootstrap intervals for
  a small set of headline contrasts, when the inferential target is fixed.

### Defer unless they directly strengthen a headline result

Widebodies without joint support, C919-only regional description, detailed taxi
analysis, engine/fleet expansion, causal ATM benefit pools, weather/load modelling,
and broad machine-learning clustering would dilute the eight-page contribution.
Engine grouping is useful only where engine identity is actually supported.
Do not reinterpret a level cruise segment as an inefficient interruption.

The current QMD keeps the classical five-section skeleton. It has a concise
methods description and results; data-cleaning status, returned-helper history,
and the input-adoption plan are kept outside its rendered narrative.
